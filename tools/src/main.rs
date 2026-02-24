//! Parse and verify signed Baochip firmware images (.img files).
//!
//! Reads signed boot images directly, extracts the signature block,
//! computes SHA-512 hashes, and verifies Ed25519ph/FIDO2 signatures.
//!
//! Usage:
//!   verify-binary boot0.img boot1.img
//!   verify-binary boot0.img --output-presign presign.bin

use std::fs;
use std::path::PathBuf;
use std::process;

use bytemuck::{Pod, Zeroable};
use clap::Parser;
use digest::{FixedOutput, HashMarker, Output, OutputSizeUser, Reset, Update};
use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use serde::Serialize;
use sha2::{Digest, Sha256, Sha512};

// bytemuck doesn't impl Pod/Zeroable for [u8; 60] out of the box,
// so we wrap it in a newtype.
#[repr(C)]
#[derive(Copy, Clone)]
struct Aad([u8; AAD_LENGTH]);
// Safety: [u8; 60] is valid for any bit pattern and has no padding.
unsafe impl Zeroable for Aad {}
unsafe impl Pod for Aad {}

impl std::ops::Deref for Aad {
    type Target = [u8; AAD_LENGTH];
    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

// ── Constants ──────────────────────────────────────────────────────

const SIGNATURE_LENGTH: usize = 64;
const PUBLIC_KEY_LENGTH: usize = 32;
const AAD_LENGTH: usize = 60;

/// Offset where sealed (signed) data begins.
const UNSIGNED_LEN: usize =
    size_of::<u32>() + SIGNATURE_LENGTH + size_of::<u32>() + AAD_LENGTH; // 132

const MAGIC_NUMBER: [u32; 2] = [
    u32::from_be_bytes(*b"yumy"),
    u32::from_be_bytes(*b"Bao3"),
];

/// Known public keys (from libs/bao1x-api/src/pubkeys/).
const KNOWN_KEYS: &[(&str, &str)] = &[
    (
        "bao1",
        "a87a5f98daabfb512fc3c2e5749b3beb192388d20160a7dd5888fb9da409523a",
    ),
    (
        "bao2",
        "79135dc667aff4f7d352b90328788ebf92c786782138b377370b15194e312888",
    ),
    (
        "beta",
        "80979929edd04e40124b52cae9ae54b24bdff72a7b8a004c41065bd1402078a7",
    ),
    (
        "developer",
        "1c9beae32aeac87507c18094387eff1c74614282affd8152d871352edf3f58bb",
    ),
];

// ── Binary structures (matching xous-core libs/bao1x-api/src/signatures.rs) ──

#[repr(C)]
#[derive(Copy, Clone, Pod, Zeroable)]
struct Pubkey {
    pk: [u8; PUBLIC_KEY_LENGTH],
    tag: [u8; 4],
}

#[repr(C)]
#[derive(Copy, Clone, Pod, Zeroable)]
struct SealedFields {
    version: u32,
    magic: [u32; 2],
    signed_len: u32,
    function_code: u32,
    anti_rollback: u32,
    min_semver: [u8; 16],
    semver: [u8; 16],
    pubkeys: [Pubkey; 4],
}

#[repr(C)]
#[derive(Copy, Clone, Pod, Zeroable)]
struct SignatureInFlash {
    _jal_instruction: u32,
    signature: [u8; SIGNATURE_LENGTH],
    aad_len: u32,
    aad: Aad,
    sealed_data: SealedFields,
}

// ── PrecomputedHash (from verify_ed25519ph) ──────────────────────

/// Wraps an already-finalized SHA-512 hash so ed25519-dalek's
/// `verify_prehashed` can consume it without re-hashing.
struct PrecomputedHash {
    hash: [u8; 64],
}

impl OutputSizeUser for PrecomputedHash {
    type OutputSize = sha2::digest::typenum::U64;
}

impl FixedOutput for PrecomputedHash {
    fn finalize_into(self, out: &mut Output<Self>) {
        out.copy_from_slice(&self.hash);
    }
}

impl Default for PrecomputedHash {
    fn default() -> Self {
        Self { hash: [0u8; 64] }
    }
}

impl HashMarker for PrecomputedHash {}

impl Update for PrecomputedHash {
    fn update(&mut self, _data: &[u8]) {}
}

impl Reset for PrecomputedHash {
    fn reset(&mut self) {}
}

// ── RISC-V JAL decoder ──────────────────────────────────────────

/// Decode RISC-V JAL instruction to extract the signed jump offset.
///
/// JAL encoding: imm[20|10:1|11|19:12] rd opcode
fn decode_jal_offset(instruction: u32) -> i32 {
    let imm_20 = (instruction >> 31) & 1;
    let imm_10_1 = (instruction >> 21) & 0x3ff;
    let imm_11 = (instruction >> 20) & 1;
    let imm_19_12 = (instruction >> 12) & 0xff;

    let imm = (imm_20 << 20) | (imm_19_12 << 12) | (imm_11 << 11) | (imm_10_1 << 1);

    // Sign-extend from 21 bits
    if imm & (1 << 20) != 0 {
        imm as i32 - (1 << 21)
    } else {
        imm as i32
    }
}

// ── Image analysis ──────────────────────────────────────────────

fn identify_key(pk_bytes: &[u8; 32]) -> Option<&'static str> {
    let pk_hex = hex::encode(pk_bytes);
    for (name, known_hex) in KNOWN_KEYS {
        if pk_hex.eq_ignore_ascii_case(known_hex) {
            return Some(name);
        }
    }
    None
}

