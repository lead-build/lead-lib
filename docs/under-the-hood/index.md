# Introduction

In this series of pills, we introduce the concepts used in lead-lib to make a
complete modular build environment that can be extended with new languages
without requiring updates to lead-lib.

Note that all files demonstrated in these pills that are placed in `lib/` are
used to build up the internals of `lead-lib` itself and are not intended to be
created by users of the build system.

These pills are intended to go deep into the internals of `lead-lib` to help
understand the underlying structure of the build system, so you can adapt and
use the advanced features of the library.

We will go through how to modularize for:
- multiple targets, configuration, and cross compilation
- reusable parts of the build
- multiple languages and code generation

All in the same build configuration, by using the constructs available in
[lead-build](https://lead-build.readthedocs.io).

To achieve that goal, one concept at a time needs to be introduced, which is
why the concept of "pills" is used. The first pill starts small and
incrementally builds up to what lead-lib is, based on lead-build.

## Prerequisites

To read through the pills, it is not expected that you know every part of the
[lead-build](https://lead-build.readthedocs.io) language. However, it is
expected that you know the basic syntax.

Recommended to read before:

- Under language
  - How to run `pb`
  - Core language concepts, expressions, and functions
  - Paths - the basics: paths are a special object in lead
- Under builds
  - Rules and builds - in the end, we want to generate a ninja output file

Good to know, and read up later when needed:

- Pattern matching - primarily how to use objects as function arguments
- List operators - these will be used to implement the pills later, but not so
  much for simple projects
- Operators and builtins that manipulate paths

## The pills

* [Pill 1 - **Simple builds**](1-builds.md) - separation of *what* to build from
  *how* to build it.
* [Pill 2 - **Modules**](2-modules.md) - introduction of the concept of having
  source code modules and including libraries instead of source files.
* [Pill 3 - **Configuring compilers**](3-configuration.md) - how to use modules
  to manage compiler configuration.
* [Pill 4 - **Dependent variables**](4-dependent-vars.md) - looking at how module
  parameters can depend on each other.
* [Pill 5 - **Generic build**](5-generic-build.md) - how to achieve a
  language-independent build function.
* [Pill 6 - **Mapping to lead-lib**](6-lead-lib.md) - how this fits in with
  `lead-lib`.