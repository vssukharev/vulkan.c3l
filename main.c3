
import bindgen;
import std::io;
import std::collections::list;

alias StringList = List{String};

macro log(String name, ...) 
{
  io::printf("--- ");
  io::printfn(name, $vasplat);
}

fn bool is_func_macro_ignored(String name) 
{
  switch (name) {
    case "VK_DEFINE_HANDLE":
    case "VK_DEFINE_NON_DISPATCHABLE_HANDLE": 
    // case "VK_MAKE_VERSION":
    // case "VK_VERSION_MAJOR":
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

  switch (name) {
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
  switch (name) {
    case "VkIcdSurfaceMir":
      return "env::VK_USE_PLATFORM_MIR_KHR";

    case "VkIcdSurfaceWayland":
      return "env::VK_USE_PLATFORM_WAYLAND_KHR";

    case "VkIcdSurfaceWin32":
      return "env::VK_USE_PLATFORM_WIN32_KHR";

    case "VkIcdSurfaceXcb":
      return "env::VK_USE_PLATFORM_XCB_KHR";

    case "VkIcdSurfaceXlib":
      return "env::VK_USE_PLATFORM_XLIB_KHR";

    case "VkIcdSurfaceAndroid":
      return "env::VK_USE_PLATFORM_ANDROID_KHR";

    case "VkIcdSurfaceMacOS":
      return "env::VK_USE_PLATFORM_MACOS_MVK";

    case "VkIcdSurfaceIOS":
      return "env::VK_USE_PLATFORM_IOS_MVK";

    case "VkIcdSurfaceMetal":
      return "env::VK_USE_PLATFORM_METAL_EXT";

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
        res = name.snake_to_pascal(alloc);
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

macro void translate_headers(Path root, String $ver) => @pool() 
{
  Path out = root.tappend("import/" +++ $ver +++ "/vulkan.c3i")!!;
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
      "-DVK_ENABLE_BETA_EXTENSIONS",
      "-DVK_USE_PLATFORM_MIR_KHR",
      "-DVK_USE_PLATFORM_WAYLAND_KHR",
      // "-DVK_USE_PLATFORM_WIN32_KHR",
      // "-DVK_USE_PLATFORM_XCB_KHR",
      // "-DVK_USE_PLATFORM_XLIB_KHR",
      "-DVK_USE_PLATFORM_ANDROID_KHR",
      "-DVK_USE_PLATFORM_MACOS_MVK",
      "-DVK_USE_PLATFORM_IOS_MVK",
      "-DVK_USE_PLATFORM_METAL_EXT",
      "-DVK_USE_PLATFORM_VI_NN",
    },
    .module_name = "vulkan::vk",
    .skip_errors = false,
    .no_verbose = true,
    .include_file = fn bool(String path) =>
      path.contains("vulkan_") || path.contains("external/"),
  };

  bg::translate_header("vulkan/vulkan.h", transfns, opts, genfns)!!;
}


fn void main(String[] args) {
  Path root = path::cwd(tmem)!!;
  translate_headers(root, "1.1");
  translate_headers(root, "1.2");
  translate_headers(root, "1.3");
  translate_headers(root, "1.4");
}


