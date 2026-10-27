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
  "1.96")

;; betrusted-io/rust fork for Xous sysroot
;; Must match %rust-version (e.g., 1.90.0-xous branch)
(define %rust-xous-commit
  "a48a2a994bfc528906b2b8a5dad810d321a10791")
(define %rust-xous-guix-hash
  "0sbjaaqjvl72hsm7jq4bbfabpch3za441yqispcqjajv5l5p8sn4")

;; betrusted-io/rust submodule pins (compiler-rt + backtrace).
;; Commits are the fork's gitlinks (src/llvm-project, library/backtrace);
;; hashes are `guix hash -rx` of those checkouts.  Derived by update-config.scm.
(define %llvm-compiler-rt-commit
  "1cb4e3833c1919c2e6fb579a23ac0e2b22587b7e")
(define %llvm-compiler-rt-guix-hash
  "0sm4qly2a1mxg9zw8ym1vynsdpsi7spf030ilyaqfq4a20z3w6q0")
(define %backtrace-rs-commit
  "28ec93b503bf0410745bc3d571bf3dc1caac3019")
(define %backtrace-rs-guix-hash
  "1vbqd5i1znqik5r5ai0gl77dib3svfyl1i66ywhzyvaz1ch2mxvy")
