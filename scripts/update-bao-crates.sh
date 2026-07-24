#!/usr/bin/env bash
# Regenerate packages/bao-crates.scm following the upstream
# (gnu packages rust-crates) workflow.
#
# Pipeline (mirrors upstream's `guix import` usage):
#   1. Reset bao-crates.scm to its empty template
#      (module header + qqqq/ssss markers + empty define-cargo-inputs).
#   2. Run `guix import -i bao-crates.scm crate --lockfile=... <key>`
#      once per xous-core Cargo.lock (main + locales).  The importer
#      mutates the file: inserts (define rust-...) blocks between the
#      qqqq/ssss markers and merges each key into the existing
#      (define-cargo-inputs lookup-cargo-inputs) form.
#   3. Inject (snippet bao-<name>-snippet) clauses into the three git
#      origins whose Cargo.toml needs editing (atsama5d27, rqrr,
#      xous-usb-hid).  Snippet vars live in packages/bao-git-snippets.scm.
#
# Usage:  scripts/update-bao-crates.sh
#
# Env:
#   CHANNELS  guix channels file (default: channels/guix.scm)
#   OUT       output file (default: packages/bao-crates.scm)
#   XOUS_SRC  override: a local xous-core checkout to import from instead of
#             the pinned source.  For dev/offline use ONLY -- it defeats
#             reproducibility.  Leave unset in normal use.

set -euo pipefail

CHANNELS="${CHANNELS:-channels/guix.scm}"
OUT="${OUT:-packages/bao-crates.scm}"
TEMPLATE="${TEMPLATE:-scripts/bao-crates.tmpl.scm}"

# Fetch the xous-core source at the commit pinned in xous-config.scm (derived
# from baobit.toml) by realizing its git-fetch origin directly -- the same
# reproducible source guix builds the firmware from.  Both Cargo.lock files
# live inside the resulting store checkout, so the regen never depends on a
# local working copy.  (Mirrors update-sysroot-crates, which reads the rust
# fork's library/Cargo.lock the same way.)
if [ -z "${XOUS_SRC:-}" ]; then
  echo "=== fetching pinned xous-core source ===" >&2
  XOUS_SRC=$(guix time-machine --channels="$CHANNELS" -- \
    build -L packages -e '(@ (bao) xous-core-source)')
  echo "xous-core source: $XOUS_SRC" >&2
else
  echo "warning: using XOUS_SRC override ($XOUS_SRC) -- not reproducible" >&2
fi

MAIN_LOCK="$XOUS_SRC/Cargo.lock"
LOCALES_LOCK="$XOUS_SRC/locales/Cargo.lock"

for f in "$MAIN_LOCK" "$LOCALES_LOCK" "$CHANNELS" "$TEMPLATE"; do
  if [ ! -e "$f" ]; then
    echo "error: missing required input: $f" >&2
    exit 1
  fi
done

#
# 1. Reset OUT to the empty template.
#

# Capture the previous generation's crate count *before* the template
# overwrites it, so the post-regeneration guard can detect a gross drop.
PREV_CRATES=0
if [ -f "$OUT" ]; then
  PREV_CRATES=$(grep -c '^(define rust-' "$OUT" || true)
fi

cp "$TEMPLATE" "$OUT"

#
# 2. Run the importer once per lockfile.
#

# Run the importer from the pinned channel guix via time-machine.
run_importer() {
  local lock=$1 key=$2
  echo "=== importing $key from $lock ==="
  guix time-machine --channels="$CHANNELS" -- import \
    -i "$OUT" crate --lockfile="$lock" "$key" \
    2>&1 | grep -vE '^;;;|newer than compiled|^WARNING|^<unknown' || true
}

run_importer "$MAIN_LOCK" xous-core
run_importer "$LOCALES_LOCK" locales

