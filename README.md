# lead-lib - Language tools for the Lead Build System

The [Lead Build System](https://lead.readthedocs.io), or just Lead, is a
declarative build system. Its language, implemented by
[lead-build](https://github.com/lead-build/lead-build), enables reusable modules
that are architecture- and compiler-independent, so integrators can choose what
to include without adopting a library's internal structure.

This requires conventions and libraries for specifying builds, so each project
implements the same interface and modules compose cleanly.

This is where *lead-lib* comes in.

More information is available in the
[documentation](https://lead.readthedocs.io/).

## Usage

The best way of using lead-lib is to check it out as a submodule within your
project:

```sh
git submodule add https://github.com/lead-build/lead-lib.git lead-lib
```

and `include` the file `lead-lib.pbb` into your project's `main.pbb`:

```pbb
|{ cwd, include, ... }|
let
    lib = include "${cwd}/lead-lib/lead-lib.pbb" { };
in
lib.build [
    lib.lang.c.app_build "my_app",
    lib.lang.config.simple "${cwd}",
    lib.lang.c.mod {
        src = [ "${cwd}/src/main.c" ];
        inc = [ "${cwd}/src/" ];
    },
]
```

That makes sure your build stays consistent until you manually upgrade the
library.

## Contents

The top-level `lead-lib.pbb` exports:

- `build`, which builds a list of modules
- `merge`, which combines a list of modules into a single module
- `gate`, which includes a module only when a condition on the resolved build
  is true
- `lang`, the language modules:
    - `lang.c`, for C
    - `lang.rust`, for Rust static libraries (experimental, see
      [lang/rust/README.md](lang/rust/README.md))
    - `lang.config`, for common build configuration, such as
      `lang.config.simple`
    - `lang.common`, shared language-level helpers, such as
      `lang.common.merge_target`, a helper to merge target metadata such as
      `common.subdir`
- `tk`, the toolkit helpers module, such as `tk.flatten`, which flattens a list
  of lists into a single list

In the C language backend, object output translation respects
`target.common.subdir` by appending it to `config.common.objdir`.
