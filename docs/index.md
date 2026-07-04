# lead-lib - Language tools for lead-build

[lead-build](https://lead-build/readthedocs.io) is a declarative language for
describing build projects. It enables reusable modules that are architecture-
and compiler-independent, so integrators can choose what to include without
adopting a library's internal structure.

This requires conventions and libraries for specifying builds, so each project
implements the same interface and modules compose cleanly.

This is where *lead-lib* comes in.

At a high level, lead-lib provides:

- Conventions for how modules integrate (the build API)
- Tools for implementing boilerplate module builds

It does so while remaining:
- language independent
- naturally supportive of code generation, such as parser generators and
  protocol generators
- capable of hierarchical linking, for example by combining reusable libraries
  into one build output that can be used as input to the next
- compatible with multiple architectures in the same build, for example with
  non-global CFLAGS

It also provides helpers for languages.

Currently:
- C, via gcc

Planning to add:
- C via clang
- Rust
- and others...

## Usage

Best way of using lead-lib is to check it out as a submodule within your
project, and `include` the file `lead-lib.pbb` into your projects `main.pbb`.

That makes sure your build stays consistent until you manually upgrade the
library.


## File structure

For users, there are two main file types: project files and module files.

The project file is placed at the top level of the project and is called
`main.pbb`. They sepecify the output of the deliverable out of the project.
Including linking and packaging.

The module file is placed in a module folder. By convention, it has the same
name as the module, with a `.pbb` suffix. They contains the modules output,
intended for further processing withing a parent lead-build script.

## Theory of operation

The build system focuses on what should be delivered, not on source layout.

Given target parameters, each module provides a list of *deliverables* from the
module's point of view.

For example, a module containing an application's source code delivers the
*object* files needed to build the application, based on the *environment*
containing the compiler and its parameters.

The project file then performs the final link step.

### Module file structure

Each module must be able to provide build input to other modules using system
configuration input. Therefore, modules are loaded in two passes:

1. Environment and target configuration
2. Object generation (compilation)

From an external perspective, the minimal module file is:

```pbb
|{...}|
|{...} @ config|
{
    env = {
        c = {
            inc = [
                cwd
            ];
        };
    };

    obj = |build| build.lang.c |{cc, ...}| [
        cc "${cwd}/myfile_a.c",
        cc "${cwd}/myfile_b.c",
        cc "${cwd}/myfile_c.c",
    ];
}
```

where `obj` represents pass 2.


### Libraries and intermediate builds

When building libraries that do not depend on external sources, the library can
be defined as a build in pass 1 and then returned in pass 2. This leverages
laziness in lead-lang for reuse across multiple targets, so the library is
built only once.

The requirement is that pass 2 returns _a_ correct build in the `obj` field,
along with information in the language-specific environment that other modules
can access.
