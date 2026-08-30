# Pill 1 - Basic builds

At first, given an understanding of the language of
[lead-build](https://lead-build.readthedocs.io), it is quite simple to set up
a basic modular build system for a given language.

It is recommended to read through the documentation and familiarize yourself
with the basics of the language before reading this section.

For example, a C module usually consists of a given set of parameters. In this
case, we focus on the two main ones:

- source files
- include paths

## Prerequisites

## Implementation

We can then easily define a module as:

```pbb
{
    srcs = [
        # list of source files
    ];
    incs = [
        # list of include paths
    ];
}
```

The language definition can then be implemented as a library that compiles the
files into an output binary. Of course, more configuration parameters can be
added, such as which compilers to use, compiler flags, and defines, and so on.

The library can be a separate file called `lib/lang_c.pbb`:

```pbb
|{ pb, ... }|
{
    build = | output_file module |
    let
         # Calculate arguments for include paths
        includes = [ | inc | "-I${inc}" for module.incs ];

         # Define the compile command. This assumes the .o file is beside .c.
         # This is a function that takes a source file and returns the built
         # object file.
        compile_c_to_o =
        let
             # Compile rule is only defined for the function below.
            rule_compile = pb.rule (
                |{ input, output }|
                {
                    command = [
                        "gcc",
                        "-c",
                        "-o", output,
                        "-MMD", "-MD", "${output}.d",
                        input ] ++ includes;
                    depfile = "${output}.d";
                    description = "CC ${input}";
                }
            );
        in
         # Return a function that takes a source file and returns the build
         # for the object file.
        | srcfile | rule_compile {
            input = srcfile;
            output = srcfile - ".c" + ".o";
        };

         # Define the link command.
        link_o_to_app = pb.rule (
            |{ input, output }|
            {
                command = [
                    "gcc",
                    "-o", output,
                    input
                ];
                description = "LD ${output}";
            }
        );
    in
    link_o_to_app {
        output = output_file;
        input = [
            | srcfile | compile_c_to_o srcfile
            for module.srcs
        ];
    };
}
```

Let's see how to use it. Create a main file for the project, `main.pbb`:

```pbb
|{ cwd, include, ... }|
let
    lang_c = include "${cwd}/lib/lang_c.pbb";

    app = {
        srcs = [
            "${cwd}/main.c",
            "${cwd}/lib/lib.c",
        ];
        incs = [
            "${cwd}/lib",
        ];
    };
in
(lang_c.build "${cwd}/my_app" app)
```

## Output

Standing in the directory of `main.pbb` and running `pb` should then produce
a `build.ninja` file that looks like:

```ninja
rule gcc_c_o_MMD
  command = gcc -c -o ${out} -MMD -MD ${out}.d ${in} -Ilib
  depfile = ${out}.d
  description = CC$ ${in}

rule gcc_o
  command = gcc -o ${out} ${in}
  description = LD$ ${out}

build lib/lib.o: gcc_c_o_MMD lib/lib.c

build main.o: gcc_c_o_MMD main.c

build my_app: gcc_o main.o lib/lib.o

default my_app
```

This file is the output of `pb` and might be recognized as a ninja file used to
control [ninja](https://ninja-build.org/).

To finally build the project, just run `ninja` in the terminal, which will read
the `build.ninja` file and run the commands to compile, given that the source
files exist. Ninja is used because it is great at handling dependency tracking,
parallel builds, and speed, while `lead-build` becomes a frontend to generate
the build description.

It can be seen that:

- `my_app`, as the top-level target, is default
- `my_app` is linked from two object files
- the object files are compiled from source using two rules

In ninja, the actual rule names that are generated are only internal references.
Therefore, in lead-build, those are just generated to be unique and best effort
to be descriptive.

## Conclusion

This separates two important parts of a build that should be handled in a build
system:

- What to build
- How to build it

In the next pill, we will look at how to extend the build to handle modules.