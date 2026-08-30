# Pill 5 - Generic build function

We have so far, except for pill 4, used a specific function to handle C builds.

But one of the core concepts of the lead build system, with `lead-lib` and
`lead-build` is that you never create a language specific project, like a C
project. Instead, you create a project containing C code, or a combination of
languages.

Another core concept is that there are no global configuration, but
configuration resides within the modules passed to `lib.build`.

Up until this point we have built up the concepts required to achieve this, its
just to fit the pieces togheter.

## Genralizing the build

We have in pill 3 shown how to add configuration as modules. And in pill 4 shown
how to make parameters in the modules dependent on each other, while letting
non-referenced paramters not evaluated, due to laziness in `lead-build`

This solution can be used to define what outputs the project should have, by
defining the common `config.out` as a list of all generated artifacts.

Given the languages injects a base module before the others at hte last step
before building, it is possible for the language to always add a build in its
own submodule

For example, `lang.c` can in its module add `lang.c.app`, that always points to
a generated build based on the parameters specified in `lang.c.srcs`,
`lang.c.incs` and other. If not referenced, for exmaple if building a rust
output, it doen't even have to compile, since it isn't referenced, and therefore
not evaluated.

This means, tell `lib.build` to output the application build from c, it is just
to add a module containing:

```pbb
app_build = | l | let ll = l l; in {
    config = {
        out = ll.c.app;
    };
};
```

Adding this module to the build will result in `lib.build` referencing
`ll.config.out`, which then references `ll.c.app`.

## Adapt the build to dependent vars

To show how it works, lets adopt the build from pill 3, with the dependent vars
from pill 4, and add the output as described above.

To start, we look at what implications this has to `main.pbb`, as that's what
the user sees:

```pbb
|{ cwd, include, ... }|
let
    lib = include "${cwd}/lib/lib.pbb";

    target = | l |
    let
        ll = l l;
    in
    {
        config = {
            objdir = [ "${cwd}/build" ];
            srcdir = [ "${cwd}" ];
            app = [ "${cwd}/my_app" ];
            out = ll.c.app; # Make this i C build.
        };
    };

    myapp = | _ |
    {
        c = {
            srcs = [
                "${cwd}/main.c",
                "${cwd}/model/model.c",
                "${cwd}/model/some_other_model.c",
            ];
            incs = [
                "${cwd}/model",
            ];

             # By limitations in this example, we need to define "app" here too,
             # since all parameters within a language needs to be defined here.
             # This is properly handled in `lead-lib`
            app = [];
        };
    };

    app_mods = lib.merge [
        target,
        myapp
    ];
in
(
    lib.build app_mods
)
```

The main parts that are added are just encapsulation of the objects as
functions. And most of them are wrapped in helpers anyway.

Lets look at `lib/lib.pbb`:

```pbb
|{ include, dbg, cwd, ... }|
let
    lang_config = include "${cwd}/lang_config.pbb";
    lang_c = include "${cwd}/lang_c.pbb";

     # merge is needed to generate the base module. Will also be exported below.
    merge = | mods l |
    let
         # Just pass l down to all modules, which means during merge, it can
         # simply be used as a normal object
        evaled_mods = [ | mod | (mod l) for mods ];
    in
    {
         # Merge config from all modules where config is defined.
        config = lang_config.merge [
            | mod | mod.config for evaled_mods if | mod | mod ? "config"
        ];
         # Merge c from all modules where c is defined.
        c = lang_c.merge [
            | mod | mod.c for evaled_mods if | mod | mod ? "c"
        ];
    };

     # Combine all base modules from all langauges
    base_mod = | l |
    {
        config = lang_config.base l;
        c = lang_c.base l;
    };
in
{
     # Export merge
    merge = merge;

     # Re-export the langauges
    config = lang_config;
    c = lang_c;

     # Build function
    build = | mod |
    let
         # Combine all modules a single module, including the language base.
        all_mods = merge [ base_mod, mod ];

         # This is the recursion from pill 4
        res = all_mods all_mods;
    in
    res.config.out; # Use the configured output
}
```

Here are some bigger changes.

First off, the merge function takes an extra argument. Due to how `lead-build`
handles functions with multiple arguments. calling the function with only `mods`
*binds* `mods` to the function and leaving a function taking `l`.

The only change after that is that it does the recursive eval of all mods,
to continue with the merge as it was before.

The second change is `base_mod` that is built up from all the languages
available, which is needed by the `build` function, as mostly described in
pill 4. It can be seen that it combines the `base_mod` with `mod` to build from
the argument, to recurse before getting `res.config.out`.

The `lib/lang_config.pbb` doesn't contain much to surprise:

```pbb
|{ pb, ... }|
{
     # The base module for config doesn't depend on any other module, so it can
     # simply use a wildcard for the argument.
    base = | _ |
    {
        objdir = [];
        srcdir = [];
        app = [];

         # is defined from a module in `main.pbb` or similar.
        out = [];
    };

    merge = | mods |
    {
        objdir = ( | prev mod | prev ++ mod.objdir for []: mods );
        srcdir = ( | prev mod | prev ++ mod.srcdir for []: mods );
        app = ( | prev mod | prev ++ mod.app for []: mods );
        out = ( | prev mod | prev ++ mod.out for []: mods );
    };
}
```

The base submodule contains the defaults, and merge has the new `out` field.

Same with `lib/lang_c.pbb`:

```pbb
|{ pb, dbg, ... }|
let
     # Function using fold to get the last element from a list
    list_last = | list | (| prev elem | elem for list);

     # we still need to build the module, but this time, it's not exported as a
     # build. This will be used to generate the `app` field in the base module.
     # To build, this needs to be referenced from `mod.config.out`.
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
in
{
    base = | l |
    let
        ll = l l;
    in
    {
         # No default sources or includes. Still needs to be defined
        srcs = [];
        incs = [];

         # App is a list of all outputs, given this module should be built.
         # This is referenced from a module in `main.pbb` if a C build is
         # exptected.
        app = [
            build ll # Invoke the previous build function.
        ];
    };

    merge = | mods |
    {
        srcs = ( | prev mod | prev ++ mod.srcs for []: mods );
        incs = ( | prev mod | prev ++ mod.incs for []: mods );
        app = ( | prev mod | prev ++ mod.app for []: mods );
    };
}
```

THe build function is actually untouched. What has happened is that it is moved
so it's not exported, but rather used in the new `base` module, as the new
patameter `app`, as described earlier.

## Conclusion

This shows that it's possible to use a generic project, and a generic build
function `lib.build` to build any language.

This gives a modular system, where any parameter, even the list of sources, can
be modified from any other module, or language, which is useful for code
generation, as we will see in the next pill, where we introduce `lead-lib` and
more languages.