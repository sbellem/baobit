<p align="center">
  <img src="logo-dark.jpeg" alt="baobit logo" width="900">
</p>

![Build bootloader](https://github.com/sbellem/baobit/actions/workflows/bootloader.yml/badge.svg)
![Build dabao](https://github.com/sbellem/baobit/actions/workflows/dabao.yml/badge.svg)
![Build baosec](https://github.com/sbellem/baobit/actions/workflows/baosec.yml/badge.svg)

# baobit

Reproducible build toolchain for [Baochip][] firmware. Rebuild from source
and verify that the firmware on your device matches the public source code.

> **DEF CON 34 badge?** Start with **[DC34.md](DC34.md)** — a self-contained
> walkthrough calibrated to the badge's hardware and firmware, including the
> board-specific package to build and how to read the `audit` output.

## Prerequisites

Install [GNU Guix](https://guix.gnu.org/manual/1.5.0/en/html_node/Installation.html)
on your host system. Guix is required for all build and verification workflows.

## 1. Verify Your Device

Run `audit` on your Baochip to get the firmware hashes and the baobit commit
that built it. Then rebuild from source and compare.

### From a checkout (recommended)

```bash
# The full 40-character "baobit toolchain" value from audit
BAOBIT_COMMIT=441559d7e1984623ec0a52f60f90240c740b6c41

git clone https://github.com/sbellem/baobit && cd baobit
git checkout "${BAOBIT_COMMIT}"

make boot0 ROOT=boot0
make boot1 ROOT=boot1
```

Everything is pinned by the commit you checked out: the Guix revision comes
from `channels/guix.scm` at that commit, the package definitions from that
same tree. Nothing is fetched from a mutable branch.

### From a channels file (quick check)

```bash
curl --proto '=https' --tlsv1.2 -sSfLo baobit.scm \
  "https://raw.githubusercontent.com/sbellem/baobit/refs/heads/main/channels/baobit.${BAOBIT_COMMIT:0:8}.scm"

guix time-machine --channels=baobit.scm -- build bao1x-boot0 --root=boot0
guix time-machine --channels=baobit.scm -- build bao1x-boot1 --root=boot1
```

**Inspect `baobit.scm` before using it.** It is fetched from a mutable branch,
addressed by a 32-bit prefix, and it carries the channel introductions that
bootstrap all subsequent Guix authentication — so whoever controls that file
controls what "authenticated" means. Confirm its `baobit` commit is the full
value from your audit, and that both introductions match the ones published in
[VERIFY.md](VERIFY.md).

### Compare

```bash
sha512sum boot0/bao1x-boot0-presign.img   # should match "boot0 code only"
sha512sum boot1/bao1x-boot1-presign.img   # should match "boot1 code only"
```

Guix may satisfy a build from a substitute server rather than compiling it
locally, in which case you have confirmed that your build inputs agree with the
server's — not that you reproduced the output. To force an independent local
rebuild and error out if the result is not bit-identical:

```bash
make boot0 CHECK=1
make boot1 CHECK=1
```

A match shows the code region on your device is byte-identical to a build from
the named baobit commit. It does **not** prove those bytes are what is
executing — the hashes are reported by `audit`, which runs in boot1, over an
unauthenticated serial console.

See [VERIFY.md](VERIFY.md) for the full guide, the device state checklist, and
the trust assumptions the whole procedure rests on.

## 2. Verify Official Release Images

Official signed firmware images are published at
`https://ci.betrusted.io/releases/`. Download them and verify their Ed25519
signatures and presign hashes using the `verify-binary` tool.

```bash
git clone https://github.com/sbellem/baobit && cd baobit

# Build the signature verifier
guix shell nss-certs rust rust:cargo -- cargo build --release --manifest-path tools/Cargo.toml

# Download signed images and verify
VERSION=v0.10.0
RELEASES_URL="https://ci.betrusted.io/releases/${VERSION}/baochip"
curl --proto '=https' --tlsv1.2 -sSfLO ${RELEASES_URL}/baochip/bootloader/bao1x-boot0.img"
curl --proto '=https' --tlsv1.2 -sSfLO ${RELEASES_URL}/baochip/bootloader/bao1x-boot1.img"

./tools/target/release/verify-binary bao1x-boot0.img bao1x-boot1.img
```

The `Presign SHA512` from `verify-binary` should match `boot0 code only` /
`boot1 code only` from your device's audit output.

## 3. Build Firmware from Source

Build individual packages or the full firmware stack:

```bash
# Build a single package
make boot0

# Build all bootloaders
make bootloader

# Build all production artifacts
make manifest
```

Verify reproducibility by rebuilding and comparing:

```bash
make CHECK=1 boot0
```

Run `make help` for the full list of targets and options.

## 4. Preparing a Release

Firmware builds are published at `https://ci.betrusted.io/releases/`. To
prepare a new release:

1. Edit `baobit.toml` with the target xous-core commit, then regenerate
   the config:
   ```bash
   make update-config
   ```
2. Build and verify all bootloaders:
   ```bash
   make bootloader
   make CHECK=1 bootloader
   ```
3. Generate the channel file for the release commit:
   ```
   channels/baobit.<SHORT_COMMIT>.scm
   ```
4. Tag and push to trigger the release workflow.

## Packages

This Guix channel provides packages for all [Baochip][] firmware components.
The firmware source code is part of the [Xous microkernel][xous-core] repository.

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

## Links

- [xous-core][] -- Xous operating system source, containing the Baochip firmware
- [Baochip][] -- Open hardware security device

[xous-core]: https://github.com/betrusted-io/xous-core
[baochip]: https://baochip.com
