# Pill 2 - Modules

In the previous pill, we looked at how to define a single module consisting of
a set of source files and a list of include paths.

In practice, we want to modularize the code. For example, we may have code for
a UI frontend library, a terminal frontend library, and a data model backend
library, as well as some startup glue logic for each executable.

In this case, we will look at how to split the module from the previous pill
into different modules.

## Implementation

In the previous pill, we defined an `app` module, which was implemented as a
`pb` object containing source files and include paths.

Let's say we want to create a generic model library.

At a first glance, we can simply split it into two modules.

`main.pbb` can then be:

```pbb
|{ cwd, include, ... }|
let
    lang_c = include "${cwd}/lib/lang_c.pbb";

    app = {
        srcs = [
            "${cwd}/main.c",
        ];
        incs = [
        ];
    };

    model = {
        srcs = [
            "${cwd}/model/model.c",
            "${cwd}/model/some_other_model.c",
        ];
        incs = [
            "${cwd}/model",
        ];
    };

    all_modules = lang_c.merge [
        app,
        model,
    ];
in
(lang_c.build "${cwd}/my_app" all_modules)
```

However, there is one new method used here: `lang_c.merge`. Let's implement it.

At the end of `lang_c.pbb` from the previous pill, add the following before the
final `}`.

Note that this will be part of a library, not used by the end user. It is simply
shown as an example of how it can be done.

```pbb

# ---- >8 ----
    merge = | mods |
    {
        srcs = ( | prev mod | prev ++ mod.srcs for []: mods );
        incs = ( | prev mod | prev ++ mod.incs for []: mods );
    };
# ---- >8 ----
}
```

Let's break it down into parts:

`merge = | mods |` means `merge` is a function that takes a variable `mods`,
which is a list of all the modules in the project.

The function returns `{ srcs = ...; incs = ...; }`, which is itself the same
definition of a module. So it combines a list of modules into a single module.

The last part `( | prev mod | prev ++ mod.xx for []: mods )` uses the
language construct called "fold" to flatten a list of lists into a single list.

In lead-lib, this function is actually available as `tk.flatten`, but since we
don't use lead-lib yet, we have to implement it ourselves. For now, you can
just skip over the details of the implementation if you want.

The concept of modules and `merge`—taking a list of modules and combining them
into a single module—is a central part of `lead-lib`, and it will be extended
and generalized in several steps later.

## Step two - multiple files

So why is it important to use modules? Do all files still need to be listed?

Let's split `main.pbb` into separate files.

The `model` module has all the files listed from within the same subdirectory,
namely `model/`. Wouldn't it be great to have the subdirectory enclose all of
the configuration needed for that module?

Let's try it out.

Add a file `model/model.pbb`:

```pbb
|{ cwd, ... }|
{
    srcs = [
        "${cwd}/model.c",
        "${cwd}/some_other_model.c",
    ];
    incs = [
        "${cwd}",
    ];
}
```

Note that `cwd` in this case is an input from lead-build, referencing the
directory of the `*.pbb` file. Therefore, referencing `"${cwd}/model.c"` in
this file results in referencing the file `model.c` relative to the directory of
`model/model.pbb`.

This means the submodule `model/` does not need to reference where it is placed
in the source tree of the overall project. This makes it possible to package
build definitions in a library, like an embedded RTOS or source library, without
requiring any assumptions about *where* it is placed in the application's
source tree. In later pills, we will even see that it is not necessary for the
overall project to know what language the module is written in.

But this means we need to include the file in the overall project's `main.pbb`:

```pbb
|{ cwd, include, ... }|
let
    lang_c = include "${cwd}/lib/lang_c.pbb";

    app = {
        srcs = [
            "${cwd}/main.c",
        ];
        incs = [
        ];
    };

    model = include "${cwd}/model/model.pbb";

    all_modules = lang_c.merge [
        app,
        model,
    ];
in
(lang_c.build "${cwd}/my_app" all_modules)
```

## Output

After running `pb` in the directory, the `build.ninja` file will include rules
for the model files, as defined in the submodule:

```ninja
#...
build main.o: gcc_c_o_MMD main.c
build model/model.o: gcc_c_o_MMD model/model.c
build model/some_other_model.o: gcc_c_o_MMD model/some_other_model.c
build my_app: gcc_o main.o model/model.o model/some_other_model.o
#...
```

placing the object files beside the `.c` files, as expected so far.

# Conclusions

We have shown the power of being able to split code into modules, where modules
can split the build into:

- what to integrate
- what to include in the submodule

while still producing a single output.

However, there is still more to generalize.

In the next pill, we will look at how to configure compilers and how that fits
into the module system, as well as what needs to change.