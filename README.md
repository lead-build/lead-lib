# lead-lib

## File structure

For the user, there are two types of files: Project files, and module files.

The project file is placed in the top of the project, called `main.pbb`.

The module file is placed in a module folder, with a name by convesion is called
the same as the module, suffixed with `.pbb`

## Theory of operation

The concept of the build system is focused around what should be delivered, not
what is the source.

Each module therefore provides, given target parameters, a list of
*deliverables* from the modules point of view.

For example, a module containing the source of an application delivers the
*object* files needed to build the aplication, based on the *environment*
containing the compiler and parameters.

The project file then does the final link of the project.

### Module file structure

Each module needs to be able to provide input for other modules to build, with
input from system configuration. Therefore, modules are loaded in two passes:

1. Envionment and target configuration
2. Building and compilation

From an outside point of view, the minimal module file is therefore:

```pbb
|{...}|
|{...} @ env|
{
    lang = {
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

where `obj` represents pass two


### Libraries and intermediate builds

When building libraries that does not depend on any external sources, it may be
defined as a build in pass 1, and just returned in pass 2, to leverage laziness
in lead-lang, for reusability, when bulding multiple targets and only build the
library once.

The requirement is that what is returns is _a_ correct build in `obj` field, and
inforamtion of in the language specific environment for other modules to access
it.
