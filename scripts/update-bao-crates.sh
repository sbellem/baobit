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
#   4. Append friendly-name aliases for packages/bao.scm.
#      (e.g. (define rust-armv7-git rust-armv7-0.2.1.e37a72f))
#
# Usage:  scripts/update-bao-crates.sh
#
# Env:
#   XOUS_SRC  xous-core checkout (default: $HOME/code/baochip/xous-core-dev)
#   GUIX_SRC  patched guix checkout (default: $HOME/code/guix/guix)
#   OUT       output file (default: packages/bao-crates.scm)

set -euo pipefail

XOUS_SRC="${XOUS_SRC:-$HOME/code/baochip/xous-core-dev}"
GUIX_SRC="${GUIX_SRC:-$HOME/code/guix/guix}"
OUT="${OUT:-packages/bao-crates.scm}"
TEMPLATE="${TEMPLATE:-scripts/bao-crates.tmpl.scm}"

MAIN_LOCK="$XOUS_SRC/Cargo.lock"
LOCALES_LOCK="$XOUS_SRC/locales/Cargo.lock"
PRE_INST_ENV="$GUIX_SRC/pre-inst-env"

for f in "$MAIN_LOCK" "$LOCALES_LOCK" "$PRE_INST_ENV" "$TEMPLATE"; do
  if [ ! -e "$f" ]; then
    echo "error: missing required input: $f" >&2
    exit 1
  fi
done

#
# 1. Reset OUT to the empty template.
#

cp "$TEMPLATE" "$OUT"

#
# 2. Run the importer once per lockfile.
#

OUT_ABS=$(realpath "$OUT")

run_importer() {
  local lock=$1 key=$2
  echo "=== importing $key from $lock ==="
  ( cd "$GUIX_SRC" \
    && guix shell -D guix --pure -- \
         ./pre-inst-env guix import \
           -i "$OUT_ABS" crate --lockfile="$lock" "$key" \
         2>&1 | grep -vE '^;;;|newer than compiled|^WARNING|^<unknown' || true )
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
# 4. Append friendly-name aliases used by packages/bao.scm.
#
# For each <friendly>=<prefix> pair, find the importer-emitted symbol whose
# name starts with <prefix> and append "(define <friendly> <importer-name>)".
#

# Each entry maps a friendly *-git alias to the crate's name as it appears
# in Cargo.lock.  The script looks up the importer-emitted symbol whose
# name starts with "rust-<crate>-" + a digit (the version), and ends in
# ".SHA" (i.e. is a git-source crate).
declare -A ALIASES=(
  [rust-armv7-git]=armv7
  [rust-atsama5d27-git]=atsama5d27
  [rust-com-rs-git]=com-rs
  [rust-curve25519-dalek-git]=curve25519-dalek
  [rust-engine-25519-git]=engine-25519
  [rust-engine25519-as-git]=engine25519-as
  [rust-ring-xous-git]=ring
  [rust-rqrr-git]=rqrr
  [rust-sha2-xous-git]=sha2
  [rust-simple-fatfs-git]=simple-fatfs
  [rust-usb-device-git]=usb-device
  [rust-usbd-serial-git]=usbd-serial
  [rust-xous-usb-hid-git]=xous-usb-hid
)

{
  printf '\n;;;\n;;; Friendly-name aliases for packages/bao.scm.\n;;; Appended by scripts/update-bao-crates.sh.\n;;;\n\n'
  # Sorted iteration so the file is deterministic across runs (bash
  # associative array order is unspecified).
  for friendly in $(printf '%s\n' "${!ALIASES[@]}" | sort); do
    crate=${ALIASES[$friendly]}
    # ".SHA" tail requires at least 7 hex chars (git short-rev) to avoid
    # matching plain semver suffixes like "0.1.1" where "1" is hex.
    match=$(grep -E "^\(define rust-${crate}-[0-9][^[:space:]]*\.[a-f0-9]{7,}$" "$OUT" \
            | awk '{print $2}')
    count=$(printf '%s' "$match" | grep -c . || true)
    if [ "$count" -ne 1 ]; then
      echo "error: alias $friendly: crate '$crate' matched $count symbols, expected 1" >&2
      printf '%s\n' "$match" >&2
      exit 6
    fi
    printf '(define %s %s)\n' "$friendly" "$match"
  done
} >> "$OUT"

#
# Note: (bao-cargo-inputs) thunk lives in scripts/bao-crates.tmpl.scm —
# already present in OUT from the initial template copy.

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
echo "aliases:        $(grep -cE '^\(define rust-[a-z0-9-]+-git rust-' "$OUT")"
echo "cargo keys:     $(grep -cE '^\s+\([a-z][a-z0-9-]+ =>' "$OUT")"
