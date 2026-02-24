# Baochip Bootloader Verification
This guide explains how to verify that the bootloader firmware on your Baochip
is authentic and matches the source code.

There are two levels of verification:

1. **Signature verification** -- verify that the `.img` files carry valid
   Ed25519 signatures from a known Baochip signing key.
2. **Reproducible build verification** -- rebuild the firmware from source
   with Guix and compare hashes against what the device reports.

## Prerequisites
- [Rust toolchain](https://rustup.rs/) (for `verify-binary`)
- [GNU Guix](https://guix.gnu.org/) (for reproducible builds)
- Internet access to fetch channel sources

## Step 1: Run the Audit Command
Run the `audit` command on your Baochip to get the firmware information:

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

Note the following values:
- `boot0 code only` -- the SHA-512 hash to verify against the expected source code
- `boot1 code only` -- the SHA-512 hash to verify against the expected source code
- `baobit toolchain` -- the baobit commit used to build the bootloaders

## Step 2: Verify Signatures
The `verify-binary` tool in `tools/` parses signed `.img` files, checks their
Ed25519ph or FIDO2 signatures against the embedded public keys, and reports
the hashes.

### Build the tool
```bash
cd tools
cargo build --release
```

### Verify the images
```bash
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

If verification passes, the firmware image carries a valid signature from a
known Baochip key. The `Presign SHA512` value should match `boot0 code only`
(or `boot1 code only`) from the audit output. The `Padded SHA512` matches
the official release hashes at `ci.betrusted.io`.

## Step 3: Reproducible Build (Optional)
For full verification, rebuild the firmware from source and compare hashes.

### Download the channels file
1. Set `BAOBIT_COMMIT_SHORT` to the baobit toolchain commit, **truncated to 8 characters**,
from the audit output:

```bash
BAOBIT_COMMIT_SHORT=441559d7
```

2. Download the channels file:
```bash
curl --proto '=https' --tlsv1.2 -sSfLo baobit.scm "https://raw.githubusercontent.com/sbellem/baobit/refs/heads/main/channels/baobit.${BAOBIT_COMMIT_SHORT}.scm"
```

### Build the firmware
Build `bao1x-boot0` and `bao1x-boot1` using `guix time-machine`:

```bash
guix time-machine --channels=baobit.scm -- build bao1x-boot0 --root=boot0
guix time-machine --channels=baobit.scm -- build bao1x-boot1 --root=boot1
```

The output will be under the directory passed to `--root`, which will be a symlink to
the store path, e.g.:
```bash
/gnu/store/abc123...-bao1x-boot0
```

### Compare hashes
Hash the built firmware and compare against the audit output:

```bash
sha512sum boot0/bao1x-boot0-presign.img
sha512sum boot1/bao1x-boot1-presign.img
```

Compare these hashes with the `boot0 code only` and `boot1 code only` values
from the audit output:

```bash
echo "563802e7f10fd0ca0a1c700c6313eff624aa57d9cd88d3c33af4b720eff5480432e01c116925a324a96e12d92953d7cb6076ea4557a22058e1a61be4c2b4dee2 boot0/bao1x-boot0-presign.img" | sha512sum --check --strict
boot0/bao1x-boot0-presign.img: OK
```

If hashes match, you know:
1. The signature on the image is valid (Step 2)
2. The firmware is identical to what you built from source
3. The signing key is one of the known Baochip keys

## Troubleshooting
### Build takes a long time
The first build downloads and compiles the Rust toolchain, which can take significant
time and disk space. Subsequent builds will be faster due to caching.

### Substitutes
To speed up builds, you can use substitute servers if available:
```bash
guix time-machine --channels=baobit.scm -- build bao1x-boot0 \
  --substitute-urls="https://ci.guix.moe https://bordeaux.guix.gnu.org"
```

### Hash mismatch
If the hashes don't match:
1. Ensure you're using the exact baobit commit from the audit output
2. Verify your Guix installation is working correctly
3. Try building with `--check` to verify reproducibility:
   ```bash
   guix time-machine --channels=baobit.scm -- build bao1x-boot0 --check
   ```
4. File an issue at https://github.com/sbellem/baobit/issues.
