# Rust static lib bindings

This implementation is experimental at this point.

Briefly tested using:

Cargo.toml:
```toml
...

[lib]
crate-type = ["staticlib"]

[profile.release]
panic = "abort"

[profile.dev]
panic = "abort"

...

[build-dependencies]
cbindgen = "0.29.4"
...

```

build.rs:
```rust
extern crate cbindgen;

use std::env;

fn main() {
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();

    cbindgen::Builder::new()
      .with_crate(&crate_dir)
      .with_config(cbindgen::Config::from_root_or_default(&crate_dir))
      .generate()
      .expect("Unable to generate bindings")
      .write_to_file("bindings.h");
}
```

lib.rs:

```rust
#![no_std]
#![no_main]

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}

#[unsafe(no_mangle)]
pub extern "C" fn rust_eh_personality() {}

#[unsafe(no_mangle)]
pub extern "C" fn my_exported_function(left: i32, right: i32) -> i32 {
    left + right
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = my_exported_function(2, 2);
        assert_eq!(result, 4);
    }
}
```