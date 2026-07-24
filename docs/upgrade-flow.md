# Upgrade Flow: bumping xous-core and/or the Rust toolchain

This document describes how to bump the firmware source (xous-core) and/or
the Rust toolchain (the `betrusted-io/rust` fork) in this channel, **by hand
if desired**, and how to **independently audit** every value the tooling
generates.

The guiding principle: every generated file is a pure function of a *pinned
input*. An auditor re-runs the generator and expects **zero diff**; the final
firmware is **bit-reproducible** via `guix build --check`. Nothing here needs
to be trusted blindly.

## What is source-of-truth vs generated

| File | Role | Produced by |
|------|------|-------------|
| `baobit.toml` | **source of truth** — hand-edited | you |
| `packages/xous-config.scm` | generated (xous-core + rust commits, git-describe, guix hashes, **and the compiler-rt / backtrace submodule pins**) | `make update-config` |
| `packages/xous-sysroot-crates.scm` | generated (std deps) | `make update-sysroot-crates` |
| `packages/bao-crates.scm` | generated (firmware deps) | `make update-bao-crates` |

The compiler-rt and backtrace-rs pins are **not** independent inputs: the
`betrusted-io/rust` fork already records them as submodule gitlinks, so
`make update-config` derives them (commit *and* guix hash) straight from the
fork. The only thing you hand-edit for a Rust bump is the fork commit in
`baobit.toml`.

Each step below is tagged with when it applies:
**[both]**, **[rust]** (Rust toolchain bump only), or **[xous]** (xous-core bump only).

## Quick checklist

1. **[both]** Edit `baobit.toml` — set `[xous-core] commit` and/or `[rust-xous] version` + `commit`.
2. **[both]** `make update-config` — regenerate `packages/xous-config.scm` (xous-core + rust hashes **and** the compiler-rt / backtrace submodule pins).
3. **[rust]** `make update-sysroot-crates` — regenerate `packages/xous-sysroot-crates.scm`.
4. **[xous]** `make update-bao-crates` — regenerate `packages/bao-crates.scm`.
5. **[both]** Build: `make rv32imac-none rv32imac-xous toolchain` then the firmware targets.
6. **[both]** Verify reproducibility: `make dabao CHECK=1` (+ one bootloader).
7. **[both]** Review the diff and commit.

The package version tracks the real Rust release automatically: the sysroot /
toolchain `version` fields use `(package-version %rust)`, while `%rust-version`
(e.g. `1.94`) is only the guix package *series* key (`rust-1.94`), not the
patch release (`1.94.1`). Nothing to edit there on a bump.

---

## Step 1 — Edit `baobit.toml` [both]

`baobit.toml` is the only file you hand-edit for the version bump itself:

```toml
[xous-core]
owner  = "betrusted-io"
commit = "<xous-core commit SHA>"

[rust-xous]
version = "1.94"                 # guix package series key -> rust-1.94
                                 # (NOT the patch release 1.94.1)
commit  = "<betrusted-io/rust commit SHA>"
```

Find the Rust fork commit for a version on the fork's branch/tag list:

```bash
git ls-remote --heads --tags https://github.com/betrusted-io/rust | grep 1.94
# e.g. refs/heads/1.94.0-xous -> fa8d53c5ed77e1707686acf94b0569cbed37696b
```

> The pinned guix must already package the requested Rust version. Check:
> ```bash
> guix time-machine -C channels/guix.scm -- build -L packages --dry-run \
>   -e '(@ (gnu packages rust) rust-1.94)'
> ```
> If it is absent, the guix channel pin in `channels/guix.scm` must be bumped
> first (out of scope for a normal version bump).

## Step 2 — Regenerate `xous-config.scm` [both]

```bash
make update-config            # = ./update-config.scm
```

**What it does:** reads `baobit.toml`, clones each repo, checks out the commit,
and writes the derived values into `packages/xous-config.scm`:
- `%xous-commit`, `%rust-xous-commit` — copied from `baobit.toml`
- `%xous-git-describe` — `git describe --long --abbrev=9`
- `%xous-guix-hash`, `%rust-xous-guix-hash` — `guix hash -rx .`
- `%xous-owner`, `%rust-version` — copied from `baobit.toml`
- `%llvm-compiler-rt-commit` / `-guix-hash` and `%backtrace-rs-commit` /
  `-guix-hash` — the fork's submodule gitlinks (derived as below)

For the two Rust submodules it runs, inside the fork checkout:

```bash
git submodule update --init --depth 1 src/llvm-project library/backtrace
git -C src/llvm-project  rev-parse HEAD   # -> %llvm-compiler-rt-commit
git -C library/backtrace rev-parse HEAD   # -> %backtrace-rs-commit
guix hash -rx src/llvm-project            # -> %llvm-compiler-rt-guix-hash
guix hash -rx library/backtrace           # -> %backtrace-rs-guix-hash
```

`rust-xous-toolchain.scm` reads those four vars, so a Rust bump needs **no
hand-editing of submodule pins** — only the fork commit in `baobit.toml`.
(`git submodule update` checks out exactly the commit the fork records as its
gitlink, which is the authoritative pin — more correct than a `.gitmodules`
branch name, which can move.)

> **Cost / skip.** Hashing `src/llvm-project` means fetching ~2.4 GB, so the
> submodule step runs **only when the rust-xous commit changes** (an
> xous-core-only bump skips it). Force a re-derivation by clearing
> `%llvm-compiler-rt-guix-hash` in `xous-config.scm`. The fetch is unavoidable
> once per Rust bump — a content hash needs the content.

**Manual equivalent / audit** (re-derive any value independently):

