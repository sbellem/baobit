;;; Utility tools for Baochip firmware development
;;;
;;; This module provides tools for analyzing firmware builds:
;;; - rustfilt: Rust symbol demangler
;;; - riscv32-none-elf-binutils: Cross binutils for RISC-V
;;; - elf-analyzer: Generate assembly listings from firmware ELFs

(define-module (tools)
  #:use-module (guix packages)
  #:use-module ((guix download)
                #:select (url-fetch))
  #:use-module ((guix build-system cargo)
                #:select (crate-uri))
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system trivial)
  #:use-module (guix gexp)
  #:use-module ((guix licenses)
                #:prefix license:)
  #:use-module (gnu packages cross-base)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages rust)
  #:export (rustfilt riscv32-none-elf-binutils elf-analyzer))

;;; =============================================================
;;; CRATE SOURCES (generated via guix import crate -f Cargo.lock)
;;; =============================================================

(define (crate-source name version hash)
  (origin
    (method url-fetch)
    (uri (crate-uri name version))
    (file-name (string-append "rust-" name "-" version ".tar.gz"))
    (sha256 (base32 hash))))

(define rust-bitflags-1.3.2
  (crate-source "bitflags" "1.3.2"
                "12ki6w8gn1ldq7yz9y680llwk5gmrhrzszaa17g1sbrw2r2qvwxy"))

(define rust-clap-2.34.0
  (crate-source "clap" "2.34.0"
                "071q5d8jfwbazi6zhik9xwpacx5i6kb2vkzy060vhf0c3120aqd0"))

(define rust-libc-0.2.144
  (crate-source "libc" "0.2.144"
                "1qfzrwhncsradwvdzd8vsj4mc31fh0rb5rvny3884rwa48fcq01b"))

(define rust-rustc-demangle-0.1.23
  (crate-source "rustc-demangle" "0.1.23"
                "0xnbk2bmyzshacjm2g1kd4zzv2y2az14bw3sjccq5qkpmsfvn9nn"))

(define rust-term-size-0.3.2
  (crate-source "term_size" "0.3.2"
                "1n885cykajsppx86xl7d0dqkgmgsp8v914lvs12qzvd0dij2jh8y"))

(define rust-textwrap-0.11.0
  (crate-source "textwrap" "0.11.0"
                "0q5hky03ik3y50s9sz25r438bc4nwhqc6dqwynv4wylc807n29nk"))

(define rust-unicode-width-0.1.10
  (crate-source "unicode-width" "0.1.10"
                "12vc3wv0qwg8rzcgb9bhaf5119dlmd6lmkhbfy1zfls6n7jx3vf0"))

(define rust-winapi-0.3.9
  (crate-source "winapi" "0.3.9"
                "06gl025x418lchw1wxj64ycr7gha83m44cjr5sarhynd9xkrm0sw"))

(define rust-winapi-i686-pc-windows-gnu-0.4.0
  (crate-source "winapi-i686-pc-windows-gnu" "0.4.0"
                "1dmpa6mvcvzz16zg6d5vrfy4bxgg541wxrcip7cnshi06v38ffxc"))

(define rust-winapi-x86-64-pc-windows-gnu-0.4.0
  (crate-source "winapi-x86_64-pc-windows-gnu" "0.4.0"
                "0gqq64czqb64kskjryj8isp62m2sgvx25yyj3kpc2myh85w24bki"))

(define %rustfilt-crates
  (list rust-bitflags-1.3.2
        rust-clap-2.34.0
        rust-libc-0.2.144
        rust-rustc-demangle-0.1.23
        rust-term-size-0.3.2
        rust-textwrap-0.11.0
        rust-unicode-width-0.1.10
        rust-winapi-0.3.9
        rust-winapi-i686-pc-windows-gnu-0.4.0
        rust-winapi-x86-64-pc-windows-gnu-0.4.0))

;;; =============================================================
;;; TOOLS
;;; =============================================================

