;;; Baochip firmware build configuration
;;;
;;; This file is meant to be updated via update-config.scm
;;;
;;; To update: edit baobit.toml, then run: make update-config
;;;
;;; If you see "fatal: No names found, cannot describe anything",
;;; increase clone-depth in baobit.toml.

(define-module (xous-config)
  #:export (%xous-commit %xous-guix-hash
                         %xous-git-describe
                         %xous-owner
                         %rust-version
                         %rust-xous-commit
                         %rust-xous-guix-hash))

;; GitHub owner (user or org)
(define %xous-owner
  "betrusted-io")
(define %xous-git-describe
  "v0.10.0-28-g31738d94e")
(define %xous-commit
  "31738d94efec851f4bad313af0b46759e7fb907d")
(define %xous-guix-hash
  "022wr7hp9x2037mj6g46rr42dshhrsy61z6k2bnk8bwpfm259aj4")

;; Rust toolchain version (e.g., "1.90", "1.91")
;; Package modules resolve this to rust-X.YZ
(define %rust-version
  "1.90")

;; betrusted-io/rust fork for Xous sysroot
;; Must match %rust-version (e.g., 1.90.0-xous branch)
(define %rust-xous-commit
  "ca03bea71ce37fac6696f67020d27d4172f65771")
(define %rust-xous-guix-hash
  "01y6dl7f7ag4pgagav0qp4chir90qraidqsh7r8ml97mcsxwfkfl")
