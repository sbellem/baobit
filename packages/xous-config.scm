;;; Baochip firmware build configuration
;;;
;;; This file is meant to be updated via update-config.scm
;;;
;;; To update: edit baobit.toml, then run: make update-config

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
  "v0.10.1-0-gbcfdca404")
(define %xous-commit
  "bcfdca40486cc7e0cecfb76fed20cd2b84d5a2e9")
(define %xous-guix-hash
  "1b9smwwvs2zd7g83xv51qzf8yv1lmk7mlpjdm6x8y54xnyg3krs1")

;; Rust toolchain version (e.g., "1.90", "1.91")
;; Package modules resolve this to rust-X.YZ
(define %rust-version
  "1.93")

;; betrusted-io/rust fork for Xous sysroot
;; Must match %rust-version (e.g., 1.90.0-xous branch)
(define %rust-xous-commit
  "2ae864f7d4d42c73ab05f5e01265ea31ae81a86e")
(define %rust-xous-guix-hash
  "0lh2ja680clqc5clcch8av8505rk5s71nkdg21yj4c7w5h24bmay")
