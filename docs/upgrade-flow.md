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

The package version tracks the real Rust release automatically: the sysroot /
toolchain `version` fields use `(package-version %rust)`, while `%rust-version`
(e.g. `1.94`) is only the guix package *series* key (`rust-1.94`), not the
patch release (`1.94.1`). Nothing to edit there on a bump.

## Pick your path

Three self-contained recipes follow. **Find the one that matches your bump and
run every step in it, top to bottom** — there is nothing to skip and nothing to
figure out. Each step names the generator it runs; the
[Command reference](#command-reference) at the bottom explains what each one
does and how to audit it independently.

- **Path A — xous-core only** — new firmware source, same Rust toolchain.
- **Path B — Rust toolchain only** — new `betrusted-io/rust`, same xous-core.
- **Path C — both** — new firmware source *and* new Rust toolchain.

---

## Path A — xous-core only

New firmware source, unchanged Rust toolchain. The sysroots and toolchain do
not change, so guix reuses them (from substitutes or the store) — you neither
rebuild them nor regenerate `xous-sysroot-crates.scm`.

1. **Edit `baobit.toml`** — set `[xous-core] commit` to the new SHA.
   (See [`baobit.toml`](#baobittoml--the-only-file-you-hand-edit).)
2. **`make update-config`** — regenerate `packages/xous-config.scm`.
   Cheap here: the ~2.4 GB Rust-submodule fetch is skipped because the Rust
   commit did not change.
   (See [`make update-config`](#make-update-config--xous-configscm).)
3. **`make update-bao-crates`** — regenerate `packages/bao-crates.scm`, the
   firmware dependency closure, from the new commit's `Cargo.lock`.
   (See [`make update-bao-crates`](#make-update-bao-crates--bao-cratesscm).)
4. **Build the firmware:**
   ```bash
   make boot0 boot1 alt-boot1 baremetal-dabao dabao baosec
   # or the full production set:
   make manifest
   ```
   (See [Build](#build).)
5. **Verify reproducibility:**
   ```bash
   make dabao CHECK=1
   make boot0 CHECK=1
   ```
   (See [Verify reproducibility](#verify-reproducibility).)
6. **Review and commit.** Expected diff — and nothing else:
   `baobit.toml`, `packages/xous-config.scm`, `packages/bao-crates.scm`.

---

## Path B — Rust toolchain only

New `betrusted-io/rust` fork, unchanged xous-core. The firmware dependency
closure does not change, so you do **not** regenerate `bao-crates.scm`.

**Before you start:** confirm the pinned guix can build the requested Rust
series — see
[Prerequisite: guix packages the Rust version](#prerequisite-guix-packages-the-rust-version).

1. **Edit `baobit.toml`** — set `[rust-xous] version` and `commit`.
   (See [`baobit.toml`](#baobittoml--the-only-file-you-hand-edit).)
2. **`make update-config`** — regenerate `packages/xous-config.scm`, including
   the compiler-rt / backtrace submodule pins. This fetches ~2.4 GB **once**
   per Rust bump (a content hash needs the content).
   (See [`make update-config`](#make-update-config--xous-configscm).)
3. **`make update-sysroot-crates`** — regenerate
   `packages/xous-sysroot-crates.scm`, the std dependency closure.
   (See [`make update-sysroot-crates`](#make-update-sysroot-crates--xous-sysroot-cratesscm).)
4. **Build the sysroots, toolchain, then firmware:**
   ```bash
   make rv32imac-none rv32imac-xous toolchain
   make boot0 boot1 alt-boot1 baremetal-dabao dabao baosec   # or: make manifest
   ```
   (See [Build](#build).)
5. **Verify reproducibility:**
   ```bash
   make dabao CHECK=1
   make boot0 CHECK=1
   ```
   (See [Verify reproducibility](#verify-reproducibility).)
6. **Review and commit.** Expected diff: `baobit.toml`,
   `packages/xous-config.scm`, `packages/xous-sysroot-crates.scm`.
   `rust-xous-toolchain.scm` does **not** change — it reads the pins from
   `xous-config.scm`.

---

## Path C — both

New firmware source **and** new Rust toolchain. This is Path A + Path B: run all
four generators, then rebuild everything.

**Before you start:** confirm the pinned guix can build the requested Rust
series — see
[Prerequisite: guix packages the Rust version](#prerequisite-guix-packages-the-rust-version).

1. **Edit `baobit.toml`** — set `[xous-core] commit` **and** `[rust-xous]
   version` + `commit`.
   (See [`baobit.toml`](#baobittoml--the-only-file-you-hand-edit).)
2. **`make update-config`** — regenerate `packages/xous-config.scm` (xous-core
   + rust hashes **and** the compiler-rt / backtrace submodule pins; fetches
   ~2.4 GB once for the Rust submodule).
   (See [`make update-config`](#make-update-config--xous-configscm).)
3. **`make update-sysroot-crates`** — regenerate
   `packages/xous-sysroot-crates.scm`, the std deps.
   (See [`make update-sysroot-crates`](#make-update-sysroot-crates--xous-sysroot-cratesscm).)
4. **`make update-bao-crates`** — regenerate `packages/bao-crates.scm`, the
   firmware deps.
   (See [`make update-bao-crates`](#make-update-bao-crates--bao-cratesscm).)
5. **Build the sysroots, toolchain, then firmware:**
   ```bash
   make rv32imac-none rv32imac-xous toolchain
   make boot0 boot1 alt-boot1 baremetal-dabao dabao baosec   # or: make manifest
   ```
   (See [Build](#build).)
6. **Verify reproducibility:**
   ```bash
   make dabao CHECK=1
   make boot0 CHECK=1
   ```
   (See [Verify reproducibility](#verify-reproducibility).)
7. **Review and commit.** Expected diff: `baobit.toml`,
   `packages/xous-config.scm`, `packages/xous-sysroot-crates.scm`,
   `packages/bao-crates.scm`.

---

## Command reference

What each step does, its manual equivalent, and how to audit it independently.
The paths above tell you *which* of these to run and in *what order*; this
section explains *what each one does*.

### Prerequisite: guix packages the Rust version

*(Rust bumps only — Paths B and C.)* Find the fork commit for a version, then
confirm the pinned guix can build that Rust series:

```bash
git ls-remote --heads --tags https://github.com/betrusted-io/rust | grep 1.94
# e.g. refs/heads/1.94.0-xous -> fa8d53c5ed77e1707686acf94b0569cbed37696b

guix time-machine -C channels/guix.scm -- build -L packages --dry-run \
  -e '(@ (gnu packages rust) rust-1.94)'
```

If the Rust series is absent, the guix channel pin in `channels/guix.scm` must
be bumped first (out of scope for a normal version bump).

### `baobit.toml` — the only file you hand-edit

`baobit.toml` is the only file you edit by hand for the version bump itself:

```toml
[xous-core]
owner  = "betrusted-io"
commit = "<xous-core commit SHA>"          # Paths A and C

[rust-xous]
version = "1.94"                 # guix package series key -> rust-1.94
                                 # (NOT the patch release 1.94.1)
commit  = "<betrusted-io/rust commit SHA>" # Paths B and C
```

Edit only the block(s) your path calls for: `[xous-core]` for Path A,
`[rust-xous]` for Path B, both for Path C.

### `make update-config` → `xous-config.scm`

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

> **Cost / when the big fetch happens.** Hashing `src/llvm-project` means
> fetching ~2.4 GB, so the submodule step runs **only when the rust-xous commit
> changes** (Paths B and C). An **xous-core-only bump (Path A) skips it**, so
> `make update-config` is cheap there. Force a re-derivation by clearing
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

### `make update-sysroot-crates` → `xous-sysroot-crates.scm`

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

### `make update-bao-crates` → `bao-crates.scm`

This registry is the firmware's dependency closure, imported from xous-core's
two lockfiles. It reads those lockfiles from the **pinned source**: it fetches
the `xous-core-source` git origin at the commit in `xous-config.scm` via
`guix build`, so **no local checkout is needed** and the result tracks
`baobit.toml` reproducibly. The importer runs from the guix pinned in
`channels/guix.scm`.

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

**Built-in audits** (the script fails loud on any of these):
- every crate in `EXPECTED_GIT_CRATES` is present as a `git-fetch` origin
  (keep this list in sync with `%git-deps` in `packages/bao.scm`);
- `git-fetch` origin count ≥ expected;
- crate count did not drop vs the previous file (override with
  `ALLOW_CRATE_DROP=1` for an intentional removal);
- parentheses balance.

> A local xous-core checkout can still be forced with `XOUS_SRC=<path>` for
> dev/offline work, but that bypasses the pinned source and is **not
> reproducible** — leave it unset in normal use.

### Build

```bash
make rv32imac-none rv32imac-xous toolchain          # sysroots + toolchain
make boot0 boot1 alt-boot1 baremetal-dabao dabao baosec   # firmware
# or, for the full production set:
make manifest
```

On an xous-core-only bump (Path A) the first line is a no-op in practice: the
sysroots and toolchain are unchanged and come straight from substitutes or the
store. Use `SUBS=none` to force a from-source build (no substitutes) if you
want to exercise the whole chain locally.

### Verify reproducibility

`CHECK=1` rebuilds and byte-compares (`guix build --check`):

```bash
make dabao CHECK=1            # exercises the full xous sysroot path
make boot0 CHECK=1           # a bare-metal target
```

Both must succeed. `dabao` is the most valuable check because it links the
xous sysroot rlibs and the heaviest git-dep rewriting.

---

## Auditing a published build

Because every input is pinned and every generated file round-trips, a third
party can reproduce a release without trusting the maintainer:

1. Check out the channel at the published commit.
2. Re-run the generators for the relevant path (Path A/B/C above) — expect
   **no diff** (the committed generated files match their pinned inputs).
3. `make <target> CHECK=1` — expect the published store hash.

See also `docs/reproducible-firmware-provenance.md` and
`docs/channel-reproducibility-issue.md`.

---

## Worked examples

### Path A — xous-core only

```toml
# baobit.toml
[xous-core]
owner  = "betrusted-io"
commit = "08162ddbc155633376e42eda0c47f6f77fce5c83"   # v0.10.2-beta1-24-g08162ddbc
```

```bash
make update-config                # step 2 — cheap; Rust submodule fetch skipped
make update-bao-crates            # step 3 — firmware deps (e.g. bao1x-api -> 0.1.2)
make boot0 boot1 dabao            # step 4
make dabao CHECK=1                # step 5
```

### Path B — Rust only (1.93 → 1.94)

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
make rv32imac-xous toolchain dabao   # step 4
make dabao CHECK=1                # step 5
```
