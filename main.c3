
import bindgen;
import std::io;
import std::collections::list;

alias StringList = List{String};

/// ----- Utils
macro log(String name, ...) 
{
  io::printf("--- ");
  io::printfn(name, $vasplat);
}

macro String @get_platform_condition(String $platform)
{
  var $str = "env::VK_USE_PLATFORM_" +++ $platform;
  return "$defined(" +++ $str +++ ") &&& " +++ $str; 
}

macro String @get_version_condition(String $major, String $minor)
{
  var $str = "env::VK_API_VERSION_" +++ $major +++ "_" +++ $minor;
  var $pref;
  $if $minor == "4":
    $pref = "!$defined(" +++ $str +++ ") ||| ";
  $else
    $pref = "$defined(" +++ $str +++ ") &&& ";
  $endif

  return $pref +++ $str +++ " == vk::@makeApiVersion(0, " +++ $major +++ ", " +++ $minor +++ ", 0)"; 
}

macro String.contains_ext(self, ...)
{
  bool res;

  var $vas = { $vasplat };
  $foreach $va : $vas:
    res = res || self.contains($va);
  $endforeach

  return res;
}

macro String.is_screaming(self)
{
  foreach (c : self)
  {
    if (c.is_lower()) return false;
  }
  return true;
}

// ---- Functions
fn bool is_func_macro_ignored(String name) 
{
  switch (name) {
    case "VK_DEFINE_HANDLE":
    case "VK_DEFINE_NON_DISPATCHABLE_HANDLE": 
    case "VK_MAKE_API_VERSION":
    // case "VK_MAKE_VERSION":
    // case "VK_VERSION_MINOR":
    // case "VK_VERSION_PATCH":
      return true;
    default:                
      return false;
  }
}

fn bool is_const_ignored(String name) 
{
  if (name.ends_with("_")) return true;

  switch (name) 
  {
    case "VK_LAYER_EXPORT": 
    case "VK_VERSION_1_0":
    case "VK_USE_64_BIT_PTR_DEFINES":
      return true;

    default:                
      return false;
  }
}

fn String get_if_condition(String name) 
{
  switch
  {
    case name.contains_ext("Xcb", "_xcb_", "_XCB_"):
      return @get_platform_condition("XCB_KHR");

    case name.contains_ext("Wayland", "_wayland_", "_WAYLAND_"):
      return @get_platform_condition("WAYLAND_KHR");

    case name.contains_ext("MacOS", "_macos_", "_MACOS_"):
      return @get_platform_condition("MACOS_MVK");

    case name.contains_ext("IOS", "_ios_"):
      return @get_platform_condition("IOS_MVK");

    case name.contains_ext("Android", "_android_", "_ANDROID_"):
      return @get_platform_condition("ANDROID_KHR");
    
    case name.contains_ext("AcquireXlib", "acquire_xlib", "ACQUIRE_XLIB"):
      return @get_platform_condition("XLIB_XRANDR_KHR");

    case name.contains_ext("Xlib", "_xlib_", "_XLIB_"):
      return @get_platform_condition("XLIB_KHR");

    case name.contains_ext("Metal", "_metal_", "_METAL_"):
      return @get_platform_condition("METAL_EXT");

    case name.contains_ext("Win32", "_win32_", "_WIN32_"):
      return @get_platform_condition("WIN32_KHR");

    case name.contains("NN") && name.contains_ext("Vi", "_vi_", "_VI_"):
      return @get_platform_condition("VI_NN");

    case name.contains_ext("DirectFB", "_directfb_", "_DIRECTFB_"):
      return @get_platform_condition("DIRECTFB_EXT");

    case name.contains_ext("QNX"):
      return @get_platform_condition("SCREEN_QNX");

    case name.contains_ext("FUCHSIA"):
      return @get_platform_condition("FUCHSIA");

    case name.contains_ext("GGP"):
      return @get_platform_condition("GGP");

    // TODO: SCI support
    // case name.contains_ext(""):
    //   return @get_platform_condition("SCI");

    // TODO: beta extensions support
    // case name.contains_ext(""):
    //   return @get_platform_condition("EXTENSIONS");

    default:
      return "";
  }

}

