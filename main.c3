
import bindgen;
import std::io;
import std::collections::list;

alias StringList = List{String};

macro log(String name, ...) {
  io::printf("[LOG]: ");
  io::printfn(name, $vasplat);
}

fn bool is_func_macro_ignored(String name) {
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

fn bool is_const_ignored(String name) {
  switch (name) {
    case "VK_LAYER_EXPORT": 
      return true;
    default:                
      return false;
  }
}

fn String get_if_condition(String name) {
  switch (name)
  {
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

fn String get_func_macro_body(String name) {
  switch (name) {
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
  }

  return name;
}

macro void translate_headers(Path root, String $ver) => @pool() {
  
  Path out = root.tappend("import/" +++ $ver +++ "/vulkan.c3i")!!;
  Path current = root.tappend("headers/" +++ $ver +++ "/vulkan")!!;
  path::chdir(current)!!; 
  log("Changed directory to %s", current);

  BGTransCallbacks transfns = {
    .func = fn String(String name, Allocator alloc) =>
      name.strip("vk").camel_to_snake(alloc),

    .type = fn String(String name, Allocator alloc) =>
      name.map_basic_type(alloc) ?? name.copy(alloc),

    .variable = fn String(String name, Allocator alloc) =>
      name == "module" ? "mod" :
      name.camel_to_snake(alloc),
      
    .constant = fn String(String name, Allocator alloc) =>
      is_const_ignored(name) ? "" : 
      name.strip("VK_").snake_to_screaming(alloc),

    .func_macro = fn String(String name, Allocator alloc) =>
      is_func_macro_ignored(name) ? "" : 
      name.strip("VK_").screaming_to_snake(alloc),
  };

  BGGenCallbacks genfns = {
    .func_macro = fn String(String name, Allocator alloc) =>
      get_func_macro_body(name).copy(alloc),

    .if_condition = fn String(String name, Allocator alloc) =>
      get_if_condition(name).copy(alloc),
  };

  // StringList headers;
  // headers.tinit();
  // // foreach (p : path::ls(tmem, current)!!) {
  // //   if (is_path_ignored(p)) continue;
  // //   headers.push(p.str_view());
  // // }
  // headers.push(current.tappend("vulkan_core.h").str_view())!!;
  // headers.push(current.tappend("vulkan_android.h").str_view())!!;
  // // headers.push(current.tappend("vk_icd.h").str_view())!!;

  BGOptions opts = {
    .out_name = out.str_view(),
    .clang_args = { 
      "-DVK_ENABLE_BETA_EXTENSIONS",
      // "-DVK_USE_PLATFORM_MIR_KHR",
      // "-DVK_USE_PLATFORM_WAYLAND_KHR",
      // "-DVK_USE_PLATFORM_WIN32_KHR",
      // "-DVK_USE_PLATFORM_XCB_KHR",
      // "-DVK_USE_PLATFORM_XLIB_KHR",
      // "-DVK_USE_PLATFORM_ANDROID_KHR",
      // "-DVK_USE_PLATFORM_MACOS_MVK",
      // "-DVK_USE_PLATFORM_IOS_MVK",
      // "-DVK_USE_PLATFORM_METAL_EXT",
    },
    .module_name = "vulkan::vk",
    .skip_errors = false,
    .include_file = fn bool(String name) =>
      name.contains("vulkan_"),
  };

  bg::translate_header("vulkan.h", transfns, opts, genfns)!!;
}


fn void main(String[] args) {

  Path root = path::cwd(tmem)!!;
  translate_headers(root, "1.1");
  // translate_headers(root, "1.2");
}


