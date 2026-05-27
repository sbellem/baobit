#!/usr/bin/env bash
# Inject (snippet bao-<name>-snippet) into the 3 git origins whose
# Cargo.toml needs editing before `cargo vendor` can succeed.
#
# This is the bare-minimum post-processing step.  Without it, building
# any firmware target with this bao-crates file would fail at the vendor
# phase, because cargo would try to resolve optional dependencies that
# aren't present in the vendor dir (rtt-target, ft3269, image, etc.)
# or feature wiring that references unavailable feature flags.
#
# The snippet variables themselves live in packages/bao-git-snippets.scm,
# which the bao-crates module already imports.
#
# Each git origin block in the importer's output looks like:
#
#   (define rust-NAME-VER.SHA
#     ;; TODO REVIEW: ...
#     (origin
#       (method git-fetch)
#       (uri ...)
#       (file-name ...)
#       (sha256 (base32 "HASH"))))
#
# We replace the final  ))))  (closing base32, sha256, origin, define)
# with  ))  (closing base32, sha256 only) and add a new line
#   (snippet bao-NAME-snippet)))   (snippet field + close origin + define)
#
# Usage:  scripts/inject-snippets.sh [FILE]
#         FILE defaults to packages/bao-crates.scm.

set -euo pipefail

OUT="${1:-packages/bao-crates.scm}"

if [ ! -f "$OUT" ]; then
  echo "error: input file not found: $OUT" >&2
  exit 1
fi

inject_snippet() {
  local prefix=$1 snippet=$2
  awk -v prefix="$prefix" -v snippet="$snippet" '
    $0 ~ "^\\(define " prefix { in_block = 1 }
    in_block && /^[[:space:]]*\(sha256 \(base32 "[^"]+"\)\)\)\)$/ {
      sub(/\)\)\)\)$/, "))")
      print
      match($0, /^[[:space:]]*/)
      indent = substr($0, RSTART, RLENGTH)
      print indent "(snippet " snippet ")))"
      in_block = 0
      next
    }
    { print }
  ' "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
}

inject_snippet rust-atsama5d27-    bao-atsama5d27-snippet
inject_snippet rust-rqrr-          bao-rqrr-snippet
inject_snippet rust-xous-usb-hid-  bao-xous-usb-hid-snippet

echo "snippets injected:"
grep -c '(snippet bao-' "$OUT"