;;; rustfilt - Rust symbol demangler
(define-public rustfilt
  (package
    (name "rustfilt")
    (version "0.2.2-alpha.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/luser/rustfilt")
             (commit "8cf08c0680ebd17e7c1ae5c67227fa7026129af6")))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0bqczkqymx7h1fmxhh4scy2blfimhbmzlh02f9901ni29fkfgvgn"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'check)

          ;; Set up vendor directory from crate sources
          (add-after 'unpack 'setup-vendor
            (lambda* (#:key inputs #:allow-other-keys)
              (use-modules (ice-9 popen)
                           (ice-9 rdelim))
              (let ((vendor-dir (string-append (getcwd) "/vendor")))
                (mkdir-p vendor-dir)
                (for-each (lambda (input)
                            (let* ((name (car input))
                                   (path (cdr input)))
                              (when (string-prefix? "crate-" name)
                                (let* ((file-name (basename path))
                                       (crate-name (substring file-name 5
                                                              (- (string-length
                                                                  file-name) 7)))
                                       (crate-dir (string-append vendor-dir
                                                                 "/"
                                                                 crate-name))
                                       (port (open-input-pipe (string-append
                                                               "sha256sum "
                                                               path)))
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
                                  (call-with-output-file (string-append
                                                          crate-dir
                                                          "/.cargo-checksum.json")
                                    (lambda (port)
                                      (format port
                                              "{\"files\":{},\"package\":\"~a\"}"
                                              checksum))))))) inputs))))

          ;; Configure cargo to use vendored crates
          (add-after 'setup-vendor 'configure-cargo
            (lambda _
              (mkdir-p ".cargo")
              (call-with-output-file ".cargo/config.toml"
                (lambda (port)
                  (format port "[source.crates-io]~%")
                  (format port "replace-with = \"vendored-sources\"~%")
                  (format port "[source.vendored-sources]~%")
                  (format port "directory = \"vendor\"~%")))))

          ;; Build with cargo
          (replace 'build
            (lambda _
              (setenv "CARGO_HOME"
                      (string-append (getcwd) "/.cargo-home"))
              (invoke "cargo" "build" "--release")))

          ;; Install binary
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let ((bin (string-append (assoc-ref outputs "out") "/bin")))
                (mkdir-p bin)
                (install-file "target/release/rustfilt" bin)))))))
    (native-inputs `(("rust" ,rust-1.90)
                     ("rust:cargo" ,rust-1.90 "cargo")
                     ("tar" ,tar)
                     ("gzip" ,gzip)
                     ("coreutils" ,coreutils)
                     ,@(map (lambda (crate)
                              `(,(string-append "crate-"
                                                (origin-file-name crate)) ,crate))
                            %rustfilt-crates)))
    (home-page "https://github.com/luser/rustfilt")
    (synopsis "Demangle Rust symbol names")
    (description
     "A command-line tool to demangle Rust symbol names, similar to
@code{c++filt} for C++.")
    (license license:asl2.0)))

;;; Cross binutils for RISC-V bare-metal
(define-public riscv32-none-elf-binutils
  (cross-binutils "riscv32-none-elf"))

;;; =============================================================
;;; FIRMWARE REPORT GENERATION
;;; =============================================================

