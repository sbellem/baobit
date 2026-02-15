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
# Add channel to ~/.config/guix/channels.scm
guix pull

# Build bootloader
guix time-machine -C channels.scm -- build -L packages bao1x-boot0

# Or use make
make boot0
```

## Configuration

All release parameters are in `packages/xous-config.scm`:

| Variable | Description |
|----------|-------------|
| `%xous-commit` | Target xous-core commit |
| `%xous-git-describe` | Git describe output (set by `make xous-core-info`) |
| `%xous-guix-hash` | Source hash (set by `make xous-core-info`) |
| `%xous-owner` | GitHub owner (default: `betrusted-io`) |
| `%rust-version` | Rust toolchain version (e.g., `"1.90"`) |
| `%rust-xous-commit` | betrusted-io/rust fork commit (must match `%rust-version`) |
| `%rust-xous-guix-hash` | betrusted-io/rust source hash |

## Updating xous-core

```bash
make update-config XOUS_CORE_COMMIT=abc123def...
make boot0
```

This computes and updates `%xous-commit`, `%xous-git-describe`, and `%xous-guix-hash`.

If `git describe` fails with "No names found", pass a larger clone depth:
```bash
make update-config XOUS_CORE_COMMIT=abc123 CLONE_DEPTH=100
```

To update betrusted-io/rust as well:
```bash
make update-config XOUS_CORE_COMMIT=abc123 RUST_XOUS_COMMIT=def456
```

## Reproducibility

Builds are verified reproducible via:
```bash
make CHECK=1 boot0
```

Build all production artifacts at once:
```bash
guix time-machine -C channels.scm -- build -L packages -m manifest.scm
```

Artifact hashes (SHA256 + MD5) are reported in CI job summaries.

## Related Projects

- [xous-core](https://github.com/betrusted-io/xous-core) - Xous operating system
- [Baochip](https://baochip.com/) - Open hardware security device
