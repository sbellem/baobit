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
  "v0.10.0-60-ga846f680a")
(define %xous-commit
  "a846f680a882b69595e7b5b0288ec7d4f0eda98d")
(define %xous-guix-hash
  "199d7qwyp5s8ppps4h873fprwj6q8f6y1z2ir0pwj40fbhm4lx1y")

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
