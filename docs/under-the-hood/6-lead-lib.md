# Pill 6 - lead-lib and multiple languages

At this point, we have built up all the building blocks needed to step into
lead-lib, and see how to extend it from there.

We are here going to see how a single build can be used to build for multiple
architectures and use code generation, by using the code generators to output
.c source files.

## Migrate to lead-lib

Given the previous build, we are going to skip ahead to use `lead-lib`.

The build from pill 4 will then give the `main.pbb`, given lead-lib is loaded
as a subdirectory `lead-lib`, preferrably as a git submodule.

```pbb
|{ cwd, include, ... }|
let
    lib = include "${cwd}/lead-lib/lead-lib.pbb" { };

    target = | _ |
    {
        config = {
            objbasedir = "${cwd}/build";
            srcdirs = [ "${cwd}" ];
            outdir = "${cwd}/out";
        };
    };

     # lead-lib are using a wrapper to make the code cleaner. It's just a normal
     # module as seen before
    my_app = lib.lang.c.mod {
        src = [
            "${cwd}/main.c",
            "${cwd}/model/model.c",
            "${cwd}/model/some_other_model.c",
        ];
        inc = [
            "${cwd}/model",
        ];
    };

    app_mods = [
         # this generates the lib.common.out definition for the app.
        lib.lang.c.app_build "my_app",

        target,
        my_app
    ];
in
 # lib.build from lead-lib takes a list of modules.
lib.build app_mods
```

As seen, all the building blocks are there from previous pill.

`lib.lang.c.mod` is just a wrapper to encapsulate the boilerplate for the module
functions, and enable extension of type checking in the future.

`lib.lang.c.app_build` encapsulates setting the `l.common.out` paramter, as it
is called in lead-lib, togheter with setting `l.config.target_name` to define
the name of the application.

## Adding a language

Given the flexibility of lead-lib, it is possible to add custom languages.

Languages are part of the library itself, and can therefore not be added as
modules. But by convention, `include "${cwd}/lead-lib/lead-lib.pbb" { }` takes
an object as argument to tune lead-lib. And one way is to add the paramters
`languages`.

In this case, we're going to look at a simple "language" called "structpack",
which is a hypotethical python package that takes a `.toml` file, and converts
it into a c header file, that is accessible from any other .c file, that would
enable them access functions generated to pack and unpack structs for
communication.

The same way would be possible to use for parser genererators, like `yacc` and
`bison`.

For that, we need to create a language definition file, here called
`lang_structpack.pbb`:

```pbb
|{ cwd, pb, dbg, ... }|
let
    structpack_cmd = | input output | [
        "python3",
        "${cwd}/structpack.py",
        "-i",
        input,
        "-o",
        output
    ];

    toml_to_hdr = | ll file | pb.translate {
        input = file;
        from = ll.config.srcdirs;
        to = ll.config.objdir;
    };

    tmpl_structpack = | ll |
    let
        rule_sp = pb.rule (
            |{ input, output }|
            {
                command = structpack_cmd input output;
                description = "SP structpack ${input}";
            }
        );
    in
    | file | rule_sp {
        input = file;
        output = (toml_to_hdr ll file) - ".toml" + ".h";
    };
in
{
    merge = {
        inc = | a b | a ++ b;
        src = | a b | a ++ b;

        out_src = | a b | a ++ b;
        out_hdr = | a b | a ++ b;
    };

    base = | l | let ll = l l;
    in
    {
        c = {
            extra_deps = ll.sp.out_hdr;
            inc = [
                | src_file | (toml_to_hdr ll src_file)
                for (ll.sp.inc)
            ];
        };
        sp = {
            inc = [];
            src = [];
            out_src = [];
            out_hdr = let
                sp = tmpl_structpack ll;
            in
            [
                | src_file | sp src_file
                for (ll.sp.src)
            ];
        };
    };

    export = {
        mod = |{inc ? [], src ? [], ...}|
        | _ |{
            sp = {
                inc = inc;
                src = src;
            };
        };
    };
}
```

Feel free to dig into the parts hat might interest you. But in this pill we are
going to focus on just a few parts:

First, in lead-lib, the `base` module for a language can contain paramters for
any other langauge too. The `base` module in this case shows how the language
itself injects an include path, using `base.c.inc`. It is also injects the
generated file to `base.c.extra_deps`, which the c implementation in lead-lib
uses as dependency for all generated object files, to guarantee changes in the
`.toml` input file rebuilds all other sources.

It also sets `export.mod`, which will be available as `lib.lang.sp.mod` to
simplify generation of structpack modules.

the include path in structpack is necessary since structpack generates the
header files within a build-directory, so it tells structpack which translated
paths to inject.

The main file, with code generation will then be:

```pbb
|{ cwd, include, ... }|
let
    lib = include "${cwd}/lead-lib/lead-lib.pbb" {
        languages = {
            sp = include "${cwd}/lang_structpack.pbb";
        };
    };

    target = | _ |
    {
        config = {
            objbasedir = "${cwd}/build";
            srcdirs = [ "${cwd}" ];
            outdir = "${cwd}/out";
        };
    };

     # lead-lib are using a wrapper to make the code cleaner. It's just a normal
     # module as seen before
    my_app = lib.lang.c.mod {
        src = [
            "${cwd}/main.c",
            "${cwd}/model/model.c",
            "${cwd}/model/some_other_model.c",
        ];
        inc = [
            "${cwd}/model",
        ];
    };
    my_sp_mod = lib.lang.sp.mod {
        inc = [
            "${cwd}/model",
        ];
        src = [
            "${cwd}/model/some_struct.toml",
        ];
    };

    app_mods = [
         # this generates the lib.common.out definition for the app.
        lib.lang.c.app_build "my_app",

        target,
        my_app,
        my_sp_mod,
    ];
in
 # lib.build from lead-lib takes a list of modules.
lib.build app_mods
```

The only two additions is the added `language` to lead-lib include, and the
structpack module `my_sp_mod`.

The generated `build.ninja` can then correctly show all dependencies generated:
```
rule gcc_c_o_MMD
  command = gcc -c -o ${out} -MMD -MF ${out}.d ${in} -Ibuild/my_app/model -Imodel
  description = CC$ gcc$ ${in}
  depfile = ${out}.d

rule gcc_o
  command = gcc -o ${out} ${in}
  description = LD$ gcc$ ${out}

rule python_i_o
  command = python3 structpack.py -i ${in} -o ${out}
  description = SP$ structpack$ ${in}

build build/my_app/main.o: gcc_c_o_MMD main.c | build/my_app/model/some_struct.h

build build/my_app/model/model.o: gcc_c_o_MMD model/model.c | build/my_app/model/some_struct.h

build build/my_app/model/some_other_model.o: gcc_c_o_MMD model/some_other_model.c | build/my_app/model/some_struct.h

build out/my_app: gcc_o build/my_app/main.o build/my_app/model/model.o build/my_app/model/some_other_model.o

build build/my_app/model/some_struct.h: python_i_o model/some_struct.toml

default out/my_app
```

# Conclusion

In this pill we have shown how the previous pills integrate into lead-lib, and
how to use the flexibility for code generation.

In the next pill, we will show how it can be used for multiple parallell targets
and relocation libraries.
