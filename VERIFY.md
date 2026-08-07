# Baochip Firmware Verification

Verify that the firmware on your Baochip matches the public source code by
rebuilding it from source and comparing hashes. Optionally verify Ed25519
signatures on the official release images.

## Trust model

This procedure is useful only within a set of assumptions. Stating them is what
tells you exactly what a hash match does and does not establish.

**The measurement runs in boot1.** The hashes come from the `audit` command,
which executes *in `boot1`*: it reads `boot0` and `boot1` out of RRAM and prints
their SHA-512. The report is therefore only as honest as the `boot1` producing it.

**You supply `boot1`, so the measurer is trusted by construction.** In this model
you either build `boot1` from source and install it yourself, or you install an
official image only after confirming its presign hash equals your own build
(Step 3). Either way, the boot1 doing the measuring is one you have verified —
its honesty is established, not assumed.

**The one root assumption is an honest chip probe (CP).** `boot0`, the reference
public keys, and the write-locks that protect them are all burned at the chip
probe stage of manufacturing. Every on-device check compares against a value
written there, so a dishonest CP cannot be detected in software. Given a correct
CP, `boot0` is genuine and immutable, so it faithfully launches the `boot1` you
installed, which in turn reports the true contents of RRAM.

**What a match therefore means.** If CP was honest and your rebuilt hashes match
the audit output, the `boot0` and `boot1` actually resident on your device are the
images built from the published source. If CP was *not* honest, this procedure
establishes nothing - and no software check can tell the difference.

**Residual assumptions, even with an honest CP:**

- **`boot0` has not been altered since CP**. This procedure does not verify it.
  The audit only reports what is in RRAM, it cannot prove `boot0` is write-locked, so
  `boot0` immutability is an assumption. It rests on a write-lock set at
  manufacturing; whether that lock is in force depends on the silicon and on
  production provisioning, and should not be assumed on pre-production (**A0**)
  silicon without confirming the board.
- **The silicon returns the true contents of RRAM when `boot1` reads it, no shadow
  memory or read remapping.** This is a hardware assumption, addressable only by
  physical inspection (e.g. IRIS), not by this procedure.

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

If hashes match, the `boot0` and `boot1` resident in your device's RRAM are
identical to what you built from the public source code — subject to the
assumptions in [Trust model](#trust-model) above.

## DEF CON 34 badges

Badges report `Board type reads as: Oem` and differ from the flow above in three
ways:

1. **`boot0` and `boot1` were built from different baobit commits.** Use each
   image's own `baobit toolchain` value.
2. **`boot1` is the "lite" variant** - build `bao1x-boot1-lite`, not
   `bao1x-boot1`.
3. **Badges are A0 (pre-production) silicon.** `boot0`'s on-chip write protection
   was set during production.

For a badge running `v0.10.1-0-gbcfdca404` the commits are `441559d7` (boot0)
and `4be6e2d6` (boot1). Substitute the values your own `audit` reports:

```bash
# boot0 -- its "boot0 baobit toolchain" commit
curl --proto '=https' --tlsv1.2 -sSfLo boot0.scm \
  "https://raw.githubusercontent.com/sbellem/baobit/refs/heads/main/channels/baobit.441559d7.scm"
guix time-machine --channels=boot0.scm -- build bao1x-boot0 --root=boot0

# boot1 -- its "boot1 baobit toolchain" commit; note the -lite package
curl --proto '=https' --tlsv1.2 -sSfLo boot1.scm \
  "https://raw.githubusercontent.com/sbellem/baobit/refs/heads/main/channels/baobit.4be6e2d6.scm"
guix time-machine --channels=boot1.scm -- build bao1x-boot1-lite --root=boot1

sha512sum boot0/bao1x-boot0-presign.img   # match "boot0 code only"
sha512sum boot1/bao1x-boot1-presign.img   # match "boot1 code only"
```

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

If all three agree, then under the [Trust model](#trust-model) above:
1. The firmware resident on your device matches the public source code
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