fn function_code_name(code: u32) -> &'static str {
    match code {
        0 => "Invalid",
        1 => "Boot0",
        2 => "Boot1",
        3 => "UpdatedBoot1",
        4 => "Loader",
        5 => "UpdatedLoader",
        6 => "Baremetal",
        7 => "UpdatedBaremetal",
        0x100 => "Kernel",
        0x101 => "UpdatedKernel",
        0x8000 => "Swap",
        0x8001 => "UpdatedSwap",
        0x10_0000 => "App",
        0x10_0001 => "UpdatedApp",
        _ => "Unknown",
    }
}

/// Partition size in bytes for zero-padding, derived from flash memory layout.
///   BOOT0: 0x6000_0000 .. 0x6002_0000  = 128 KiB
///   BOOT1: 0x6002_0000 .. 0x6006_0000  = 256 KiB
///   LOADER/BAREMETAL: 0x6006_0000 .. 0x600A_0000 = 256 KiB
fn partition_size(function_code: u32) -> Option<usize> {
    match function_code {
        1 => Some(128 * 1024),              // Boot0
        2 | 3 => Some(256 * 1024),          // Boot1 / UpdatedBoot1
        4 | 5 => Some(256 * 1024),          // Loader / UpdatedLoader
        6 | 7 => Some(256 * 1024),          // Baremetal / UpdatedBaremetal
        _ => None,
    }
}

#[derive(Serialize)]
struct ImageReport {
    #[serde(rename = "file")]
    filename: String,
    file_size: usize,
    #[serde(rename = "function")]
    function_code: String,
    mode: &'static str,
    signed_sha512: String,
    presign_sha512: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    padded_sha512: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    padded_size: Option<usize>,
    #[serde(rename = "signature")]
    signature_hex: String,
    #[serde(rename = "signing_key")]
    signing_key_hex: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    signing_key_name: Option<&'static str>,
    version: String,
    anti_rollback: u32,
    #[serde(rename = "embedded_keys")]
    pubkeys: Vec<EmbeddedKey>,
    verification: VerifyResult,
}

#[derive(Serialize)]
struct EmbeddedKey {
    key: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    name: Option<&'static str>,
    tag: String,
}

#[derive(Serialize)]
enum VerifyResult {
    #[serde(rename = "PASSED")]
    Passed,
    #[serde(rename = "FAILED")]
    Failed(String),
}

