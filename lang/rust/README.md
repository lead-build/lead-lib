# Rust static lib bindings

This implementation is experimental at this point.

A complete walkthrough is available in the
[cookbook](https://lead.readthedocs.io/en/latest/cookbook/c-and-rust/) of the
Lead documentation.

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

use std::{env, path::PathBuf};

fn main() {
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();

    // If CBINDGEN_HEADER_OUTPUT is relative, it should be relative to PWD, not
    // CARGO_MANIFEST_DIR, to match the structure of the ninja build.
    let pwd = PathBuf::from(env::var("PWD").unwrap());
    let header_name = PathBuf::from(env::var("CBINDGEN_HEADER_OUTPUT").unwrap());
    let header_path = pwd.join(&header_name);

    cbindgen::Builder::new()
        .with_crate(&crate_dir)
        .with_config(cbindgen::Config::from_root_or_default(&crate_dir))
        .generate()
        .expect("Unable to generate bindings")
        .write_to_file(&header_path);
}
```

The environment variable `CBINDGEN_HEADER_OUTPUT` is set by the build rule in
`rust.pbb`, and tells where the generated header is expected.

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