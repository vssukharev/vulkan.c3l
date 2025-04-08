
# vulkan.c3l - Vulkan bindings for C3

Vulkan bindings created via [bindgen.c3l](https://github.com/vssukharev/bindgen.c3l).

## Setup

To install the bindings to your project, simple copy **vulkan.c3l** to your project library directory and set "vulkan" as dependenncy.

## Configuration

If you desire to use older version of Vulkan (1.1, 1.2 or 1.3) you will need to set the corresponding environment variable in your C3 project. For example:
```rust
module 

```

## Regenerate bindings

First of all, install **libclang** required by [bindgen.c3l](https://github.com/vssukharev/bindgen.c3l) Then simply run `c3c run` from root directory.


