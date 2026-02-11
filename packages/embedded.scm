;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2024 Baochan contributors
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (embedded)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages cross-base)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix platform)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (xous-core-config))

;;; Commentary:
;;;
;;; Bare-metal Rust sysroots for embedded development.
;;;
;;; This module provides pre-built Rust standard libraries (sysroots) for
;;; bare-metal targets, similar to how gnu/packages/embedded.scm provides
;;; GCC toolchains for ARM bare-metal development.
;;;
;;; Code:

(define-public rust-sysroot-riscv32imac-none-elf
  (package
    (inherit %rust)
    (name "rust-sysroot-riscv32imac-none-elf")
    (outputs '("out"))
    (arguments
     (substitute-keyword-arguments (package-arguments %rust)
       ((#:tests? _ #f) #f)
       ((#:phases phases)
        #~(modify-phases #$phases
            (replace 'configure
              (lambda* (#:key inputs outputs #:allow-other-keys)
                (let* ((out (assoc-ref outputs "out"))
                       (target-cc
                        (search-input-file
                         inputs "/bin/riscv32-none-elf-gcc"))
                       (target-ar
                        (search-input-file
                         inputs "/bin/riscv32-none-elf-ar")))
                  (call-with-output-file "config.toml"
                    (lambda (port)
                      (display
                       (string-append
                        "[llvm]\n"
                        "[build]\n"
                        "cargo = \"" (search-input-file inputs "/bin/cargo")
                        "\"\n"
                        "rustc = \"" (search-input-file inputs "/bin/rustc")
                        "\"\n"
                        "docs = false\n"
                        "python = \"" (which "python") "\"\n"
                        "vendor = true\n"
                        "submodules = false\n"
                        "target = [\"riscv32imac-unknown-none-elf\"]\n"
                        "[install]\n"
                        "prefix = \"" out "\"\n"
                        "sysconfdir = \"etc\"\n"
                        "[rust]\n"
                        "debug = false\n"
                        "jemalloc = false\n"
                        "default-linker = \"" target-cc "\"\n"
                        "channel = \"stable\"\n"
                        "[target."
                        #$(platform-rust-target
                           (lookup-platform-by-system
                            (%current-system)))
                        "]\n"
                        "llvm-config = \""
                        (search-input-file inputs "/bin/llvm-config")
                        "\"\n"
                        "linker = \"" (which "gcc") "\"\n"
                        "cc = \"" (which "gcc") "\"\n"
                        "cxx = \"" (which "g++") "\"\n"
                        "ar = \"" (which "ar") "\"\n"
                        "[target.riscv32imac-unknown-none-elf]\n"
                        "cc = \"" target-cc "\"\n"
                        "ar = \"" target-ar "\"\n"
                        "linker = \"" target-cc "\"\n"
                        "no-std = true\n"
                        "[dist]\n")
                       port))))))
            (replace 'build
              ;; Build only the standard library for the bare-metal target.
              ;; With no-std = true, this produces core, alloc, and
              ;; compiler_builtins.
              (lambda* (#:key parallel-build? #:allow-other-keys)
                (let ((job-spec (string-append
                                 "-j" (if parallel-build?
                                          (number->string (parallel-job-count))
                                          "1"))))
                  (invoke "./x.py" job-spec "build" "library/std"))))
            (replace 'install
              ;; Manual install to avoid generate-copyright failure caused by
              ;; patched cargo checksums (same issue as rust-1.91+).
              (lambda* (#:key outputs #:allow-other-keys)
                (let* ((out (assoc-ref outputs "out"))
                       (target "riscv32imac-unknown-none-elf")
                       (host-triple
                        #$(platform-rust-target
                           (lookup-platform-by-target-or-system
                            (or (%current-target-system)
                                (%current-system)))))
                       (src-lib (string-append
                                 "build/" host-triple
                                 "/stage2/lib/rustlib/" target "/lib"))
                       (dest-lib (string-append
                                  out "/lib/rustlib/" target "/lib")))
                  (mkdir-p dest-lib)
                  (for-each (lambda (f)
                              (install-file f dest-lib))
                            (find-files src-lib "\\.(rlib|a)$")))))
            (delete 'wrap-rustc)
            (delete 'delete-install-logs)))))
    (native-inputs
     (modify-inputs (package-native-inputs %rust)
       (prepend (cross-gcc "riscv32-none-elf" #:libc #f))
       (prepend (cross-binutils "riscv32-none-elf"))))
    ;; Propagate the linker so consumers don't need to add it explicitly
    (propagated-inputs
     (list (cross-binutils "riscv32-none-elf")))
    (synopsis "Bare-metal RISC-V sysroot for riscv32imac-unknown-none-elf")
    (description "Pre-built standard library (sysroot) for the
riscv32imac-unknown-none-elf Rust target, enabling compilation of bare-metal
RISC-V applications.  This package propagates the cross-binutils linker.")))
