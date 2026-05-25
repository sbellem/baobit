;;; Baochip crate sources.
;;;
;;; This file is managed by 'guix import'.  Do NOT add definitions manually.
;;;
;;; Workflow:
;;;   1. Copy this template:
;;;        cp scripts/bao-crates.tmpl.scm packages/bao-crates.scm
;;;   2. Run `guix import -i packages/bao-crates.scm crate --lockfile=...`
;;;      once per xous-core Cargo.lock — typically:
;;;        - xous-core/Cargo.lock           with key  xous-core
;;;        - xous-core/locales/Cargo.lock   with key  locales
;;;   3. Run scripts/post-process-bao-crates.sh to inject (snippet ...) into
;;;      the 3 git origins whose Cargo.toml needs editing.

(define-module (bao-crates)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system cargo)
  #:use-module (bao-git-snippets)
  #:export (lookup-cargo-inputs))

;;;
;;; Rust libraries fetched from crates.io and from git sources
;;; referenced by xous-core's Cargo.lock files.
;;;

(define qqqq-separator 'begin-of-crates)

(define ssss-separator 'end-of-crates)


;;;
;;; Cargo inputs.
;;;

(define-cargo-inputs lookup-cargo-inputs)
