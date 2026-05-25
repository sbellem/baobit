#!/usr/bin/env bash
# Post-process a bao-crates.scm that has already been populated by
# `guix import crate --lockfile=...` runs.
#
# Expected input shape (what the importer produces against our template):
#   - Module header with `#:use-module (bao-git-snippets)` and an #:export
#     list that includes bao-cargo-inputs.
#   - qqqq-separator ... ssss-separator block with the importer's
#     (define rust-NAME-VERSION ...) blocks.
#   - (define-cargo-inputs lookup-cargo-inputs ...) populated with the
#     keys `xous-core` and `locales` (one (KEY => (list ...)) per lockfile
#     the user imported).
#   - (define (bao-cargo-inputs) ...) thunk — already in the template.
#
# One transformation: inject (snippet bao-<name>-snippet) into the 3 git
# origins whose Cargo.toml needs editing.  Snippet vars come from
# bao-git-snippets.
#
# Usage:  scripts/post-process-bao-crates.sh [FILE]
#         FILE defaults to packages/bao-crates.scm.

set -euo pipefail

OUT="${1:-packages/bao-crates.scm}"

if [ ! -f "$OUT" ]; then
  echo "error: input file not found: $OUT" >&2
  exit 1
fi

# Idempotency guard — refuse to run twice on the same file.
# Snippets are the unique post-process artefact; if any is present we're done.
if grep -qE '\(snippet bao-[a-z0-9-]+-snippet\)' "$OUT"; then
  echo "error: $OUT already contains snippet injections — already post-processed." >&2
  echo "Reset by re-copying the template and re-running the importer." >&2
  exit 2
fi

# Sanity-check the input shape so we fail fast with a clear message rather
# than producing a half-mangled file.
if ! grep -q '^(define-cargo-inputs lookup-cargo-inputs$' "$OUT" \
   && ! grep -q '^(define-cargo-inputs lookup-cargo-inputs' "$OUT"; then
  echo "error: $OUT has no (define-cargo-inputs lookup-cargo-inputs ...) form." >&2
  echo "Run the importer first." >&2
  exit 3
fi
for k in xous-core locales; do
  if ! grep -qE "^[[:space:]]+\($k =>" "$OUT"; then
    echo "error: $OUT lacks cargo-inputs key '$k'." >&2
    echo "Expected the importer to be run for both lockfiles." >&2
    exit 3
  fi
done

#
# 1. Inject (snippet bao-<name>-snippet) into git origins that need it.
#
# Each git origin block ends with a line shaped like
#     (sha256 (base32 "...."))))
# The four trailing parens close: base32, sha256, origin, define.
# We split that into two lines, inserting (snippet ...) inside (origin ...):
#     (sha256 (base32 "...."))
#     (snippet bao-<name>-snippet)))
#

inject_snippet() {
  local prefix=$1 snippet=$2
  awk -v prefix="$prefix" -v snippet="$snippet" '
    $0 ~ "^\\(define " prefix { in_block = 1 }
    in_block && /^[[:space:]]*\(sha256 \(base32 "[^"]+"\)\)\)\)$/ {
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

for s in bao-atsama5d27-snippet bao-rqrr-snippet bao-xous-usb-hid-snippet; do
  n=$(grep -c "(snippet $s)" "$OUT")
  if [ "$n" -ne 1 ]; then
    echo "error: expected 1 injection of $s, found $n" >&2
    exit 5
  fi
done

#
# Final sanity check.
# Note: the (bao-cargo-inputs) thunk lives in scripts/bao-crates.tmpl.scm, not
# here — it's static and doesn't need to be regenerated.
#

opens=$(tr -cd '(' < "$OUT" | wc -c)
closes=$(tr -cd ')' < "$OUT" | wc -c)
if [ "$opens" -ne "$closes" ]; then
  echo "error: paren mismatch in $OUT — opens=$opens closes=$closes" >&2
  exit 7
fi

echo "post-processed: $OUT"
echo "  lines:         $(wc -l < "$OUT")"
echo "  crate defines: $(grep -c '^(define rust-' "$OUT")"
echo "  snippets:      $(grep -c '(snippet bao-' "$OUT")"
echo "  cargo keys:    $(grep -cE '^[[:space:]]+\([a-z][a-z0-9-]+ =>' "$OUT")"
