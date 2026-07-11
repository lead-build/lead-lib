# lead-lib - Language tools for lead-build

[lead-build](https://lead-build/readthedocs.io) is a declarative language for
describing build projects. It enables reusable modules that are architecture-
and compiler-independent, so integrators can choose what to include without
adopting a library's internal structure.

This requires conventions and libraries for specifying builds, so each project
implements the same interface and modules compose cleanly.

This is where *lead-lib* comes in.

More information is available in the [documentation](https://lead-lib.readthedocs.io/)

For information about the language for [lead-build](https://github.com/lead-build/lead-build) itself, checkout it's own [documentation](https://lead-build.readthedocs.io/).

## Usage

Best way of using lead-lib is to check it out as a submodule within your
project, and `include` the file `lead-lib.pbb` into your projects `main.pbb`.

That makes sure your build stays consistent until you manually upgrade the
library.

## Recent language additions

The top-level `lead-lib.pbb` export now also provides:

- `tk`, the toolkit helpers module
- `lang.common`, shared language-level helpers

Current toolkit helpers include:

- `tk.flatten`, which flattens a list of lists into a single list

Current language helpers include:

- `lang.common.merge_target`, a helper to merge target metadata such as
	`common.subdir`

In the C language backend, object output translation now respects
`target.common.subdir` by appending it to `config.common.objdir`.
