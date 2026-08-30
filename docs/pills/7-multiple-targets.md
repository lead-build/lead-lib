# Pill 7 - multiple targets

We have shown how lead-lib can be used to generate flexible targets. But still
need to show how it can be used to run multiple configuration in parallell.

Since `lib.build` is pure, that it only generates what is passed as input, and
returns the build as a return value, it is totally valid to run it several
times within the same build script.

## Release vs. debug build

In this example, we can show how to use the same modules defining source, or
even defining code generation, by passing them to multiple `lib.build`
instances.

That can be used if multiple targets, architectures or similar are needed for
the same source.

In this case, we are going to do two separate builds, one with `-O3` flag set
and one with `-O0` and `-g` set, just by switching the configuration module,
while preserving the rest.

Only update `main.pbb` from previous pill to:

```pbb
|{ cwd, include, ... }|
let
    lib = include "${cwd}/lead-lib/lead-lib.pbb" {
        languages = {
            sp = include "${cwd}/lang_structpack.pbb";
        };
    };

    target_release = | _ |
    {
        config = {
            objbasedir = "${cwd}/build/release";
            srcdirs = [ "${cwd}" ];
            outdir = "${cwd}/out_release";
        };
        c = {
            cflags = [ "-O3" ];
        };
    };

    target_debug = | _ |
    {
        config = {
            objbasedir = "${cwd}/build/debug";
            srcdirs = [ "${cwd}" ];
            outdir = "${cwd}/out_debug";
        };
        c = {
            cflags = [
                "-O0",
                "-g",
                "-ggdb"
            ];
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

    app = lib.merge [
        my_app,
        my_sp_mod,
    ];
in
 # lead-build can handle a list of generated output. However, lib.build already
 # returns a list, so flatten it, using the lead-lib toolkit function "flatten"
lib.tk.flatten [
    lib.build [
        lib.lang.c.app_build "my_app",
        target_release,
        app,
    ],
    lib.build [
        lib.lang.c.app_build "my_app_debug",
        target_debug,
        app,
    ],
]
```

This shows that two different `lib.build` calls are made, with the different
targets, and different build dirs.
