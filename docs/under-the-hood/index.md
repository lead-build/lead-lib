# Introruction

In this series of pills, we will introduce the concepts used in lead-lib to make
a complete modular build environment, that can be extensible with new languages,
without updates to lead-lib

Note that all files demonstrated in those pills that is placed in `lib/` is to
build up the internals of `lead-lib` itself, and not inteded to be made by the
user of the build system.

Those pills is intended to go deep into the intenrals of `lead-lib`, to
understand the underlying structure of the build system, to be able to adapd and
use the advanced featuers of the library.

We will go through how to modularize for:
- multiple targets, configuration and cross compilation
- resuable parts of the build
- multiple languages and code genration

All in the same build configuration, by using the constructs available in
[lead-build](https://lead-build.readthedocs.io).

But to achieve that goal, one concept at a time needs to be introduced, which is
why the concept of "pills" are used. First pill will start small, and
incrementally build up to what is lead-lib, based on lead-build.

## Prerequisites

To read through the pills, it is not expected to know every part of the
[lead-build](https://lead-build.readthedocs.io) language. However, it is
expected to know the basic syntax.

Recommeded to read before:

- Under language
  - How to run `pb`
  - Core language concepts, expressions and functions
  - Paths - the basics, that paths are a special object in lead
- Under builds
  - Rules and builds - in the end, we want to generate a ninja output file

Good to know, and read up later, when needed

- Pattern matching - primarily how to use objects as function arguments
- List operators, will be used to implement the pills later, but not so much for
  within simple projects
- Operators and builtins that manipulate paths

## The pills

* [Pill 1 - **Simple builds**](1-builds.md) - separation of *what* to build from
  *how* to build
  it.
* [Pill 2 - **Modules**](2-modules.md) - introduction of the concept of having
  source code
  modules, and including libraries instead of source files.
* Pill 3 - **Configuring compilers** - how to use modules to manage compiler
  configuration.
* Pill 4 - **Dependent variables** - Looking at how module parameters can depend
  on eachother.
* Pill 5 - **Generic build** - How to achieve a language-indepedendent build
  function
* Pill 6 - **Mapping to lead-lib** - How this fit in with `lead-lib`