#
# 3. Inject (snippet bao-<name>-snippet) into git origins that need it.
#
# Each git crate's (define rust-NAME-VER.SHA ...) ends with a line like
#     (sha256 (base32 "...."))))
# The four trailing parens close: base32, sha256, origin, define.
# We turn that into:
#     (sha256 (base32 "...."))     <- closes base32 + sha256 only
#     (snippet bao-<name>-snippet)))  <- snippet field + close origin + define
#
# inject_snippet CRATE-NAME-PREFIX SNIPPET-VAR
inject_snippet() {
  local prefix=$1 snippet=$2
  awk -v prefix="$prefix" -v snippet="$snippet" '
    $0 ~ "^\\(define " prefix { in_block = 1 }
    in_block && /^[[:space:]]*\(sha256 \(base32 "[^"]+"\)\)\)\)$/ {
      # Strip the two trailing parens that close origin + define; emit them
      # on the snippet line instead so the snippet sits inside (origin ...).
      sub(/\)\)\)\)$/, "))")
      print
      indent = ""
      match($0, /^[[:space:]]*/)
      indent = substr($0, RSTART, RLENGTH)
      print indent "(snippet " snippet ")))"
      in_block = 0
      next
    }
    in_block && /^[[:space:]]*\(sha256/ {
      print "ERROR: unexpected sha256 line shape in " prefix " block" > "/dev/stderr"
      exit 4
    }
    { print }
  ' "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
}

inject_snippet rust-atsama5d27-    bao-atsama5d27-snippet
inject_snippet rust-rqrr-          bao-rqrr-snippet
inject_snippet rust-xous-usb-hid-  bao-xous-usb-hid-snippet

# Spot-check injection happened (one occurrence per snippet).
for s in bao-atsama5d27-snippet bao-rqrr-snippet bao-xous-usb-hid-snippet; do
  n=$(grep -c "(snippet $s)" "$OUT")
  if [ "$n" -ne 1 ]; then
    echo "error: expected 1 injection of $s, found $n" >&2
    exit 5
  fi
done

#
# Note: (bao-cargo-inputs) thunk lives in scripts/bao-crates.tmpl.scm —
# already present in OUT from the initial template copy.

#
# Sanity-check the regenerated registry: every git-forked crate must appear as
# a (method git-fetch) origin.  This list is the single source of truth for
# those crates -- keep it in sync with %git-deps in packages/bao.scm when
# xous-core's forks change.  Names are matched by stem anchored on the version
# digit so `curve25519-dalek` does not shadow `curve25519-dalek-derive`.
#

EXPECTED_GIT_CRATES=(
  armv7 atsama5d27 com-rs curve25519-dalek curve25519-dalek-derive
  engine-25519 engine25519-as ring rqrr sha2 simple-fatfs
  usb-device usbd-serial utralib xous-usb-hid
)

missing=()
for stem in "${EXPECTED_GIT_CRATES[@]}"; do
  if ! grep -qE "^\(define rust-${stem}-[0-9]" "$OUT"; then
    missing+=("$stem")
  fi
done
if [ "${#missing[@]}" -ne 0 ]; then
  echo "error: ${#missing[@]} expected git-forked crate(s) missing from $OUT:" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  echo "the regenerated registry is incomplete." >&2
  exit 8
fi

git_count=$(grep -c '(method git-fetch)' "$OUT" || true)
if [ "$git_count" -lt "${#EXPECTED_GIT_CRATES[@]}" ]; then
  echo "error: only $git_count git-fetch origins in $OUT, expected >= ${#EXPECTED_GIT_CRATES[@]}" >&2
  exit 8
fi

# Guard against a gross drop vs the previous generation.  A drop may be a
# legitimate dependency removal; require an explicit opt-in.
new_crates=$(grep -c '^(define rust-' "$OUT" || true)
if [ "$PREV_CRATES" -gt 0 ] && [ "$new_crates" -lt "$PREV_CRATES" ]; then
  if [ "${ALLOW_CRATE_DROP:-0}" = 1 ]; then
    echo "warning: crate count dropped ${PREV_CRATES} -> ${new_crates} (ALLOW_CRATE_DROP=1)" >&2
  else
    echo "error: crate count dropped ${PREV_CRATES} -> ${new_crates}" >&2
    echo "if the reduction is intentional, re-run with ALLOW_CRATE_DROP=1." >&2
    exit 8
  fi
fi

#
# Final sanity: paren balance + counts.
#

opens=$(tr -cd '(' < "$OUT" | wc -c)
closes=$(tr -cd ')' < "$OUT" | wc -c)
if [ "$opens" -ne "$closes" ]; then
  echo "error: paren mismatch in $OUT — opens=$opens closes=$closes" >&2
  exit 7
fi

echo
echo "=== summary ==="
echo "output:         $OUT"
echo "lines:          $(wc -l < "$OUT")"
echo "crate defines:  $(grep -c '^(define rust-' "$OUT")"
echo "snippets:       $(grep -c '(snippet bao-' "$OUT")"
echo "cargo keys:     $(grep -cE '^\s+\([a-z][a-z0-9-]+ =>' "$OUT")"
