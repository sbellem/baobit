;;; GNU Guix package definition for Rust with Xous target support
;;;
;;; This module provides a Rust toolchain that includes both the
;;; riscv32imac-unknown-xous-elf and riscv32imac-unknown-none-elf targets
;;; for building Xous applications and bare-metal bootloaders.

(define-module (rust-xous)
  #:use-module (guix packages)
  #:use-module (guix build-system trivial)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages commencement)
  #:use-module (rust)
  #:use-module (rust-riscv32imac-none-elf)
  #:use-module (rust-riscv32imac-xous-elf))

;;; Merged sysroot combining base Rust targets with bare-metal and Xous
(define-public rust-sysroot-merged
  (package
    (name "rust-sysroot-merged")
    (version "1.93.0")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((out (assoc-ref %outputs "out"))
                 (rustlib-out (string-append out "/lib/rustlib"))
                 (base-rust (assoc-ref %build-inputs "rust"))
                 (bare-metal-sysroot
                  (assoc-ref %build-inputs "bare-metal-sysroot"))
                 (xous-sysroot (assoc-ref %build-inputs "xous-sysroot")))
            (mkdir-p rustlib-out)
            ;; Copy base toolchain's rustlib
            (copy-recursively (string-append base-rust "/lib/rustlib")
                              rustlib-out)
            ;; Add bare-metal target
            (copy-recursively
             (string-append bare-metal-sysroot
                            "/lib/rustlib/riscv32imac-unknown-none-elf")
             (string-append rustlib-out
                            "/riscv32imac-unknown-none-elf"))
            ;; Add Xous target
            (copy-recursively
             (string-append xous-sysroot
                            "/lib/rustlib/riscv32imac-unknown-xous-elf")
             (string-append rustlib-out
                            "/riscv32imac-unknown-xous-elf"))))))
    (inputs
     `(("rust" ,rust-1.93)
       ("bare-metal-sysroot" ,rust-sysroot-riscv32imac-none-elf)
       ("xous-sysroot" ,xous-sysroot)))
    (home-page "https://github.com/betrusted-io/rust")
    (synopsis "Merged Rust sysroot with Xous and bare-metal targets")
    (description "A merged Rust sysroot that combines the standard library
targets with both riscv32imac-unknown-xous-elf and riscv32imac-unknown-none-elf
targets for Xous development.")
    (license (list license:asl2.0 license:expat))))

;;; Final wrapped Rust toolchain with Xous support
(define-public rust-xous
  (package
    (name "rust-xous")
    (version "1.93.0")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((out (assoc-ref %outputs "out"))
                 (bin-dir (string-append out "/bin"))
                 (base-rust (assoc-ref %build-inputs "rust"))
                 (base-rust-cargo (assoc-ref %build-inputs "rust:cargo"))
                 (merged-sysroot (assoc-ref %build-inputs "rust-sysroot-merged"))
                 (gcc-toolchain (assoc-ref %build-inputs "gcc-toolchain"))
                 (bash (assoc-ref %build-inputs "bash"))
                 ;; LD_LIBRARY_PATH for libgcc_s.so.1 needed by build scripts
                 (ld-library-path (string-append gcc-toolchain "/lib")))
            (mkdir-p bin-dir)

            ;; Create cc symlink to gcc (needed by Rust's cc crate)
            (symlink (string-append gcc-toolchain "/bin/gcc")
                     (string-append bin-dir "/cc"))

            ;; Create wrapper for rustc
            (call-with-output-file (string-append bin-dir "/rustc")
              (lambda (port)
                (format port "#!~a/bin/bash~%" bash)
                (format port "export LD_LIBRARY_PATH=\"~a${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}\"~%"
                        ld-library-path)
                (format port "exec ~a/bin/rustc --sysroot ~a \"$@\"~%"
                        base-rust merged-sysroot)))
            (chmod (string-append bin-dir "/rustc") #o755)

            ;; Create wrapper for cargo (use cargo output, not main output)
            (call-with-output-file (string-append bin-dir "/cargo")
              (lambda (port)
                (format port "#!~a/bin/bash~%" bash)
                (format port "export LD_LIBRARY_PATH=\"~a${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}\"~%"
                        ld-library-path)
                (format port "export RUSTC=~a/bin/rustc~%" out)
                (format port "exec ~a/bin/cargo \"$@\"~%" base-rust-cargo)))
            (chmod (string-append bin-dir "/cargo") #o755)

            ;; Symlink other tools from main rust output
            (for-each
             (lambda (tool)
               (let ((source (string-append base-rust "/bin/" tool))
                     (target (string-append bin-dir "/" tool)))
                 (when (file-exists? source)
                   (symlink source target))))
             '("rustfmt" "cargo-fmt" "clippy-driver" "cargo-clippy"
               "rust-analyzer" "rustdoc"))))))
    (inputs
     `(("rust" ,rust-1.93)
       ("rust:cargo" ,rust-1.93 "cargo")
       ("rust-sysroot-merged" ,rust-sysroot-merged)
       ("gcc-toolchain" ,gcc-toolchain)
       ("bash" ,bash)))
    ;; Propagate linkers from sysroot packages so consumers don't need them
    (propagated-inputs
     `(("bare-metal-sysroot" ,rust-sysroot-riscv32imac-none-elf)
       ("xous-sysroot" ,xous-sysroot)))
    (home-page "https://github.com/betrusted-io/rust")
    (synopsis "Rust toolchain with Xous and bare-metal target support")
    (description "A complete Rust toolchain that includes support for both
riscv32imac-unknown-xous-elf and riscv32imac-unknown-none-elf targets,
enabling development of applications for the Xous operating system and
bare-metal bootloaders on RISC-V hardware.  Linkers are propagated from
the sysroot packages.")
    (license (list license:asl2.0 license:expat))))

rust-xous
