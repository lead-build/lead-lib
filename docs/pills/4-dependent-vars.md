# Pill 4 - Dependent Variables

In this pill, we are going to step back a bit from the bigger project, and
look at the module concept as its basic.

We have shown so far how to make modules that can model the source files and
paramters from a submodule, we have shown how to place compiler configuration
in a module. However, it has a limitation, that parameters can not be dependent.

To do this, we are not going to generate a ninja build file, but rather use the
`pb -E` feature to look at the evaluated lead source tree.

## Simplification

At the core, we are going to look at a simple module of one level:

Create a file `part_1.pbb`
```pbb
|{ cwd, ... }|
let
    mod = {
        app = "my_app";
        arch = "x86_64";
        outdir = "${cwd}/out";
    };
in
mod.outdir / (mod.app + "-" + mod.arch)
```

This shows a generated path out of the three parameters in the simplified
module.

And try to evaluate it using `pb -E -i part_1.pbb`. It should output:
```
[root]/$/out/my_app-x86_64
```

Note that the path is written as a Path object, as described in
[lead-build](https://lead-build.readthedocs.io) documentation.

The question is how we can generate a parameter within the module itself for 
the output file, dependent on the three parameters. For example:

```pbb
|{ cwd, ... }|
let
    mod = {
        app = "my_app";
        arch = "x86_64";
        outdir = "${cwd}/out";
        outfile = ...; # What to put here?
    };
in
mod.outfile
```

## Iteration

One important aspect of `lead-build` is that it is *lazy*, which means it only
evaluates the part of the expressions that actually is used. This can be used
to our advantage.

So lets try again, but making the module a *function*.

Create a `part_2.pbb` containing:

```pbb
|{ cwd, ... }|
let
    mod = | l |{
        app = "my_app";
        arch = "x86_64";
        outdir = "${cwd}/out";
    };

    res = mod { };
in
res.outdir / (res.app + "-" + res.arch)
```

Since nothing within the module depends on `l`, we can simply pass an empty
object to itself.

Result is the same as previous attempt:
```
[root]/$/out/my_app-x86_64
```

Now we have the possiblity to pass a value to the object itself, which means we
can create parameters in the module dependent on some input parameters. What if
we then run the module twice, passing the first iteration back to itself?

Lets try `part_3.pbb`:

```pbb
|{ cwd, ... }|
let
    mod = | l |{
        app = "my_app";
        arch = "x86_64";
        outdir = "${cwd}/out";
        outfile = l.outdir / (l.app + "-" + l.arch);
    };

    iter1 = mod { };
    iter2 = mod iter1;
in
iter2.outfile
```

Gives yet again:
```
[root]/$/out/my_app-x86_64
```

Note that, in this case, if we would have looked at `iter1.outfile`, then that
would be an error, since `l.outdir`, `l.app` and `l.arch` would be undefined for
`iter1`, where `l` is set to `{}`.

It is however valid to have `outfile` set, dependent on those variables in `l`,
since outfile is not *evaluated*, as long as `l.outfile` is not referenced at
that iteration.

To achieve more levels of referencing, it is easy to iterate more times.
However, this implementation only allows a finite level of iteration.

Therefore, lets try another approach, what if we can make it recursive?

## Recursion

Instead of evaluating the iteration outside of the module, what if we move it
into the module itself:

Lets modify:

```pbb
|{ cwd, ... }|
let
    mod = | l |
    let
        ll = l l;
    in
    {
        app = "my_app";
        arch = "x86_64";
        outdir = "${cwd}/out";
        outfile = ll.outdir / (ll.app + "-" + ll.arch);
    };

    res = mod mod;
in
res.outfile
```

At the top level, for `(mod x).app`, `(mod x).arch` and `(mod x).outdir`, the
result is not dependent at all on what the argument `x` is, it won't even be
evaluated. Not even the `let ll = l l; in` expression that is added, since
neither `l` or `ll` is referenced from those paramters. Therefore, x can be of
any type defined in lead-build; an object, null or a function. It doesn't
matter.

So when passing the module itself into it, which itself is a function at this
point, they will still evaluate.

So calculating `res = mod mod;` means passing the module function back to the
module, giving access to all top level parameters.

When evaluating `res.outfile` however, the module function on line 3 gets the
module itself as argument `l`. On line 5, it evaluates `ll = l l;`, which is the
same as `res = mod mod;`, since `l` in this case is set to `mod`, from the call
`res = mod mod;`.

That means, `ll`, when evaluating `res.outfile` is set to the evaluated `mod`
that gives access to `ll.outdir`, `ll.app` and `ll.arch`.

In fact, if any of those would be depending on variables within the module
itself, `ll = l l;` still evaluates one iteration more, and there is a recursive
resolution of all variables, which results in an infinite number of iterations
theoretically allowed.

This concept of recursive resolution is used as the basis of `lead-lib` module
system, to make it possible to allow multiple languages depending on eachother,
as will be descibed in later pills.

More levels of iterations can be seen here, in `part_5.pbb`:

```pbb
|{ cwd, ... }|
let
    mod = | l |
    let
        ll = l l;
    in
    {
        var_a = "a";
        var_b = ll.var_a + "b";
        var_c = ll.var_b + "c";
        var_d = ll.var_c + "d";
    };

    res = mod mod;
in
res.var_d
```

resolves to:
```
"abcd"
```

## Infinite recursion

As shown in previous chapter, this is a quite powerful concept, to be able to
depend on other parameters.

However, it works by in the end ending up in parameters that are not dependent
on `l`. If not, there will be no termination, and the system will end up in a
loop of infinite recursion, that is quite hard to debug.

One example, `part_6`:

```pbb
|{ cwd, ... }|
let
    mod = | l |
    let
        ll = l l;
    in
    {
        var_a = ll.var_b + "a";
        var_b = ll.var_a + "b";
    };

    res = mod mod;
in
res.var_b
```

shows that `ll.var_b` depends on `ll.var_a` which depends back on `ll.var_b`.

Running this example will end up in:
```
thread 'main' (18762) has overflowed its stack
fatal runtime error: stack overflow, aborting
[1]    18762 IOT instruction  pb -E -i part_6.pbb
```

To have any chance of debugging this, add `-vvv` to the `pb`. It will print out
a trace of all expressions that are being resolved internally within `pb`. The
format may vary between versions of `pb`, but it may be a clue of where the
recursion happens.

`pb -E -i part_6.pbb -vvv` will be quite noisy, but give some clues:

In this case, it will output something similar to:
```
...    ...    binary operator expression at part_6.pbb:9:17
... Resolving bound expression at part_6.pbb:9:17
...    ...    attribute selection at part_6.pbb:9:17
... Resolving bound expression at part_6.pbb:9:20
... Resolving bound expression at part_6.pbb:9:17
... Resolving bound expression at part_6.pbb:5:14
...    ...    function call at part_6.pbb:5:14
... Resolving bound expression at part_6.pbb:5:14
... Resolving bound expression at part_6.pbb:5:16
...    ...    bound expression at part_6.pbb:4:5
...    ...    bound expression at part_6.pbb:7:5
... Resolving bound expression at part_6.pbb:8:17
...    ...    binary operator expression at part_6.pbb:8:17
... Resolving bound expression at part_6.pbb:8:17
...    ...    attribute selection at part_6.pbb:8:17
... Resolving bound expression at part_6.pbb:8:20
... Resolving bound expression at part_6.pbb:8:17
... Resolving bound expression at part_6.pbb:5:14
...    ...    function call at part_6.pbb:5:14
... Resolving bound expression at part_6.pbb:5:14
... Resolving bound expression at part_6.pbb:5:16
...    ...    bound expression at part_6.pbb:4:5
...    ...    bound expression at part_6.pbb:7:5
... Resolving bound expression at part_6.pbb:9:17
```

In this case, it can be seen that there are a lot of focus around `part_6.pbb:8`
and `part_6.pbb:9`, which happens to be the lines:

```pbb
        var_a = ll.var_b + "a";
        var_b = ll.var_a + "b";
```
which gives a clue of where the infinite recursion happens.

## Merge

This however means we need to modify the merging slightly, by passing the `l`
parameter forward.

Given that we have a `merge_objs` function, that merges two resolved modules,
the `l` parameter can be passed down simply by using:

```pbb
merge = | mods l | merge_objs [|mod| mod l for mods];
```

## Conclusion

We have introduced the concept of having modules as functions with recursion,
to make module parameters dependent on each other.

In the next pill, we will look at how this self-referencing can be used to
replace the language specific `lib.c.build` with a generic `lib.build`.
