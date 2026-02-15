<p align="center">
  <img src="logo-dark.jpeg" alt="baobit logo" width="900">
</p>

# baobit

Guix channel for reproducible [Baochip](https://baochip.com/) firmware builds.

![Build bootloader](https://github.com/sbellem/baobit/actions/workflows/bootloader.yml/badge.svg)
![Build packages](https://github.com/sbellem/baobit/actions/workflows/build.yml/badge.svg)

## Overview

This channel provides Guix packages for building Baochip/Xous firmware with full reproducibility. All builds are verified with `guix build --check`.

### Packages

| Package | Description |
|---------|-------------|
| `bao1x-boot0` | Stage 0 bootloader |
| `bao1x-boot1` | Stage 1 bootloader |
| `bao1x-alt-boot1` | Alternative stage 1 bootloader |
| `bao1x-baremetal-dabao` | Bare-metal dabao |
| `dabao` | Dabao firmware |
| `dabao-helloworld` | Dabao helloworld example |
| `baosec` | Baosec firmware |
| `rust-xous-toolchain` | Complete Rust toolchain for Xous |

## Quick Start

```bash
# Update to a new xous-core commit (computes hash and git-describe automatically)
make update-config XOUS_CORE_COMMIT=abc123def...

# Build bootloader
make boot0

# Or build all production artifacts
make manifest
```

## Configuration

All release parameters are in `packages/xous-config.scm`:

| Variable | Description |
|----------|-------------|
| `%xous-commit` | Target xous-core commit |
| `%xous-git-describe` | Git describe output (set by `make update-config`) |
| `%xous-guix-hash` | Source hash (set by `make update-config`) |
| `%xous-owner` | GitHub owner (default: `betrusted-io`) |
| `%rust-version` | Rust toolchain version (e.g., `"1.90"`) |
| `%rust-xous-commit` | betrusted-io/rust fork commit (must match `%rust-version`) |
| `%rust-xous-guix-hash` | betrusted-io/rust source hash |

## Updating Configuration

The `update-config` target computes and updates commit hashes, `git describe` output, and `guix hash` values.

```bash
# Update xous-core only
make update-config XOUS_CORE_COMMIT=abc123def...

# Update both xous-core and betrusted-io/rust
make update-config XOUS_CORE_COMMIT=abc123 RUST_XOUS_COMMIT=def456

# If git describe fails with "No names found", use a larger clone depth
make update-config XOUS_CORE_COMMIT=abc123 CLONE_DEPTH=100
```

## Reproducibility

Verify builds are reproducible:
```bash
make CHECK=1 boot0
make CHECK=1 manifest
```

Artifact hashes (SHA256 + MD5) are reported in CI job summaries.

## Related Projects

- [xous-core](https://github.com/betrusted-io/xous-core) - Xous operating system
- [Baochip](https://baochip.com/) - Open hardware security device
