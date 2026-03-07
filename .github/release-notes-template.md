## Reproducible Bootloader Build

Independent build of the Baochip ${UPSTREAM_TAG} bootloader firmware from
source using [GNU Guix](https://guix.gnu.org/). The presign images below
should be **bit-for-bit identical** to the
[official betrusted-io release](https://ci.betrusted.io/releases/${UPSTREAM_TAG}/baochip/bootloader/).

### Verify

Download the presign images from both releases and compare:

```bash
# From this release (baobit)
for f in bao1x-boot0-presign.img bao1x-boot1-presign.img bao1x-alt-boot1-presign.img; do
  curl -sSfLO "https://github.com/sbellem/baobit/releases/download/${TAG}/$f"
done

# From official release (betrusted-io)
for f in bao1x-boot0-presign.img bao1x-boot1-presign.img bao1x-alt-boot1-presign.img; do
  curl -sSfLo "official-$f" "https://ci.betrusted.io/releases/${UPSTREAM_TAG}/baochip/bootloader/$f"
done

# Compare
sha512sum *-presign.img
```

If hashes match, the official release binary was built from the published
source code.

For full verification instructions (including device-level checks), see
[VERIFY.md](https://github.com/sbellem/baobit/blob/main/VERIFY.md).

### Assets

| File | Description |
|------|-------------|
| `bao1x-boot0-presign.img` | Stage 0 bootloader (unsigned) |
| `bao1x-boot1-presign.img` | Stage 1 bootloader (unsigned) |
| `bao1x-alt-boot1-presign.img` | Alt stage 1 bootloader (unsigned) |
| `hashes.txt` | SHA-512 checksums for all files |
| `sums.txt` | MD5 checksums for all files |
| `baobit.${REV}.scm` | Guix channels file for reproducing this build |
| `elf-analysis.tar.gz` | Bootloader ELF analysis reports |
| `supplementary-images.tar.gz` | All other firmware images (dev-key signed) |

> **Note:** Signed `.img` and `.uf2` files in the supplementary archive use
> development keys. For production firmware, download from the
> [official release](https://ci.betrusted.io/releases/${UPSTREAM_TAG}/baochip/bootloader/).

### Reproduce This Build

```bash
curl -sSfLO "https://github.com/sbellem/baobit/releases/download/${TAG}/baobit.${REV}.scm"
guix time-machine --channels=baobit.${REV}.scm -- build bao1x-boot0
guix time-machine --channels=baobit.${REV}.scm -- build bao1x-boot1
```

### Signature Verification

${VERIFY_NOTE}
