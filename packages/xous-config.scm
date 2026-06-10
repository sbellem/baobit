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
                         %rust-xous-guix-hash
                         %llvm-compiler-rt-commit
                         %llvm-compiler-rt-guix-hash
                         %backtrace-rs-commit
                         %backtrace-rs-guix-hash))

;; GitHub owner (user or org)
(define %xous-owner
  "betrusted-io")
(define %xous-git-describe
  "v0.10.1-3-gb439d312a")
(define %xous-commit
  "b439d312a45479419fb8853481ce92269eecf7ff")
(define %xous-guix-hash
  "1llii1gixaicr784zqhp1lbwpnaml75s6q8j1jih3hms9y7sbr57")

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

;; betrusted-io/rust submodule pins (compiler-rt + backtrace).
;; Commits are the fork's gitlinks (src/llvm-project, library/backtrace);
;; hashes are `guix hash -rx` of those checkouts.  Derived by update-config.scm.
(define %llvm-compiler-rt-commit
  "85a90d119deb25b518867cd37d62c7b93b575a6f")
(define %llvm-compiler-rt-guix-hash
  "03wi07w42267vj2jr2s9hakssvidskfrl1nlw3n8swfwl0jnd8hf")
(define %backtrace-rs-commit
  "b65ab935fb2e0d59dba8966ffca09c9cc5a5f57c")
(define %backtrace-rs-guix-hash
  "1rymm0cxx6ypjazxjps9w59qkw90rx6594w4ayxjym1a17p78vvw")