;;; Generate assembly listing reports for firmware analysis
;;; Includes: headers, sorted symbols, and full disassembly with demangled names
;;; Also generates a summary file with just headers and top symbols for CI display
(define-public (elf-analyzer firmware-pkg)
  "Create a report package for FIRMWARE-PKG containing assembly listings."
  (let ((fw-name (package-name firmware-pkg)))
    (package
      (name (string-append fw-name "-report"))
      (version (package-version firmware-pkg))
      (source
       #f)
      (build-system trivial-build-system)
      (arguments
       (list
        #:modules '((guix build utils)
                    (ice-9 popen)
                    (ice-9 rdelim))
        #:builder
        #~(begin
            (use-modules (guix build utils)
                         (ice-9 popen)
                         (ice-9 rdelim))
            (let* ((out (assoc-ref %outputs "out"))
                   (firmware #$(this-package-input "firmware"))
                   (binutils #$(this-package-native-input "binutils"))
                   (rustfilt-bin #$(this-package-native-input "rustfilt"))
                   (coreutils #$(this-package-native-input "coreutils"))
                   (objdump (string-append binutils
                                           "/bin/riscv32-none-elf-objdump"))
                   (nm (string-append binutils "/bin/riscv32-none-elf-nm"))
                   (demangle (string-append rustfilt-bin "/bin/rustfilt"))
                   (head-cmd (string-append coreutils "/bin/head"))
                   (sha256sum (string-append coreutils "/bin/sha256sum"))
                   (md5sum (string-append coreutils "/bin/md5sum"))
                   (elf-files (find-files firmware "\\.elf$")))
              (mkdir-p out)
              (for-each (lambda (elf)
                          (let* ((base (basename elf ".elf"))
                                 (rpt (string-append out "/" base
                                                     "-elf-analysis.rpt"))
                                 (summary (string-append out "/" base
                                           "-elf-analysis-summary.rpt"))
                                 ;; Compute checksums using pipes
                                 (sha256 (let* ((port (open-input-pipe (string-append
                                                                        sha256sum
                                                                        " "
                                                                        elf)))
                                                (line (read-line port)))
                                           (close-pipe port)
                                           (car (string-split line #\space))))
                                 (md5 (let* ((port (open-input-pipe (string-append
                                                                     md5sum
                                                                     " " elf)))
                                             (line (read-line port)))
                                        (close-pipe port)
                                        (car (string-split line #\space))))
                                 ;; Helper to write provenance header
                                 (write-header (lambda (port)
                                                 (format port
                                                  "; Assembly Report~%")
                                                 (format port
                                                         "; Firmware: ~a~%"
                                                         firmware)
                                                 (format port "; ELF: ~a~%"
                                                         elf)
                                                 (format port "; SHA256: ~a~%"
                                                         sha256)
                                                 (format port "; MD5: ~a~%"
                                                         md5)
                                                 (format port ";~%~%"))))
                            ;; Generate full report
                            (format #t "Generating full report for ~a...~%"
                                    base)
                            (call-with-output-file rpt
                              write-header)
                            (system (string-append objdump " -h " elf " >> "
                                                   rpt))
                            (system (string-append nm
                                     " -r --size-sort --print-size "
                                     elf
                                     " | "
                                     demangle
                                     " >> "
                                     rpt))
                            (system (string-append objdump
                                                   " -S -l -d "
                                                   elf
                                                   " | "
                                                   demangle
                                                   " >> "
                                                   rpt))
                            (format #t "Done: ~a~%" rpt)
                            ;; Generate summary (headers + top 30 symbols, no disassembly)
                            (format #t "Generating summary for ~a...~%" base)
                            (call-with-output-file summary
                              write-header)
                            (system (string-append objdump " -h " elf " >> "
                                                   summary))
                            (system (string-append "echo '' >> " summary))
                            (system (string-append
                                     "echo '; Top 30 largest symbols:' >> "
                                     summary))
                            (system (string-append nm
                                     " -r --size-sort --print-size "
                                     elf
                                     " | "
                                     demangle
                                     " | "
                                     head-cmd
                                     " -30 >> "
                                     summary))
                            (format #t "Done: ~a~%" summary))) elf-files)))))
      (inputs `(("firmware" ,firmware-pkg)))
      (native-inputs `(("binutils" ,riscv32-none-elf-binutils)
                       ("rustfilt" ,rustfilt)
                       ("coreutils" ,coreutils)))
      (home-page (package-home-page firmware-pkg))
      (synopsis (string-append "Assembly report for " fw-name))
      (description (string-append "Assembly listing report for " fw-name
                    " firmware. "
                    "Contains headers, sorted symbols, and full disassembly "
                    "with demangled Rust symbol names."))
      (license (package-license firmware-pkg)))))
