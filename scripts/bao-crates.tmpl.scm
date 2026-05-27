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
;;;      the 3 git origins that need it and append friendly-name aliases for
;;;      bao.scm.  The (bao-cargo-inputs) thunk below is already in this
;;;      template — no need to regenerate it.

(define-module (bao-crates)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module ((guix build-system cargo) #:hide (crate-source))   ;TODO: drop #:hide once we accept upstream's name normalisation
  #:use-module (bao-git-snippets)
  #:export (lookup-cargo-inputs
            bao-cargo-inputs
            rust-armv7-git
            rust-atsama5d27-git
            rust-com-rs-git
            rust-curve25519-dalek-git
            rust-engine-25519-git
            rust-engine25519-as-git
            rust-ring-xous-git
            rust-rqrr-git
            rust-sha2-xous-git
            rust-simple-fatfs-git
            rust-usb-device-git
            rust-usbd-serial-git
            rust-xous-usb-hid-git))

;;; ---------------------------------------------------------------------------
;;; TODO: REMOVE — bit-identity shim, to be deleted once the refactor is settled.
;;;
;;; Local `crate-source` that preserves underscores in cargo crate names
;;; (e.g. `rand_core`) instead of letting upstream's helper from
;;; `(guix build-system cargo)` normalise them to hyphens (`rand-core`).
;;; This affects origin file-names → vendor-dir basenames → the embedded
;;; "/build/vendor/HASH-rust-rand_core-0.6.4/src/block.rs"-style strings
;;; that rustc bakes into the binary.  Keeping it makes refactor builds
;;; bit-identical to the pre-refactor (hand-curated) baseline, useful as
;;; a regression oracle.  Long-term we want to follow upstream's
;;; convention — drop this `define` and the `#:hide (crate-source)` in
;;; the module header above once we accept the cosmetic path-string diff.
;;; ---------------------------------------------------------------------------
(define (crate-source name version hash)
  (origin
    (method url-fetch)
    (uri (crate-uri name version))
    (file-name (string-append "rust-" name "-" version ".tar.gz"))
    (sha256 (base32 hash))))

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


;;;
;;; Combined input list for the firmware xtask targets — the crates.io
;;; subset of both xous-core lockfiles.  Defined as a thunk so the body
;;; isn't evaluated at module-load time (the importer puts
;;; lookup-cargo-inputs further down the file).
;;;
;;; Git origins are FILTERED OUT here: bao.scm passes them through a
;;; separate `setup-git-deps' phase wired up via %git-dependencies, and
;;; `setup-vendor' would otherwise try to `tar xzf' a directory.
;;;

(define bao-cargo-inputs
  (lambda ()
    (filter (lambda (o)
              (not (git-reference? (origin-uri o))))
            (append (lookup-cargo-inputs 'xous-core)
                    (lookup-cargo-inputs 'locales)))))
