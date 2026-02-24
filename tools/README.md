# verify-binary

Parse and verify signed Baochip firmware images (.img files).

Reads the `SignatureInFlash` structure directly from binary images, computes SHA-512 hashes, and verifies Ed25519ph or FIDO2 signatures using the embedded public keys.

## Build

```bash
cargo build --release
```

## Usage

```bash
# Verify one or more images
verify-binary boot0.img boot1.img

# Extract presign data (original code before signing)
verify-binary boot0.img --output-presign presign.bin
```

## Output

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
Embedded keys:
  a87a5f98... (bao1) [bao1]
  79135dc6... (bao2) [bao2]
  80979929... (beta) [beta]
  1c9beae3... (developer) [dev]
Verification:   PASSED
```

## Signature modes

| Mode | Condition | Verification |
|------|-----------|--------------|
| Ed25519ph | `aad_len == 0` | `verify_prehashed(SHA-512(signed_region))` per RFC 8032 |
| FIDO2 | `aad_len > 0` | `verify(aad \|\| SHA-256(SHA-512(signed_region)))` |

## What gets hashed

- **Signed SHA512**: Hash of `image[132 .. 132 + signed_len]` — the sealed fields, padding, and code that the signature covers.
- **Presign SHA512**: Hash of the code after the JAL jump target (offset 768) — the original binary before the signature block was prepended. This matches `code only` from the device's `audit` command.
- **Padded SHA512**: Hash of the entire file zero-padded to the flash partition size (Boot0: 128 KiB, Boot1/Loader: 256 KiB). This matches the official release hashes.

## Known public keys

| Slot | Tag | Name |
|------|-----|------|
| 0 | bao1 | Production key 1 |
| 1 | bao2 | Production key 2 |
| 2 | beta | Beta testing key |
| 3 | dev | Developer key (private key is public) |

Keys are sourced from `xous-core/libs/bao1x-api/src/pubkeys/`.
