# Baochip Firmware Verification

Verify that the firmware on your Baochip corresponds to the public source code
by rebuilding it from source and comparing hashes, and verify the Ed25519
signatures on the official release images.

Read the next section before running anything. Verification here is meaningful
only relative to a specific set of assumptions, and knowing which ones you are
accepting is the difference between a useful check and a false sense of
security.

## What this verifies, and what it assumes

This document supports two separate claims. They have very different strengths,
and the second one is much weaker than it looks.

**Claim A — the published release corresponds to the published source.**
Established offline, without a device, by rebuilding under Guix and comparing
against the signed release image. This is a strong, self-contained result: it
rests only on Guix's channel authentication, the reproducibility of the build,
and the integrity of the source repositories.

**Claim B — your device is running that firmware.**
Established by comparing the release hashes against what your device's `audit`
command reports. This is *not* a proof. The `audit` command is a program that
runs on the device, in boot1, and prints an unauthenticated line of text over a
serial console. It measures boot0 and boot1 by reading them out of RRAM — that
is, the code under examination is measured by code that the same boot chain
authorized. There is no nonce, no signature, and no binding to the physical
device.

Claim B is therefore best understood as **tamper detection relative to the
factory**, not as verification of what is executing.

### The trust anchors

For the flow in this document to be sound, all of the following must hold. Only
the last group is something you can check yourself.

| # | Assumption | Why it cannot be checked here |
|---|-----------|-------------------------------|
| 1 | The foundry built the silicon as designed | Partially reduced by IRIS inspection: the number and size of memory macros can be checked against the published RTL, which bounds hidden storage. Not reduced for sub-resolution logic changes, dopant-level modification, or routing-only changes. |
| 2 | **Chip probe burned the released artifacts and engaged the write locks** | boot0, boot1, the public key anchors (both the data slots and their IFR copies) and the lock fuses are *all* written at chip probe. Every on-device integrity check compares against a value written at that same step, so a chip probe that burned a self-consistent alternate set is undetectable by any software means. This is the root assumption. |
| 3 | The Baochip signing key is uncompromised, and the artifact handoff to chip probe was intact | A validly signed image passes every check in this document. boot0's own signature is checked against keys embedded in boot0, so it does not protect the handoff. |
| 4 | The baobit commit names xous-core truthfully, and that source is benign | Nothing in this procedure reads the source. Reproducibility proves *provenance from a named source*, never that the source is safe. |
| 5 | The Guix bootstrap seed and toolchain are not backdoored | Trusting-trust. Inherited from Guix. |
| 6 | You ran `audit` yourself, on the device in your hand, reading from reset | A transcript from a third party establishes nothing at all. |
| 7 | The channel pins you build with are the ones your device named | Checkable — see Step 2. |
| 8 | Your device's security state is nominal | **Checkable — see Step 1b. This is the one group of assumptions this document can convert into evidence, and it costs nothing.** |

The single point everything rests on is **chip probe** (assumption 2), where
boot0, boot1, the public keys and the lock fuses are all written. If that step
was honest, later manufacturing stages are far more constrained: final test and
anything after it can only load *signed* code and can only advance monotonic
one-way counters, and both leave traces that `audit` prints. That is what the
state checks in Step 1b are for — they do not verify chip probe (nothing in
software can), but they detect the reachable tampering downstream of it.

If assumption 2 does not hold, nothing else in this document helps. There is no
on-device check that detects a dishonest chip probe, because the reference
values such a check would use are themselves written at chip probe.

## Prerequisites