fn process_image(data: &[u8], filename: &str) -> Result<ImageReport, String> {
    if data.len() < size_of::<SignatureInFlash>() {
        return Err(format!(
            "File too small: {} bytes (need at least {})",
            data.len(),
            size_of::<SignatureInFlash>()
        ));
    }

    // Parse the signature block
    let sig: &SignatureInFlash =
        bytemuck::from_bytes(&data[..size_of::<SignatureInFlash>()]);

    // Validate magic
    if sig.sealed_data.magic != MAGIC_NUMBER {
        return Err(format!(
            "Invalid magic: [{:#010x}, {:#010x}], expected [{:#010x}, {:#010x}]",
            sig.sealed_data.magic[0],
            sig.sealed_data.magic[1],
            MAGIC_NUMBER[0],
            MAGIC_NUMBER[1],
        ));
    }

    let signed_len = sig.sealed_data.signed_len as usize;
    let signed_end = UNSIGNED_LEN + signed_len;

    if data.len() < signed_end {
        return Err(format!(
            "File too small for signed region: {} bytes, need {}",
            data.len(),
            signed_end,
        ));
    }

    let is_fido2 = sig.aad_len > 0;
    let mode = if is_fido2 { "FIDO2" } else { "Ed25519ph" };

    // Signed region: image[UNSIGNED_LEN .. UNSIGNED_LEN + signed_len]
    let signed_region = &data[UNSIGNED_LEN..signed_end];
    let signed_hash = Sha512::digest(signed_region);
    let signed_sha512 = hex::encode(&signed_hash);

    // Presign data: decode JAL to find where code starts
    let jal_offset = decode_jal_offset(sig._jal_instruction);
    let presign_sha512 = if jal_offset > 0 && (jal_offset as usize) < data.len() {
        let presign_data = &data[jal_offset as usize..];
        hex::encode(Sha512::digest(presign_data))
    } else {
        format!("(invalid JAL offset: {})", jal_offset)
    };

    // Padded hash: zero-pad to partition size and hash
    let (padded_sha512, padded_size) = match partition_size(sig.sealed_data.function_code) {
        Some(target) => {
            let mut padded = data.to_vec();
            padded.resize(target, 0);
            (Some(hex::encode(Sha512::digest(&padded))), Some(target))
        }
        None => (None, None),
    };

    // Collect pubkeys from the signature block
    let mut pubkeys = Vec::new();
    for key in &sig.sealed_data.pubkeys {
        if key.tag != [0u8; 4] || key.pk != [0u8; 32] {
            let tag_str = String::from_utf8_lossy(&key.tag).trim().to_string();
            let key_hex = hex::encode(key.pk);
            let name = identify_key(&key.pk);
            pubkeys.push(EmbeddedKey {
                key: key_hex,
                name,
                tag: tag_str,
            });
        }
    }

    // Try each embedded key against the signature to find which one signed it.
    let ed25519_signature = Signature::from_bytes(&sig.signature);

    let mut verification = VerifyResult::Failed("no valid key found".to_string());
    let mut found_key_hex = String::new();
    let mut found_key_name: Option<&'static str> = None;

    for key in &sig.sealed_data.pubkeys {
        if key.tag == [0u8; 4] && key.pk == [0u8; 32] {
            continue;
        }

        let vk = match VerifyingKey::from_bytes(&key.pk) {
            Ok(vk) => vk,
            Err(_) => continue,
        };

        let result = if is_fido2 {
            // FIDO2: verify_strict(aad[..aad_len] || SHA-256(SHA-512(signed_region)))
            let hashed_hash = Sha256::digest(&signed_hash);
            let mut msg = Vec::new();
            msg.extend_from_slice(&sig.aad[..sig.aad_len as usize]);
            msg.extend_from_slice(&hashed_hash);
            vk.verify(&msg, &ed25519_signature)
        } else {
            // Ed25519ph: verify_prehashed with SHA-512 of signed region
            let prehash = PrecomputedHash {
                hash: signed_hash.into(),
            };
            vk.verify_prehashed(prehash, None, &ed25519_signature)
        };

        if result.is_ok() {
            found_key_hex = hex::encode(key.pk);
            found_key_name = identify_key(&key.pk);
            verification = VerifyResult::Passed;
            break;
        }
    }

    // If no embedded key worked, report the first non-zero key for display
    if found_key_hex.is_empty() {
        if let Some(ek) = pubkeys.first() {
            found_key_hex = ek.key.clone();
            found_key_name = ek.name;
        }
    }

    Ok(ImageReport {
        filename: filename.to_string(),
        file_size: data.len(),
        function_code: function_code_name(sig.sealed_data.function_code).to_string(),
        mode,
        signed_sha512,
        presign_sha512,
        padded_sha512,
        padded_size,
        signature_hex: hex::encode(sig.signature),
        signing_key_hex: found_key_hex,
        signing_key_name: found_key_name,
        version: format!("{:#x}", sig.sealed_data.version),
        anti_rollback: sig.sealed_data.anti_rollback,
        pubkeys,
        verification,
    })
}

