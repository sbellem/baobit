;;; GNU Guix package definitions for Xous Rust toolchain
;;;
;;; This module provides:
;;; - rust-sysroot-riscv32imac-xous-elf: Xous sysroot (Rust stdlib for Xous target)
;;; - rust-xous-toolchain: Complete Rust toolchain for Xous development
;;;
;;; The sysroot is built from the betrusted-io/rust fork which adds Xous target
;;; support. The toolchain combines this with the bare-metal sysroot from
;;; embedded.scm for building both Xous applications and bootloaders.

(define-module (rust-xous-toolchain)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system trivial)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((guix licenses)
                #:prefix license:)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages cross-base)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages rust)
  #:use-module (embedded)
  #:use-module (xous-sysroot-crates)
  #:use-module (xous-config))

;; Resolve %rust-version string to actual rust package
(define %rust
  (module-ref (resolve-module '(gnu packages rust))
              (string->symbol (string-append "rust-" %rust-version))))

;;;
;;; Xous sysroot (riscv32imac-unknown-xous-elf)
;;;

;;; The betrusted-io/rust fork with Xous target support
;;; Note: We don't use (recursive? #t) to avoid fetching the massive llvm-project
;;; submodule (~2GB). Instead, we fetch just compiler-rt separately below.
(define rust-xous-source
  (origin
    (method git-fetch)
    (uri (git-reference (url "https://github.com/betrusted-io/rust")
                        (commit %rust-xous-commit)))
    (file-name "rust-xous-source")
    (sha256 (base32 %rust-xous-guix-hash))))

;;; LLVM compiler-rt source (needed for builtins)
;;; Fetched separately to avoid the 2GB+ recursive llvm-project fetch.
;;; From betrusted-io/rust 1.90.0-xous .gitmodules: rust-lang/llvm-project branch rustc/20.1-2025-07-13
(define llvm-compiler-rt-source
  (origin
    (method git-fetch)
    (uri (git-reference (url "https://github.com/rust-lang/llvm-project")
                        (commit "e8a2ffcf322f45b8dce82c65ab27a3e2430a6b51")))
    (file-name "llvm-compiler-rt-source")
    (sha256 (base32 "1cw6a6blx0qfvlsp2p5wzdlnqnnnlcfjz5xx24vlcsm43vp0mk1a"))))

;;; Backtrace-rs source (needed for std's backtrace support)
;;; Commit from betrusted-io/rust 1.90.0-xous submodule reference
(define backtrace-rs-source
  (origin
    (method git-fetch)
    (uri (git-reference (url "https://github.com/rust-lang/backtrace-rs")
                        (commit "b65ab935fb2e0d59dba8966ffca09c9cc5a5f57c")))
    (file-name "backtrace-rs-source")
    (sha256 (base32 "1rymm0cxx6ypjazxjps9w59qkw90rx6594w4ayxjym1a17p78vvw"))))

;;; RISC-V 32-bit bare-metal cross toolchain (needed for build)
(define riscv32-none-elf-gcc
  (cross-gcc "riscv32-none-elf"
             #:libc #f))

(define riscv32-none-elf-binutils
  (cross-binutils "riscv32-none-elf"))

(define-public rust-sysroot-riscv32imac-xous-elf
  (package
    (name "rust-sysroot-riscv32imac-xous-elf")
    (version (string-append %rust-version ".0"))
    (source
     rust-xous-source)
    (build-system gnu-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'check)
          (add-after 'unpack 'setup-submodules
            (lambda* (#:key inputs #:allow-other-keys)
              ;; Set up compiler-rt from the separate llvm-project fetch
              ;; The build expects it at src/llvm-project/compiler-rt
              (let ((llvm-src (assoc-ref inputs "llvm-compiler-rt"))
                    (backtrace-src (assoc-ref inputs "backtrace-rs")))
                (mkdir-p "src/llvm-project")
                (copy-recursively (string-append llvm-src "/compiler-rt")
                                  "src/llvm-project/compiler-rt")
                ;; Set up backtrace-rs for std's backtrace support
                (copy-recursively backtrace-src "library/backtrace"))))
          (add-after 'setup-submodules 'setup-vendor
            (lambda* (#:key inputs #:allow-other-keys)
              (use-modules (ice-9 popen)
                           (ice-9 rdelim))
              ;; Create vendor directory and unpack all crates
              (let ((vendor-dir "library/vendor"))
                (mkdir-p vendor-dir)
                (for-each (lambda (input)
                            (let* ((name (car input))
                                   (path (cdr input)))
                              ;; Only process crate-* inputs
                              (when (string-prefix? "crate-" name)
                                (let* ((file-name (basename path))
                                       ;; Parse rust-memchr-2.7.6.tar.gz -> memchr-2.7.6
                                       (crate-name (substring file-name 5 ;drop "rust-"
                                                              (- (string-length
                                                                  file-name) 7)))
                                       (crate-dir (string-append vendor-dir
                                                                 "/"
                                                                 crate-name))
                                       ;; Compute sha256 of the tarball for cargo checksum
                                       (port (open-pipe* OPEN_READ
                                                         "sha256sum" path))
                                       (checksum-line (read-line port))
                                       (_ (close-pipe port))
                                       (checksum (car (string-split
                                                       checksum-line #\space))))
                                  (mkdir-p crate-dir)
                                  (invoke "tar"
                                          "xzf"
                                          path
                                          "-C"
                                          crate-dir
                                          "--strip-components=1")
                                  ;; Create .cargo-checksum.json
                                  (call-with-output-file (string-append
                                                          crate-dir
                                                          "/.cargo-checksum.json")
                                    (lambda (port)
                                      (format port
                                              "{\"files\":{},\"package\":\"~a\"}"
                                              checksum))))))) inputs))))
          (replace 'build
            (lambda* (#:key native-inputs inputs #:allow-other-keys)
              (let* ((vendor-dir (string-append (getcwd) "/library/vendor"))
                     (riscv-gcc (search-input-file inputs
                                 "/bin/riscv32-none-elf-gcc"))
                     (riscv-ar (search-input-file inputs
                                                  "/bin/riscv32-none-elf-ar"))
                     (host-gcc (search-input-file inputs "/bin/gcc"))
                     (gcc-lib (search-input-file inputs "/lib/libgcc_s.so.1"))
                     (gcc-lib-dir (dirname gcc-lib))
                     (cc-wrapper-dir (string-append (getcwd) "/cc-wrapper")))
                ;; Set up environment
                (setenv "HOME"
                        (getcwd))
                (setenv "CARGO_HOME"
                        (string-append (getcwd) "/.cargo"))
                (mkdir-p (getenv "CARGO_HOME"))

                ;; Create cc symlink so cargo can find it
                (mkdir-p cc-wrapper-dir)
                (symlink host-gcc
                         (string-append cc-wrapper-dir "/cc"))
                (setenv "PATH"
                        (string-append cc-wrapper-dir ":"
                                       (getenv "PATH")))

                ;; Set LD_LIBRARY_PATH so build scripts can find libgcc_s.so.1
                (setenv "LD_LIBRARY_PATH" gcc-lib-dir)

                ;; Configure vendored dependencies
                (call-with-output-file ".cargo/config.toml"
                  (lambda (port)
                    (format port "[source.crates-io]~%")
                    (format port "replace-with = \"vendored-sources\"~%")
                    (format port "~%")
                    (format port "[source.vendored-sources]~%")
                    (format port "directory = \"~a\"~%" vendor-dir)))

                ;; Environment for building
                (setenv "CARGO_PROFILE_RELEASE_DEBUG" "0")
                (setenv "CARGO_PROFILE_RELEASE_OPT_LEVEL" "3")
                (setenv "CARGO_PROFILE_RELEASE_DEBUG_ASSERTIONS" "false")
                (setenv "RUSTC_BOOTSTRAP" "1")
                (setenv "RUSTFLAGS"
                        (string-append "-Cforce-unwind-tables=yes "
                                       "-Cembed-bitcode=yes "
                                       "-Zforce-unstable-if-unmarked"))
                (setenv "__CARGO_DEFAULT_LIB_METADATA" "stablestd")
                ;; Host CC for build scripts (they run on the host)
                (setenv "CC" host-gcc)
                ;; Target CC/AR for cross-compilation
                (setenv "CC_riscv32imac_unknown_xous_elf" riscv-gcc)
                (setenv "AR_riscv32imac_unknown_xous_elf" riscv-ar)
                (setenv "RUST_COMPILER_RT_ROOT"
                        (string-append (getcwd)
                                       "/src/llvm-project/compiler-rt"))

                ;; Build sysroot
                (invoke "cargo"
                 "build"
                 "--target"
                 "riscv32imac-unknown-xous-elf"
                 "-Zbinary-dep-depinfo"
                 "--release"
                 "--features"
                 "panic-unwind compiler-builtins-c compiler-builtins-mem"
                 "--manifest-path"
                 "library/sysroot/Cargo.toml"))))
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (lib-dir (string-append out
                               "/lib/rustlib/riscv32imac-unknown-xous-elf/lib")))
                (mkdir-p lib-dir)
                ;; Write version file
                (call-with-output-file
                    (string-append out "/lib/rustlib/"
                                   "riscv32imac-unknown-xous-elf/RUST_VERSION")
                  (lambda (port)
                    (format port "~a~%"
                            #$version)))
                ;; Copy rlib files
                (for-each (lambda (file)
                            (copy-file file
                                       (string-append lib-dir "/"
                                                      (basename file))))
                          (find-files
                           "library/target/riscv32imac-unknown-xous-elf/release/deps"
                           "\\.rlib$"))))))))
    (native-inputs `(("rust" ,%rust)
                     ("rust:cargo" ,%rust "cargo")
                     ("gcc-toolchain" ,gcc-toolchain)
                     ("git" ,git)
                     ("tar" ,tar)
                     ("gzip" ,gzip)
                     ("coreutils" ,coreutils)
                     ("gcc-cross-sans-libc-riscv32-none-elf" ,riscv32-none-elf-gcc)
                     ("binutils-cross-riscv32-none-elf" ,riscv32-none-elf-binutils)
                     ("llvm-compiler-rt" ,llvm-compiler-rt-source)
                     ("backtrace-rs" ,backtrace-rs-source)
                     ;; Add all crates as inputs with crate- prefix
                     ,@(map (lambda (crate)
                              `(,(string-append "crate-"
                                                (origin-file-name crate)) ,crate))
                            sysroot-crate-origins)))
    ;; Propagate the linker so consumers don't need to add it explicitly
    (propagated-inputs (list lld-18))
    (home-page "https://github.com/betrusted-io/rust")
    (synopsis "Xous sysroot for riscv32imac-unknown-xous-elf target")
    (description
     "Pre-built standard library (sysroot) for the
riscv32imac-unknown-xous-elf Rust target, enabling compilation of Xous
applications.  This package propagates lld-18 as the linker.")
    (license (list license:asl2.0 license:expat))))

;;;
;;; Combined Rust toolchain for Xous development
;;;

;;; Merged sysroot combining base Rust targets with bare-metal and Xous
(define-public rust-sysroot-merged
  (package
    (name "rust-sysroot-merged")
    (version (string-append %rust-version ".0"))
    (source
     #f)
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
                 (bare-metal-sysroot (assoc-ref %build-inputs
                                      "rust-sysroot-riscv32imac-none-elf"))
                 (xous-sysroot
                  (assoc-ref %build-inputs
                             "rust-sysroot-riscv32imac-xous-elf")))
            (mkdir-p rustlib-out)
            ;; Copy base toolchain's rustlib
            (copy-recursively (string-append base-rust "/lib/rustlib")
                              rustlib-out)
            ;; Add bare-metal target
            (copy-recursively (string-append bare-metal-sysroot
                               "/lib/rustlib/riscv32imac-unknown-none-elf")
                              (string-append rustlib-out
                                             "/riscv32imac-unknown-none-elf"))
            ;; Add Xous target
            (copy-recursively (string-append xous-sysroot
                               "/lib/rustlib/riscv32imac-unknown-xous-elf")
                              (string-append rustlib-out
                                             "/riscv32imac-unknown-xous-elf"))))))
    (inputs `(("rust" ,%rust)
              ("rust-sysroot-riscv32imac-none-elf" ,rust-sysroot-riscv32imac-none-elf)
              ("rust-sysroot-riscv32imac-xous-elf" ,rust-sysroot-riscv32imac-xous-elf)))
    (home-page "https://github.com/betrusted-io/rust")
    (synopsis "Merged Rust sysroot with Xous and bare-metal targets")
    (description
     "A merged Rust sysroot that combines the standard library
targets with both riscv32imac-unknown-xous-elf and riscv32imac-unknown-none-elf
targets for Xous development.")
    (license (list license:asl2.0 license:expat))))

;;; Final wrapped Rust toolchain with Xous support
(define-public rust-xous-toolchain
  (package
    (name "rust-xous-toolchain")
    (version (string-append %rust-version ".0"))
    (source
     #f)
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
                 (merged-sysroot (assoc-ref %build-inputs
                                            "rust-sysroot-merged"))
                 (gcc-toolchain (assoc-ref %build-inputs "gcc-toolchain"))
                 (bash (assoc-ref %build-inputs "bash-minimal"))
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
                (format port
                 "export LD_LIBRARY_PATH=\"~a${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}\"~%"
                 ld-library-path)
                (format port "exec ~a/bin/rustc --sysroot ~a \"$@\"~%"
                        base-rust merged-sysroot)))
            (chmod (string-append bin-dir "/rustc") #o755)

            ;; Create wrapper for cargo (use cargo output, not main output)
            (call-with-output-file (string-append bin-dir "/cargo")
              (lambda (port)
                (format port "#!~a/bin/bash~%" bash)
                (format port
                 "export LD_LIBRARY_PATH=\"~a${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}\"~%"
                 ld-library-path)
                (format port "export RUSTC=~a/bin/rustc~%" out)
                (format port "exec ~a/bin/cargo \"$@\"~%" base-rust-cargo)))
            (chmod (string-append bin-dir "/cargo") #o755)

            ;; Symlink other tools from main rust output
            (for-each (lambda (tool)
                        (let ((source (string-append base-rust "/bin/" tool))
                              (target (string-append bin-dir "/" tool)))
                          (when (file-exists? source)
                            (symlink source target))))
                      '("rustfmt" "cargo-fmt" "clippy-driver" "cargo-clippy"
                        "rust-analyzer" "rustdoc"))))))
    (inputs `(("rust" ,%rust)
              ("rust:cargo" ,%rust "cargo")
              ("rust-sysroot-merged" ,rust-sysroot-merged)
              ("gcc-toolchain" ,gcc-toolchain)
              ("bash-minimal" ,bash-minimal)))
    ;; Propagate linkers from sysroot packages
    (propagated-inputs
     `(("rust-sysroot-riscv32imac-none-elf"
        ,rust-sysroot-riscv32imac-none-elf)
       ("rust-sysroot-riscv32imac-xous-elf"
        ,rust-sysroot-riscv32imac-xous-elf)))
    (home-page "https://github.com/betrusted-io/rust")
    (synopsis "Rust toolchain with Xous and bare-metal target support")
    (description
     "A complete Rust toolchain that includes support for both
riscv32imac-unknown-xous-elf and riscv32imac-unknown-none-elf targets,
enabling development of applications for the Xous operating system and
bare-metal bootloaders on RISC-V hardware.  Linkers are propagated from
the sysroot packages.")
    (license (list license:asl2.0 license:expat))))