- [GNU Guix](https://guix.gnu.org/) (for reproducible builds)
- `git`
- Internet access to fetch channel sources
- Serial access to your device (for Claim B only)

## Step 1: Read your device's state

Connect to your Baochip's serial console and run `audit`. Do this yourself, from
a power-on reset, and read the output from the first line — a later stage could
otherwise print a convincing-looking banner of its own.

```
Board type reads as: Dabao
Boot partition is: Ok(PrimaryPartition)
Semver is: v0.10.0-61-g5397e1b48
Stepping is: A1
...
Revocations:
Stage       key0     key1     key2     key3
boot0       enabled  enabled  enabled  enabled
boot1       enabled  enabled  enabled  enabled
next stage  enabled  enabled  enabled  enabled
Boot0: key 0/0 (bao1) -> 60000000
Boot1: key 0/0 (bao1) -> 60020000
...
auto-audit limit: 3
boot0 partition: 6fd9...
boot0 code only: 563802e7f10fd0ca0a1c700c6313eff624aa57d9cd88d3c33af4b720eff5480432e01c116925a324a96e12d92953d7cb6076ea4557a22058e1a61be4c2b4dee2
boot0 baobit toolchain: 441559d7e1984623ec0a52f60f90240c740b6c41
...
boot1 code only: e42b5aba61d98990ca24f5fc3b6cf012b14ea4d121f9bbe494baf4d9ae854d3ba88cdf26a288b88778826f816dc960c3ffe24b7c919108a3aca90f2dc4551a55
boot1 baobit toolchain: 441559d7e1984623ec0a52f60f90240c740b6c41
...
Boot1 receipts OK
Boot1 anti-rollback OK
```

### Step 1a: Record these values

- `boot0 code only` / `boot1 code only` — SHA-512 of the reproducible code region
- `boot0 partition` / `boot1 partition` — SHA-512 of the entire flash partition
- `baobit toolchain` — the **full 40-character** baobit commit that built the
  firmware. Use all 40 characters. Truncating to 8 leaves only 32 bits of
  identity, which is not enough to name a commit unambiguously.

### Step 1b: Check the security state

These lines are printed by the same `audit` run. Some of them can invalidate the
comparison you are about to make; others change what a successful comparison
means. Check every one of them.

| Check | Required | If it differs |
|-------|----------|---------------|
| `Stepping is:` | `A1` on production silicon | `A0` is pre-production (DEF CON 34 badges and current dev boards are A0). On A1 the RRAM code-area write protection is hard-wired on. On A0 the runtime control for that protection can be cleared (this is exactly what the stepping probe detects). Whether that alone makes boot0 rewritable, or whether a separate factory-burned write-lock still holds, is not established from public documentation. Treat A0 as offering a *weaker* immutability guarantee for boot0 than A1: on A0 you are relying more heavily on assumptions 2 and 8 and on the hash comparison itself. |
| `Boot partition is:` | `Ok(PrimaryPartition)` | On `AlternatePartition` the running boot1 is the image at `0x6006_0000`, but `audit` always hashes the partition at `0x6002_0000`. The reported `boot1 code only` is then for code that is **not executing**. |
| `Boot0:` / `Boot1: key n/n (tag)` | `bao1` or `bao2` | `dev` means the image is signed with the developer key, whose private half is public. Anyone can produce firmware this device will boot, so nothing it reports is trustworthy. `beta` is a test key. |
| `Revocations:` | all `enabled` | Revocations are monotonic and irreversible. If the Baochip keys are revoked and only `dev` remains, the device will accept firmware signed by anyone. |
| `== IN DEVELOPER MODE ==` | absent | The device has booted a developer-signed image at some point. Its secrets have been erased and its reported state is not attestable. |
| `== BOOT0/BOOT1 REPORTED PUBKEY CHECK FAILURE ==` | absent | The keys embedded in the boot images do not match the indelible reference copies. |
| `== BOOT1 FAILED PUBKEY CHECK ==` | absent | Same comparison, performed live during the audit. |
| `== CP SETUP FAILED ==` | absent | Factory provisioning did not complete. |
| `CM7 & debug confirmed fused off` | present | Otherwise hardware debug or the secondary core is enabled, and the device can be inspected or driven externally. |
| `Boot1 receipts OK` | present | The boot1 signing keys changed since the last boot. |
| `Boot1 anti-rollback OK` | present | The image's rollback counter disagrees with the device's. |
| `** System did not meet minimum requirements for security **` | **absent** | This line is printed if *any* of the above failed. Treat it as a hard stop. |

`AlternatePartition`, a `dev` signing key, and developer mode are the ones that
can make a successful hash comparison worthless — resolve those before
continuing. The rest narrow what the comparison establishes without negating it;
note them and read the relevant row.

## Step 2: Rebuild from source

Two methods. The first is recommended; it is also exactly how CI builds the
release, and it has no unauthenticated fetch step.

### Method A — build from a checkout (recommended)

```bash
# The full 40-character value from "baobit toolchain" in Step 1a
BAOBIT_COMMIT=441559d7e1984623ec0a52f60f90240c740b6c41

git clone https://github.com/sbellem/baobit && cd baobit
git checkout "${BAOBIT_COMMIT}"

make boot0 ROOT=boot0
make boot1 ROOT=boot1
```

Everything needed is pinned by the commit you just checked out: `make` builds
with `guix time-machine --channels=channels/guix.scm -- build -L packages`, so
the Guix revision comes from `channels/guix.scm` *at that commit* and the
package definitions come from the working tree *at that commit*. Nothing is
fetched from a mutable branch, and `git` verifies that you got the commit your
device named.

`ROOT=` creates a garbage-collector root symlinked to the build output:

```
boot0 -> /gnu/store/0d18xr4wlwkhycz6m96ds60mk2w9vc22-bao1x-boot0-v0.10.0-61-g5397e1b48
```

### Method B — build from a channels file

A channels file pins both `guix` and `baobit` explicitly, so it can be used
without a checkout. Pre-generated files are published for convenience:

```bash
curl --proto '=https' --tlsv1.2 -sSfLo baobit.scm \
  "https://raw.githubusercontent.com/sbellem/baobit/refs/heads/main/channels/baobit.${BAOBIT_COMMIT:0:8}.scm"
```

**This download is a convenience, not a trust anchor.** It comes from a mutable
branch and is addressed by a 32-bit prefix, and the file itself carries the
channel introductions that bootstrap all subsequent Guix authentication.
Inspect it before use and confirm all three of the following:

1. The `baobit` channel's `commit` equals the **full 40-character**
   `baobit toolchain` value from Step 1a.
2. The `baobit` channel introduction matches:
   ```
   commit:      06e8707cac44731b16bfc46b3fb5c34427fc5efe
   fingerprint: E39D 2B3D 0564 BA43 7BD9  2756 C38A E0EC CAB7 D5C8
   ```
3. The `guix` channel introduction is the standard upstream one:
   ```
   commit:      9edb3f66fd807b096b48283debdcddccfea34bad
   fingerprint: BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA
   ```
   The `guix` channel *URL* may point at a mirror rather than upstream. That is
   acceptable as long as this introduction is unchanged, because Guix
   authenticates every commit from the introduction forward against
   `.guix-authorizations`; a mirror cannot introduce unauthorized commits.

Once verified:

```bash
guix time-machine --channels=baobit.scm -- build bao1x-boot0 --root=boot0
guix time-machine --channels=baobit.scm -- build bao1x-boot1 --root=boot1
```

If you cannot satisfy the three checks above, use Method A instead.

### Force an independent rebuild

Either method may be satisfied from a substitute server rather than compiled
locally. That is not a security failure — the narinfo signature is checked
against your authorized keys, the download's hash is checked against the
narinfo, and Guix only requests a substitute for a store path it derived
locally, so a hit already proves that you and the server agree on every build
input.

It does mean, though, that you have verified *input agreement* rather than
*output reproducibility*. To actually rebuild and confirm the result is
bit-identical:

```bash
make boot0 CHECK=1          # Method A
make boot1 CHECK=1
```

```bash
guix time-machine --channels=baobit.scm -- build bao1x-boot0 --check   # Method B
guix time-machine --channels=baobit.scm -- build bao1x-boot1 --check
```

This runs `guix build --check`, which rebuilds locally and errors if the result
differs from what is already in the store — so it also detects a substitute
server that served something other than the reproducible build.

## Step 3: Compare hashes

Hash the presign images — the firmware code without the signature block — and
compare against the audit output:

```bash
sha512sum boot0/bao1x-boot0-presign.img
sha512sum boot1/bao1x-boot1-presign.img
```

Or check directly:

```bash
echo "563802e7f10fd0ca0a1c700c6313eff624aa57d9cd88d3c33af4b720eff5480432e01c116925a324a96e12d92953d7cb6076ea4557a22058e1a61be4c2b4dee2  boot0/bao1x-boot0-presign.img" | sha512sum --check --strict
boot0/bao1x-boot0-presign.img: OK
```

### What this hash covers

`code only` covers the code region *after* the 768-byte signature block, for
`signed_len` bytes. It deliberately excludes the signature block, because that
block is patched after the build and is not reproducible.

Consequently a match says **nothing** about the contents of the signature
block — the embedded public keys, the function code, the anti-rollback counter,
the semver string, or the toolchain field. Those are covered by the Ed25519
signature (Step 4) and by the state checks in Step 1b, not by this comparison.

It also does not cover unused space in the flash partition. The `boot0 partition`
value from Step 1a hashes the whole partition and would cover it; see Step 5.

## Step 4: Verify signatures on official release images

Official signed firmware images are published at
`https://ci.betrusted.io/releases/`. Verify their Ed25519 signatures with the
`verify-binary` tool.

### Build the tool

```bash
guix shell nss-certs rust rust:cargo -- cargo build --release --manifest-path tools/Cargo.toml
```

If you already have a Rust toolchain:

```bash
cd tools && cargo build --release && cd ..
```

Or download a pre-built binary from the
[releases page](https://github.com/sbellem/baobit/releases).

### Download and verify

```bash
VERSION=v0.10.0
RELEASES_URL="https://ci.betrusted.io/releases/${VERSION}/baochip/bootloader"
curl --proto '=https' --tlsv1.2 -sSfLO "${RELEASES_URL}/bao1x-boot0.img"
curl --proto '=https' --tlsv1.2 -sSfLO "${RELEASES_URL}/bao1x-boot1.img"

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

Confirm that `Signing Key` is a Baochip production key (`bao1` or `bao2`). A
`PASSED` result with the `developer` key means only that a publicly-known key
produced a valid signature.

## Step 5: Cross-check

| Source | What it provides |
|--------|-----------------|
| Device audit | `code only` and `partition` SHA-512, plus the baobit commit |
| Your build | Presign images rebuilt from source |
| Official release | Signed `.img` files from ci.betrusted.io |

The following must all agree:

- `Presign SHA512` from `verify-binary` **==** `boot0 code only` from the audit
- `sha512sum` of your rebuilt `bao1x-boot0-presign.img` **==** the same value
- The same three-way match for boot1

`hashes.txt` in a baobit GitHub release contains SHA-512 sums of the **presign**
images, so it should match your rebuild and the `Presign SHA512` line — not the
`Padded SHA512` line.

`Padded SHA512` is the signed image zero-padded to the full partition size
(128 KiB for boot0, 256 KiB for boot1). It is the value to compare against a
partition-level hash such as `boot0 partition` from the audit, but only if the
unused tail of the partition is known to be zero-filled on your device. Treat a
mismatch here as inconclusive rather than as evidence of tampering, unless you
have confirmed the padding convention for your hardware revision.

## What a match does and does not prove

**Does prove**, given assumptions 1–7 above:

- The code region of the release images is byte-identical to a build from the
  named baobit commit.
- The official release images carry valid Ed25519 signatures from a known
  Baochip key.
- Your build is reproducible and independently produces the same bytes.

**Does not prove:**

- That the source is benign. No step here reads xous-core.
- That the bytes reported are the bytes executing. The measurement comes from
  boot1, which boot0 authorized, and there is no independent path to read boot0.
  On A0 silicon the guarantee is weaker still — see the `Stepping` row in
  Step 1b.
- Anything at all, if chip probe was dishonest (assumption 2). Every reference
  value the device compares against is written at that step.

Stated minimally, and without assumptions: a program resident on your device
printed a hash equal to that of an image you built from a baobit commit whose
identity that same program asserted. Everything beyond that comes from the
assumptions above.

## Troubleshooting

### Build takes a long time
The first build compiles the Rust toolchain from source, which requires
significant time and disk space. Subsequent builds are faster due to caching.
Pass `SUBS=all` (the default) to use the available substitute servers.

### Hash mismatch
1. Confirm you used the **full 40-character** baobit commit from the audit, not
   a truncation.
2. Re-check Step 1b. A device on `AlternatePartition` reports a `boot1 code only`
   hash for a partition that is not running.
3. Verify reproducibility of your own build:
   ```bash
   make boot0 CHECK=1
   ```
4. File an issue at https://github.com/sbellem/baobit/issues.

### `audit` output is missing fields
Older firmware prints fewer lines; `Stepping is:` in particular was added after
the v0.9 series. If a check in Step 1b has no corresponding line, you cannot
discharge that assumption on this firmware revision.
