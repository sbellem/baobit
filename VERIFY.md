# Baochip Firmware Verification

Verify that the firmware on your Baochip matches the public source code by
rebuilding it from source and comparing hashes. Optionally verify Ed25519
signatures on the official release images.

## Prerequisites

- [GNU Guix](https://guix.gnu.org/) (for reproducible builds)
- Internet access to fetch channel sources

## Step 1: Get Audit Data from Your Device

Run the `audit` command on your Baochip:

```
Configured board type: Dabao
Board type reads as: Dabao
Boot partition is: Ok(PrimaryPartition)
Semver is: v0.10.0-61-g5397e1b48
...
boot0 code only: 563802e7f10fd0ca0a1c700c6313eff624aa57d9cd88d3c33af4b720eff5480432e01c116925a324a96e12d92953d7cb6076ea4557a22058e1a61be4c2b4dee2
boot0 baobit toolchain: 441559d7e1984623ec0a52f60f90240c740b6c41
...
boot1 code only: e42b5aba61d98990ca24f5fc3b6cf012b14ea4d121f9bbe494baf4d9ae854d3ba88cdf26a288b88778826f816dc960c3ffe24b7c919108a3aca90f2dc4551a55
boot1 baobit toolchain: 441559d7e1984623ec0a52f60f90240c740b6c41
...
Boot1 receipts OK
Boot1 anti-rollback OK
```

Note these values:
- `boot0 code only` / `boot1 code only` -- SHA-512 hashes of the firmware code
- `baobit toolchain` -- the baobit commit used to build the bootloaders

## Step 2: Rebuild from Source

Download the channels file for your device's baobit commit and rebuild:

```bash
# Truncate the baobit commit to 8 characters
BAOBIT_COMMIT_SHORT=441559d7

# Download the channels file
curl --proto '=https' --tlsv1.2 -sSfLo baobit.scm \
  "https://raw.githubusercontent.com/sbellem/baobit/refs/heads/main/channels/baobit.${BAOBIT_COMMIT_SHORT}.scm"

# Build the bootloaders
guix time-machine --channels=baobit.scm -- build bao1x-boot0 --root=boot0
guix time-machine --channels=baobit.scm -- build bao1x-boot1 --root=boot1
```

The `--root` flag creates a symlink to the build output, e.g.:
```
boot0 -> /gnu/store/0d18xr4wlwkhycz6m96ds60mk2w9vc22-bao1x-boot0-v0.10.0-61-g5397e1b48
```

## Step 3: Compare Hashes

Hash the presign images (firmware code without the signature block) and
compare against the audit output:

```bash
sha512sum boot0/bao1x-boot0-presign.img
sha512sum boot1/bao1x-boot1-presign.img
```

Verify directly:

```bash
echo "563802e7f10fd0ca0a1c700c6313eff624aa57d9cd88d3c33af4b720eff5480432e01c116925a324a96e12d92953d7cb6076ea4557a22058e1a61be4c2b4dee2  boot0/bao1x-boot0-presign.img" | sha512sum --check --strict
boot0/bao1x-boot0-presign.img: OK
```

If hashes match, the firmware on your device is identical to what you built
from the public source code.

## Step 4: Verify Signatures on Official Release Images

Official signed firmware images are published at
`https://ci.betrusted.io/releases/`. Download them and verify their Ed25519
signatures using the `verify-binary` tool.

### Build the tool

```bash
git clone https://github.com/sbellem/baobit && cd baobit
guix shell nss-certs rust rust:cargo -- cargo build --release --manifest-path tools/Cargo.toml
```

If you already have a Rust toolchain installed, you can use it directly:

```bash
cd tools && cargo build --release && cd ..
```

Or download a pre-built binary from the
[releases page](https://github.com/sbellem/baobit/releases).

### Download and verify

```bash
VERSION=v0.10.0
RELEASES_URL="https://ci.betrusted.io/releases/${VERSION}/baochip"
curl --proto '=https' --tlsv1.2 -sSfLO ${RELEASES_URL}/baochip/bootloader/bao1x-boot0.img"
curl --proto '=https' --tlsv1.2 -sSfLO ${RELEASES_URL}/baochip/bootloader/bao1x-boot1.img"

./tools/target/release/verify-binary bao1x-boot0.img bao1x-boot1.img
```

Example output:
```
File:           bao1x-boot0.img (93296 bytes)
Function:       Boot0
Mode:           FIDO2
Signed SHA512:  e9f3f6d9...
Presign SHA512: 563802e7...
Padded SHA512:  a0680a73... (zero-padded to 131072 bytes)
Signature:      f527009b...
Signing Key:    a87a5f98... (bao1)
Version:        0x100
Anti-rollback:  1
Verification:   PASSED
```

## Step 5: Cross-Check All Three Sources

At this point you have three independent sources of truth:

| Source | What it provides |
|--------|-----------------|
| Device audit | `code only` SHA-512 hashes + baobit commit |
| Your build | Presign images rebuilt from source |
| Official release | Signed `.img` files from ci.betrusted.io |

Verify consistency:

- **`Presign SHA512`** from `verify-binary` should match **`boot0 code only`**
  (or `boot1 code only`) from the device audit.
- **`sha512sum`** of your rebuilt `bao1x-boot0-presign.img` should match the
  same `boot0 code only` hash.
- **`Padded SHA512`** from `verify-binary` should match the corresponding hash
  in the release `hashes.txt`.

If all three agree:
1. The firmware on your device matches the public source code
2. The official release images carry valid signatures from a known Baochip key
3. Your reproducible build produces the same binary

## Troubleshooting

### Build takes a long time
The first build compiles the Rust toolchain from source, which requires
significant time and disk space. Subsequent builds are faster due to caching.

### Hash mismatch
1. Ensure you're using the exact baobit commit from the audit output.
2. Verify your Guix installation is working correctly.
3. Try building with `--check` to verify reproducibility:
   ```bash
   guix time-machine --channels=baobit.scm -- build bao1x-boot0 --check
   ```
4. File an issue at https://github.com/sbellem/baobit/issues.