```bash
tmp=$(mktemp -d)
git clone https://github.com/betrusted-io/rust "$tmp"
git -C "$tmp" checkout <rust-commit>
guix hash -rx "$tmp"                                   # = %rust-xous-guix-hash
git -C "$tmp" describe --long --abbrev=9               # = %xous-git-describe (xous-core)
git -C "$tmp" submodule update --init --depth 1 src/llvm-project library/backtrace
git -C "$tmp/src/llvm-project"  rev-parse HEAD         # = %llvm-compiler-rt-commit
git -C "$tmp/library/backtrace" rev-parse HEAD         # = %backtrace-rs-commit
guix hash -rx "$tmp/src/llvm-project"                  # = %llvm-compiler-rt-guix-hash
guix hash -rx "$tmp/library/backtrace"                 # = %backtrace-rs-guix-hash
```

`guix hash -rx` is the same recursive SWH-style serialization guix uses for
fixed-output git origins, so these are faithful independent checks.

## Step 3 — Regenerate `xous-sysroot-crates.scm` [rust]

```bash
make update-sysroot-crates
```

**What it does:** resolves the pinned fork's `library/Cargo.lock` via
`guix build --source` (so it always tracks the commit in `xous-config.scm`),
then runs:

```bash
guix import -i packages/xous-sysroot-crates.scm \
  crate -f <rust-source>/library/Cargo.lock sysroot
```

This is the canonical `guix import` workflow: it inserts the `(define rust-…
(crate-source …))` blocks between the `qqqq`/`ssss` markers and merges the
`sysroot` key into `(define-cargo-inputs lookup-cargo-inputs …)`.

**Audit (round-trip):** running it again on an already-current file produces no
change:

```bash
make update-sysroot-crates && git diff --stat packages/xous-sysroot-crates.scm
# expect: no diff
```

## Step 4 — Regenerate `bao-crates.scm` [xous]

This registry is the firmware's dependency closure, imported from xous-core's
two lockfiles. Like step 3, it reads those lockfiles from the **pinned source**
— it fetches the `xous-core-source` git origin at the commit in
`xous-config.scm` via `guix build`, so **no local checkout is needed** and the
result tracks `baobit.toml` reproducibly. The importer runs from the guix
pinned in `channels/guix.scm`.

```bash
make update-bao-crates            # = scripts/update-bao-crates.sh
```

**What it does:** realizes the pinned `xous-core-source` origin (giving a
read-only store checkout with both `Cargo.lock` files), resets
`bao-crates.scm` to `scripts/bao-crates.tmpl.scm`, then for each lockfile runs
(via `guix time-machine --channels=channels/guix.scm`)
`guix import -i packages/bao-crates.scm crate --lockfile=…` — once for
`Cargo.lock` (key `xous-core`) and once for `locales/Cargo.lock` (key
`locales`) — then injects the three `(snippet bao-…-snippet)` clauses
(atsama5d27, rqrr, xous-usb-hid).

> A local xous-core checkout can still be forced with `XOUS_SRC=<path>` for
> dev/offline work, but that bypasses the pinned source and is **not
> reproducible** — leave it unset in normal use.

**Built-in audits** (the script fails loud on any of these):
- every crate in `EXPECTED_GIT_CRATES` is present as a `git-fetch` origin
  (keep this list in sync with `%git-deps` in `packages/bao.scm`);
- `git-fetch` origin count ≥ expected;
- crate count did not drop vs the previous file (override with
  `ALLOW_CRATE_DROP=1` for an intentional removal);
- parentheses balance.

> A pure Rust bump (same xous-core) leaves the firmware deps unchanged — skip
> this step (4). A pure xous-core bump (same Rust) leaves the std deps
> unchanged — skip step 3.

## Step 5 — Build [both]

```bash
make rv32imac-none rv32imac-xous toolchain          # sysroots + toolchain
make boot0 boot1 alt-boot1 baremetal-dabao dabao baosec   # firmware
# or, for the full production set:
make manifest
```

Use `SUBS=none` to force a from-source build (no substitutes) if you want to
exercise the whole chain locally.

## Step 6 — Verify reproducibility [both]

`CHECK=1` rebuilds and byte-compares (`guix build --check`):

```bash
make dabao CHECK=1            # exercises the full xous sysroot path
make boot0 CHECK=1           # a bare-metal target
```

Both must succeed. `dabao` is the most valuable check because it links the
xous sysroot rlibs and the heaviest git-dep rewriting.

## Step 7 — Review and commit [both]

Expected diff for a Rust bump: `baobit.toml`, `packages/xous-config.scm`,
`packages/xous-sysroot-crates.scm`. (`rust-xous-toolchain.scm` does **not**
change — it reads the pins from `xous-config.scm`.)
For an xous-core bump: `baobit.toml`, `packages/xous-config.scm`,
`packages/bao-crates.scm`.

Review the generated diffs (they should contain only the version/commit/hash
churn the bump implies), then commit.

---

## Auditing a published build

Because every input is pinned and every generated file round-trips, a third
party can reproduce a release without trusting the maintainer:

1. Check out the channel at the published commit.
2. Re-run steps 2, 3, 4 (the generators) — expect **no diff** (the committed
   generated files match their pinned inputs).
3. `make <target> CHECK=1` (step 6) — expect the published store hash.

See also `docs/reproducible-firmware-provenance.md` and
`docs/channel-reproducibility-issue.md`.

## Worked example: 1.93 → 1.94 (Rust only)

```toml
# baobit.toml
[rust-xous]
version = "1.94"
commit  = "fa8d53c5ed77e1707686acf94b0569cbed37696b"   # 1.94.0-xous
```

```bash
make update-config                # step 2 — derives rust hash + the
                                  #          compiler-rt/backtrace submodule pins
make update-sysroot-crates        # step 3
make rv32imac-xous toolchain dabao   # step 5
make dabao CHECK=1                # step 6
```