fn print_report(r: &ImageReport) {
    let key_display = match r.signing_key_name {
        Some(name) => format!("{} ({})", r.signing_key_hex, name),
        None => r.signing_key_hex.clone(),
    };
    let verify_str = match &r.verification {
        VerifyResult::Passed => "PASSED",
        VerifyResult::Failed(msg) => msg,
    };

    println!("File:           {} ({} bytes)", r.filename, r.file_size);
    println!("Function:       {}", r.function_code);
    println!("Mode:           {}", r.mode);
    println!("Signed SHA512:  {}", r.signed_sha512);
    println!("Presign SHA512: {}", r.presign_sha512);
    if let (Some(ref hash), Some(size)) = (&r.padded_sha512, r.padded_size) {
        println!("Padded SHA512:  {} (zero-padded to {} bytes)", hash, size);
    }
    println!("Signature:      {}", r.signature_hex);
    println!("Signing Key:    {}", key_display);
    println!("Version:        {}", r.version);
    println!("Anti-rollback:  {}", r.anti_rollback);
    if r.pubkeys.len() > 1 {
        println!("Embedded keys:");
        for ek in &r.pubkeys {
            match ek.name {
                Some(n) => println!("  {} ({}) [{}]", ek.key, n, ek.tag),
                None => println!("  {} [{}]", ek.key, ek.tag),
            }
        }
    }
    println!("Verification:   {}", verify_str);
}

// ── CLI ─────────────────────────────────────────────────────────

#[derive(Parser)]
#[command(name = "verify-binary")]
#[command(about = "Parse and verify signed Baochip firmware images")]
struct Args {
    /// Signed .img files to analyze
    #[arg(required = true)]
    files: Vec<PathBuf>,

    /// Save extracted presign data (only for single file)
    #[arg(short, long)]
    output_presign: Option<PathBuf>,

    /// Output results as JSON
    #[arg(long)]
    json: bool,
}

fn main() {
    let args = Args::parse();

    if args.output_presign.is_some() && args.files.len() > 1 {
        eprintln!("Error: --output-presign only works with a single input file");
        process::exit(1);
    }

    let mut all_passed = true;
    let mut reports: Vec<ImageReport> = Vec::new();

    for (i, path) in args.files.iter().enumerate() {
        if !args.json && i > 0 {
            println!();
        }

        let data = match fs::read(path) {
            Ok(d) => d,
            Err(e) => {
                eprintln!("Error reading {}: {}", path.display(), e);
                all_passed = false;
                continue;
            }
        };

        let filename = path
            .file_name()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_else(|| path.display().to_string());

        match process_image(&data, &filename) {
            Ok(report) => {
                if let VerifyResult::Failed(_) = &report.verification {
                    all_passed = false;
                }

                if args.json {
                    reports.push(report);
                } else {
                    print_report(&report);

                    // Save presign data if requested
                    if let Some(ref out_path) = args.output_presign {
                        let sig: &SignatureInFlash =
                            bytemuck::from_bytes(&data[..size_of::<SignatureInFlash>()]);
                        let jal_offset = decode_jal_offset(sig._jal_instruction);
                        if jal_offset > 0 && (jal_offset as usize) < data.len() {
                            let presign = &data[jal_offset as usize..];
                            if let Err(e) = fs::write(out_path, presign) {
                                eprintln!("Error writing presign data: {}", e);
                            } else {
                                println!(
                                    "Presign data:   {} ({} bytes)",
                                    out_path.display(),
                                    presign.len()
                                );
                            }
                        }
                    }
                }
            }
            Err(e) => {
                eprintln!("Error processing {}: {}", filename, e);
                all_passed = false;
            }
        }
    }

    if args.json {
        println!("{}", serde_json::to_string_pretty(&reports).unwrap());
    }

    process::exit(if all_passed { 0 } else { 1 });
}
