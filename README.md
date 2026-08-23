<p align="center">
  <img src="logo-dark.jpeg" alt="baobit logo" width="900">
</p>

![Build bootloader](https://github.com/sbellem/baobit/actions/workflows/bootloader.yml/badge.svg)
![Build dabao](https://github.com/sbellem/baobit/actions/workflows/dabao.yml/badge.svg)
![Build baosec](https://github.com/sbellem/baobit/actions/workflows/baosec.yml/badge.svg)

# baobit

Reproducible build toolchain for [Baochip][] firmware. Rebuild from source
and verify that the firmware on your device matches the public source code.

> [!TIP]
> **DEFCON 34 Badges**
>
> See [VERIFY.md](VERIFY.md#def-con-34-badges) to check the bootloader firmware running on your badge.

## Prerequisites

Install [GNU Guix](https://guix.gnu.org/manual/1.5.0/en/html_node/Installation.html)
on your host system. Guix is required for all build and verification workflows.

## 1. Verify Your Device

Run `audit` on your Baochip to get the firmware hashes and the baobit commit
that built it. Then rebuild from source and compare.

```bash
BAOBIT_COMMIT_SHORT=441559d7   # first 8 chars of "baobit toolchain" from audit

curl --proto '=https' --tlsv1.2 -sSfLo baobit.scm \
  "https://raw.githubusercontent.com/sbellem/baobit/refs/heads/main/channels/baobit.${BAOBIT_COMMIT_SHORT}.scm"

guix time-machine --channels=baobit.scm -- build bao1x-boot0 --root=boot0
guix time-machine --channels=baobit.scm -- build bao1x-boot1 --root=boot1

sha512sum boot0/bao1x-boot0-presign.img   # should match "boot0 code only"
sha512sum boot1/bao1x-boot1-presign.img   # should match "boot1 code only"
```

If the hashes match, the boot0 and boot1 resident on your device are identical
to what you built from the public source code — subject to a set of trust
assumptions, chiefly an honest chip-probe (factory provisioning) step. What the
match does and does not establish is spelled out in the
[Trust model](VERIFY.md#trust-model).

See [VERIFY.md](VERIFY.md) for the full step-by-step guide.

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