fn String get_func_macro_body(String name) 
{
  switch (name) 
  {
    case "VK_MAKE_VERSION":
      return "return ((#major) << 22) | ((#minor) << 12) | (#patch);";

    case "VK_MAKE_API_VERSION":
      return "return (((uint)(#variant)) << 29U) | (((uint)(#major)) << 22U) | (((uint)(#minor)) << 12U) | ((uint)(#patch));";

    case "VK_API_VERSION_VARIANT":
      return "return (uint)(#version) >> 29U;";
    
    case "VK_VERSION_MAJOR":
      return "return (uint)(#version) >> 22;";

    case "VK_VERSION_MINOR":
      return "return ((uint)(#version) >> 12) & 0x3ff;";

    case "VK_VERSION_PATCH":
      return "return (uint)(#version) & 0xfff;";

    case "VK_API_VERSION_MAJOR":
      return "return ((uint)(#version) >> 22U) & 0x7FU;";

    case "VK_API_VERSION_MINOR":
      return "return ((uint)(#version) >> 12U) & 0x3FFU;";

    case "VK_API_VERSION_PATCH":
      return "return (uint)(#version) & 0xFFFU;";

    case "VK_MAKE_VIDEO_STD_VERSION":
      return "return (((uint)#major) << 22) | (((uint)#minor) << 12) | ((uint)#patch);";

    default:
      return "";
  }
}

fn String get_const_rhs(String name) 
{
  switch (name) 
  {
    case "VK_QUEUE_FAMILY_EXTERNAL":
      return "~0U-1U";

    case "VK_QUEUE_FAMILY_FOREIGN_EXT":
      return "~0U-2U";

    default:
      return "";
  }
}

fn String trans_type(String name, Allocator alloc)
{
  String res;

  String? t = name.map_basic_type(alloc);
  if (catch t)
  {
    switch
    {
      case name.starts_with("wl_"):
      case name.starts_with("xcb_"):
        res = name.snake_to_pascal(alloc);

      case name.is_screaming():
        res = name.screaming_to_pascal(alloc);

      default:
        res = name.camel_to_pascal(alloc);
    }
  }
  else
  {
    res = t;
  }

  return res;
}

macro void translate_headers(Path root, String $major_ver, String $minor_ver)
{
  var $ver = $major_ver +++ "_" +++ $minor_ver;
  Path out = root.tappend("import/vk" +++ $ver +++ ".c3i")!!;
  Path current = root.tappend("headers/" +++ $ver)!!;
  path::chdir(current)!!; 
  log("Changed directory to %s", current);

  BGTransCallbacks transfns = {
    .func = fn String(String name, Allocator alloc) =>
      name.strip("vk").pascal_to_camel(alloc),

    .type = &trans_type,

    .variable = fn String(String name, Allocator alloc) =>
      name == "module" ? "mod" : name.pascal_to_camel(alloc),
      
    .constant = fn String(String name, Allocator alloc) =>
      is_const_ignored(name) ? "" : 
      name.strip("VK_").snake_to_screaming(alloc),

    .func_macro = fn String(String name, Allocator alloc) =>
      is_func_macro_ignored(name) ? "" : 
      name.strip("VK_").screaming_to_camel(alloc),
  };

  BGGenCallbacks genfns = {
    .func_macro = fn String(String name, Allocator alloc) =>
      get_func_macro_body(name).copy(alloc),

    .constant = fn String(String name, Allocator alloc) =>
      get_const_rhs(name).copy(alloc),

    .if_condition = fn String(String name, Allocator alloc) =>
      get_if_condition(name).copy(alloc),
  };

  BGOptions opts = {
    .out_name = out.str_view(),
    .clang_args = { 
      "-I.", "-I../external",
      "-DVK_USE_PLATFORM_ANDROID_KHR",
      "-DVK_USE_PLATFORM_FUCHSIA",
      "-DVK_USE_PLATFORM_IOS_MVK",
      "-DVK_USE_PLATFORM_MACOS_MVK",
      "-DVK_USE_PLATFORM_METAL_EXT",
      "-DVK_USE_PLATFORM_VI_NN",
      "-DVK_USE_PLATFORM_WAYLAND_KHR",
      "-DVK_USE_PLATFORM_MIR_KHR",
      "-DVK_USE_PLATFORM_WIN32_KHR",
      "-DVK_USE_PLATFORM_XCB_KHR",
      "-DVK_USE_PLATFORM_XLIB_KHR",
      "-DVK_USE_PLATFORM_DIRECTFB_EXT",
      "-DVK_USE_PLATFORM_XLIB_XRANDR_KHR",
      "-DVK_USE_PLATFORM_GGP",
      "-DVK_USE_PLATFORM_SCREEN_QNX",
      // "VK_USE_PLATFORM_SCI",
      "-DVK_ENABLE_BETA_EXTENSIONS",
    },
    .module_name = "vulkan::vk @if(" +++ @get_version_condition($major_ver, $minor_ver) +++ ")",
    .skip_errors = false,
    .no_verbose = true,
    .include_file = fn bool(String path) => path.contains("vulkan_"),
  };

  bg::translate_header("vulkan/vulkan.h", transfns, opts, genfns)!!;
}


fn void main(String[] args) 
{
  Path root = path::cwd(tmem)!!;
  translate_headers(root, "1", "1");
  translate_headers(root, "1", "2");
  translate_headers(root, "1", "3");
  translate_headers(root, "1", "4");
}


