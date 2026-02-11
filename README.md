# baobit

Guix channel for reproducible xous-core builds.

## Updating xous-core

1. Edit `packages/xous-core-config.scm` - set `%xous-commit`
2. Run `make xous-core-info` - computes hash and updates config
3. Run `make boot0` to build

If `git describe` fails with "No names found", increase `%xous-clone-depth`.