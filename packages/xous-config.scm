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
  "1.94")

;; betrusted-io/rust fork for Xous sysroot
;; Must match %rust-version (e.g., 1.90.0-xous branch)
(define %rust-xous-commit
  "fa8d53c5ed77e1707686acf94b0569cbed37696b")
(define %rust-xous-guix-hash
  "08v0phd73qsdz50ylksc8yln0xrym8zm53z59mfc7sfvf9nsslp4")

;; betrusted-io/rust submodule pins (compiler-rt + backtrace).
;; Commits are the fork's gitlinks (src/llvm-project, library/backtrace);
;; hashes are `guix hash -rx` of those checkouts.  Derived by update-config.scm.
(define %llvm-compiler-rt-commit
  "00d23d10dc48c6bb9d57ba96d4a748d85d77d0c7")
(define %llvm-compiler-rt-guix-hash
  "1ay736pskcf4fzrdqw9kw5z6dskf329hjxw4xyk88g688nmzbzmi")
(define %backtrace-rs-commit
  "b65ab935fb2e0d59dba8966ffca09c9cc5a5f57c")
(define %backtrace-rs-guix-hash
  "1rymm0cxx6ypjazxjps9w59qkw90rx6594w4ayxjym1a17p78vvw")
