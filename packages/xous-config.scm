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
  "v0.10.2-181-ge8d989c75")
(define %xous-commit
  "e8d989c754bcc3a9cd66f9e3e1c70cac580731eb")
(define %xous-guix-hash
  "070ddyl8nvs1v5c16zfbp40wrzvsg0dahja4jz1s1i3476p7xwrf")

;; Rust toolchain version (e.g., "1.90", "1.91")
;; Package modules resolve this to rust-X.YZ
(define %rust-version
  "1.98")

;; betrusted-io/rust fork for Xous sysroot
;; Must match %rust-version (e.g., 1.90.0-xous branch)
(define %rust-xous-commit
  "fa073879ac5f01760105eec51f51e0c5028bb599")
(define %rust-xous-guix-hash
  "1nrqw0gniygjnh0r51i9f9j89857qd87ds3llfv3vbgfpp9pm01c")

;; betrusted-io/rust submodule pins (compiler-rt + backtrace).
;; Commits are the fork's gitlinks (src/llvm-project, library/backtrace);
;; hashes are `guix hash -rx` of those checkouts.  Derived by update-config.scm.
(define %llvm-compiler-rt-commit
  "52ed14fcd56afc30f9cccd8ca8ce237c2eef7e04")
(define %llvm-compiler-rt-guix-hash
  "1pqf0ac708wszzlmxy0dqvnn77bqa0ywwxbllcmwqk55byg6hnap")
(define %backtrace-rs-commit
  "d902726a1dcdc1e1c66f73d1162181b5423c645b")
(define %backtrace-rs-guix-hash
  "0apqspyjw96l83ngng1m462b2g97yla935wsbk8pdarvfzprik1h")
