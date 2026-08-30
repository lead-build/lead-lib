# Pill 3 - Configuration

Up to this point, we have added modular builds, possibility to merge modules.
But we do not yet have any support for adding configuration, such as compiler
flags, or even which compiler to use.

This part is not going to be too advanced, but it's important of the concept of
lead-lib module system. However, we will extend it again later.

## Modules

Modules has been until now only been source files for language C, and with no
configuration.

However, to be able to add more langauges, and generic configuration, it is
improtant to be able to add more categories to the modules, one per "langauge".

In lead-lib, a module category are called "langauge", since the intended purpose
is to group parameters into its respective langauge. However, there are also
common parameters and configuration parmeters, which for generality is placed in
the respective language, for exmaple `config`.

## Implementation

To start with, we look at how a `main.pbb` can look like, when we add some
configuartion to a module.

At this point, we keep the `objdir` and `app` as lists for now for simplicity,
and expecting them to be a single value at the end. When introducting `lead-lib`
later, this will be more generic.

```pbb
|{ cwd, include, ... }|
let
    lib = include "${cwd}/lib/lib.pbb";

    target = {
        config = {
            objdir = ["${cwd}/build"];
            srcdir = ["${cwd}"];
            app = ["${cwd}/my_app"];
        };
    };

    app = {
        c = {
            srcs = [
                "${cwd}/main.c",
                "${cwd}/model/model.c",
                "${cwd}/model/some_other_model.c",
            ];
            incs = [
                "${cwd}/model",
            ];
        };
    };

    all_modules = lib.merge [
        target,
        app,
    ];
in
(lib.c.build all_modules)
```

In this file, we can show that a module also can contain configuration, and
categories per languages.

We have added three configuration parameters:

- The a application name, what we want to generate
- The `srcdir`, which is the base dir to find all source files
- The `objdir`, which is where to place the object files.

App name and `objdir` should be a single variable, but for simplicity in this
pill, we treat them as lists, and use the last value in the list when building.
This is so we can focus on the concept of parameters and modules rather than how
to handle different types. That we will address later instead, when introducing
`lead-lib` in a later pill.

The goal is that each source file should be compiled into an object file with
the relative path to `objdir`, as the source file had relative to `srcdir`. For
exmaple, `module/lib.c` should result in `build/module/lib.o`. Then further
linked to `my_app`.

The eagle eyed reader may have noticed that the language library previously
included is not a generic library, which first for the build uses the language
c via `lib.c.build`.

But first, just define what's necessary for the `config` language, by
implenenting `lang/lang_config.pbb`

```pbb
|{ pb, ... }|
{
    merge = | mods |
    {
        objdir = ( | prev mod | prev ++ mod.objdir for []: mods );
        srcdir = ( | prev mod | prev ++ mod.srcdir for []: mods );
        app = ( | prev mod | prev ++ mod.app for []: mods );
    };
}
```

Not that the config language so far does not have a build function, since we
only intend to build the c langauge.

Speaking of `lang_c.pbb`, that needs to be updated too:

```pbb
|{ pb, dbg, ... }|
let
     # Function using fold to get the last element from a list
    list_last = | list | (| prev elem | elem for list);
in
{
    build = | module |
    let
         # Caluclate arguments for include paths
        includes = [ | inc | "-I${inc}" for module.c.incs ];

        objdir = list_last module.config.objdir; # Get the objdir from config

         # Generate the object file path from source file path. This uses the
         # builtin function pb.translate
        src_to_obj = | srcfile | pb.translate {
            input = srcfile - ".c" + ".o"; # Change suffix from .c to .o
            from = module.config.srcdir; # pb.translate takes a list of srcdirs
            to = objdir;
        };


         # Define the compile command, this assumes the .o file is beside .c
         # This is a function that takes a source file and returns the built
         # object file.
        compile_c_to_o =
        let
             # Compile rule is only defined for the function below
            rule_compile = pb.rule (
                |{ input, output }|
                {
                    command = [
                        "gcc",
                        "-c",
                        "-o", output,
                        "-MMD", "-MD", "${output}.d",
                        input
                    ]
                    ++ includes;
                    depfile = "${output}.d";
                    description = "CC ${input}";
                }
            );
        in
         # Return a function that takes a source file, and returns the build
         # for the object file.
        | srcfile | rule_compile {
            input = srcfile;
            output = src_to_obj srcfile;
        };

         # Define the link command
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
        output = list_last module.config.app; # Get the app name from config
        input = [
            | srcfile | compile_c_to_o srcfile
            for module.c.srcs
        ];
    };

    merge = | mods |
    {
        srcs = ( | prev mod | prev ++ mod.srcs for []: mods );
        incs = ( | prev mod | prev ++ mod.incs for []: mods );
    };
}
```

In this file we have made some changes.

Next is that build takes not only the parameters from `c` langauge, but all
config. This means the `lib.c.build` have access also to `mod.config.xxx`
parameters. And therefore, `lib.c.build` does no longer need the extra config
patamter, but configuration is a module itself.

The `lead-build` builtin `pb.translate` is therefore used to remap the source
files to the build dir, based on what is available in the config.

But we still need to implement `lib/lib.pbb` though:
```pbb
|{ include, cwd, ... }|
let
    lang_config = include "${cwd}/lang_config.pbb";
    lang_c = include "${cwd}/lang_c.pbb";
in
{
    merge = | mods |
    {
         # Merge config from all modules where config is defined.
        config = lang_config.merge [
            | mod | mod.config for mods if | mod | mod ? "config"
        ];
         # Merge c from all modules where c is defined.
        c = lang_c.merge [
            | mod | mod.c for mods if | mod | mod ? "c"
        ];
    };

    # Re-export the langauges
    config = lang_config;
    c = lang_c;
}
```

In this case, we reexport the `lang_c` and `lang_config.pbb`, as `lib.c` and
`lib.config`, while implementing a merge function, that merges all language
parts individually. `mod ? "language"` is a `lead-build` langauge contstruct to
check if a field is defined in an object.

Refer to [lead-build documentation](https://lead-build.readthedocs.io) if you
want to read up more on how list compherensions work. Otherwise, it's just
filtering out each language submodule from a list of modules.

# Conclusion

In this pill, we have looked at how to place configuration in a module, to keep
a build entirely to a set of modules.

It's a big step forward to be generic, but we still have one part configured
outside of the list of modules. We still use `lib.c.build`, not a generic
`lib.build` for building. So we still assume it's a C project, not a generic
project containing C.

In the next pill we will step back from the actual builds, and look at a concept
of how to make parameters in a module dependent on other parameters, before
going back to see how we can genralize the last part of the module concept.