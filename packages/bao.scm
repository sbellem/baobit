;;; GNU Guix package definitions for production Xous firmware builds
;;;
;;; This module provides packages for building Xous firmware images
;;; using git-fetch for reproducible builds across machines.
;;;
;;; IMPORTANT: When updating xous-core version, edit xous-config.scm

(define-module (bao)
  #:use-module (guix packages)
  #:use-module (guix records)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system trivial)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((guix licenses)
                #:prefix license:)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages version-control)
  #:use-module (srfi srfi-1)
  #:use-module (rust-xous-toolchain)
  #:use-module (bao-crates)
  #:use-module (xous-config))

;;; =============================================================
;;; VERSION CONFIGURATION - See xous-config.scm
;;; =============================================================

;; Short hash for display (first 8 chars of commit)
(define %xous-short-hash
  (substring %xous-commit 0 8))

;;; =============================================================
;;; ELF BINARY NAMES
;;; =============================================================
;;; Maps xtask command to ELF binary name produced by cargo.
;;; alt-boot1 uses bao1x-boot1 binary (substituted by xtask).

(define %elf-binary-names
  '(("bao1x-boot0" . "bao1x-boot0") ("bao1x-boot1" . "bao1x-boot1")
    ("bao1x-alt-boot1" . "bao1x-boot1")
    ("bao1x-baremetal-dabao" . "bao1x-baremetal-dabao")
    ("dabao" . "dabao")
    ("baosec" . "baosec")))

;;; =============================================================
;;; SOURCE DEFINITION - Fetched via git, fully reproducible
;;; =============================================================

(define xous-core-source
  (origin
    (method git-fetch)
    (uri (git-reference (url (string-append "https://github.com/" %xous-owner
                                            "/xous-core"))
                        (commit %xous-commit)))
    (file-name (git-file-name "xous-core" %xous-git-describe))
    (sha256 (base32 %xous-guix-hash))))

;;; Git dependency record type
(define-record-type* <git-dependency> git-dependency make-git-dependency
  git-dependency?
  (name git-dependency-name) ;Input name (e.g., "git-armv7")
  (origin
    git-dependency-origin) ;Origin object for the git repo
  (url git-dependency-url) ;Git URL (for Cargo.toml patching)
  (crates git-dependency-crates))
; Alist of (crate-name . subdir)

(define %git-dependencies
  (list (git-dependency (name "git-armv7")
                        (origin
                          rust-armv7-git)
                        (url "https://github.com/Foundation-Devices/armv7.git")
                        (crates '(("armv7" . "."))))
        (git-dependency (name "git-atsama5d27")
                        (origin
                          rust-atsama5d27-git)
                        (url
                         "https://github.com/Foundation-Devices/atsama5d27.git")
                        (crates '(("atsama5d27" . ".") ("utralib" . "utralib"))))
        (git-dependency (name "git-com-rs")
                        (origin
                          rust-com-rs-git)
                        (url "https://github.com/betrusted-io/com_rs")
                        (crates '(("com_rs" . "."))))
        (git-dependency (name "git-curve25519-dalek")
                        (origin
                          rust-curve25519-dalek-git)
                        (url
                         "https://github.com/betrusted-io/curve25519-dalek.git")
                        (crates '(("curve25519-dalek" . "curve25519-dalek")
                                  ("curve25519-dalek-derive" . "curve25519-dalek-derive"))))
        (git-dependency (name "git-engine-25519")
                        (origin
                          rust-engine-25519-git)
                        (url
                         "https://github.com/betrusted-io/xous-engine-25519.git")
                        (crates '(("engine-25519" . "."))))
        (git-dependency (name "git-engine25519-as")
                        (origin
                          rust-engine25519-as-git)
                        (url
                         "https://github.com/betrusted-io/engine25519-as.git")
                        (crates '(("engine25519-as" . "."))))
        (git-dependency (name "git-ring-xous")
                        (origin
                          rust-ring-xous-git)
                        (url "https://github.com/betrusted-io/ring-xous")
                        (crates '(("ring" . "."))))
        (git-dependency (name "git-rqrr")
                        (origin
                          rust-rqrr-git)
                        (url "https://github.com/betrusted-io/rqrr.git")
                        (crates '(("rqrr" . "."))))
        (git-dependency (name "git-sha2-xous")
                        (origin
                          rust-sha2-xous-git)
                        (url "https://github.com/betrusted-io/hashes.git")
                        (crates '(("sha2" . "sha2"))))
        (git-dependency (name "git-simple-fatfs")
                        (origin
                          rust-simple-fatfs-git)
                        (url
                         "https://github.com/betrusted-io/simple-fatfs.git")
                        (crates '(("simple-fatfs" . "."))))
        (git-dependency (name "git-usb-device")
                        (origin
                          rust-usb-device-git)
                        (url "https://github.com/betrusted-io/usb-device.git")
                        (crates '(("usb-device" . "."))))
        (git-dependency (name "git-usbd-serial")
                        (origin
                          rust-usbd-serial-git)
                        (url "https://github.com/betrusted-io/usbd-serial.git")
                        (crates '(("usbd-serial" . "."))))
        (git-dependency (name "git-xous-usb-hid")
                        (origin
                          rust-xous-usb-hid-git)
                        (url
                         "https://github.com/betrusted-io/xous-usb-hid.git")
                        (crates '(("xous-usb-hid" . "."))))))

;;; Derive git URL to local path mappings from %git-dependencies
(define (git-deps->mappings deps)
  (append-map (lambda (dep)
                (let ((input-name (git-dependency-name dep))
                      (git-url (git-dependency-url dep))
                      (crate-mappings (git-dependency-crates dep)))
                  (map (lambda (mapping)
                         (list (car mapping) git-url input-name
                               (cdr mapping))) crate-mappings))) deps))

(define %git-mappings
  (git-deps->mappings %git-dependencies))

;;; Helper to create firmware build packages
(define* (make-firmware-build name xtask-cmd
                              #:key (target-dir "riscv32imac-unknown-none-elf")
                              (crate-inputs '()))
  (package
    (name name)
    (version %xous-git-describe)
    (source
     xous-core-source)
    (build-system gnu-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'check)

          ;; Phase 1: Set up crates.io vendor directory
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
                                  (call-with-output-file (string-append
                                                          crate-dir
                                                          "/.cargo-checksum.json")
                                    (lambda (port)
                                      (format port
                                              "{\"files\":{},\"package\":\"~a\"}"
                                              checksum))))))) inputs))))

          ;; Phase 2: Set up git dependencies
          (add-after 'setup-vendor 'setup-git-deps
            (lambda* (#:key inputs #:allow-other-keys)
              (use-modules (ice-9 textual-ports)
                           (ice-9 regex))
              (let ((git-vendor-dir (string-append (getcwd) "/git-vendor")))
                (mkdir-p git-vendor-dir)

                ;; Copy git checkouts and fix permissions
                (for-each (lambda (input)
                            (let* ((name (car input))
                                   (path (cdr input)))
                              (when (string-prefix? "git-" name)
                                (let ((dest-dir (string-append git-vendor-dir
                                                               "/" name)))
                                  (copy-recursively path dest-dir)
                                  (for-each (lambda (f)
                                              (chmod f #o755))
                                            (find-files dest-dir ".*"
                                                        #:directories? #t))))))
                          inputs)

                ;; Clean up Cargo.toml files in git checkouts
                (for-each (lambda (cargo-toml)
                            (let ((content (call-with-input-file cargo-toml
                                             get-string-all)))
                              (when (or (string-contains content "[workspace]")
                                        (string-contains content
                                                         "[dev-dependencies]"))
                                (call-with-output-file cargo-toml
                                  (lambda (port)
                                    (let* ((modified content)
                                           (modified (regexp-substitute/global
                                                      #f "\\[workspace\\]\n?"
                                                      modified
                                                      'pre
                                                      'post))
                                           (modified (regexp-substitute/global
                                                      #f
                                                      "members *= *\\[([^]]|\n)*\\]\n?"
                                                      modified
                                                      'pre
                                                      'post))
                                           (modified (regexp-substitute/global
                                                      #f
                                                      "exclude *= *\\[([^]]|\n)*\\]\n?"
                                                      modified
                                                      'pre
                                                      'post)))
                                      (let* ((lines (string-split modified
                                                                  #\newline))
                                             (in-dev-deps #f)
                                             (filtered (filter (lambda (line)
                                                                 (cond
                                                                   ((string-prefix?
                                                                     "[dev-dependencies]"
                                                                     (string-trim
                                                                      line))
                                                                    (set!
                                                                     in-dev-deps
                                                                     #t) #f)
                                                                   ((and
                                                                     in-dev-deps
                                                                     (string-prefix?
                                                                      "["
                                                                      (string-trim
                                                                       line)))
                                                                    (set!
                                                                     in-dev-deps
                                                                     #f) #t)
                                                                   (in-dev-deps
                                                                    #f)
                                                                   (else #t)))
                                                               lines)))
                                        (display (string-join filtered "\n")
                                                 port))))))))
                          (find-files git-vendor-dir "^Cargo\\.toml$")))))

          ;; Phase 3: Patch Cargo.toml files to convert git deps to path deps
          (add-after 'setup-git-deps 'patch-cargo-toml-git-deps
            (lambda _
              (use-modules (ice-9 textual-ports)
                           (ice-9 regex))
              (let ((git-vendor-dir (string-append (getcwd) "/git-vendor"))
                    (git-mappings '#$%git-mappings))
                (for-each (lambda (cargo-toml)
                            (let ((content (call-with-input-file cargo-toml
                                             get-string-all)))
                              (when (string-contains content
                                     "git = \"https://github.com")
                                (call-with-output-file cargo-toml
                                  (lambda (port)
                                    (let ((modified content))
                                      (for-each (lambda (mapping)
                                                  (let* ((crate-name (car
                                                                      mapping))
                                                         (git-url (cadr
                                                                   mapping))
                                                         (local-dir (caddr
                                                                     mapping))
                                                         (subdir (cadddr
                                                                  mapping))
                                                         (local-path (if (string=?
                                                                          subdir
                                                                          ".")
                                                                         (string-append
                                                                          git-vendor-dir
                                                                          "/"
                                                                          local-dir)
                                                                         (string-append
                                                                          git-vendor-dir
                                                                          "/"
                                                                          local-dir
                                                                          "/"
                                                                          subdir)))
                                                         (git-pattern (string-append
                                                                       "git *= *\""
                                                                       (regexp-quote
                                                                        git-url)
                                                                       "\""))
                                                         (path-replacement (string-append
                                                                            "path = \""
                                                                            local-path
                                                                            "\"")))
                                                    (set! modified
                                                          (regexp-substitute/global
                                                           #f
                                                           git-pattern
                                                           modified
                                                           'pre
                                                           path-replacement
                                                           'post))))
                                                git-mappings)
                                      (set! modified
                                            (regexp-substitute/global #f
                                             ", *branch *= *\"[^\"]+\""
                                             modified
                                             'pre
                                             'post))
                                      (set! modified
                                            (regexp-substitute/global #f
                                             ", *rev *= *\"[^\"]+\"" modified
                                             'pre
                                             'post))
                                      (set! modified
                                            (regexp-substitute/global #f
                                             "\n *branch *= *\"[^\"]+\"[^\n]*"
                                             modified
                                             'pre
                                             'post))
                                      (set! modified
                                            (regexp-substitute/global #f
                                             "\n *rev *= *\"[^\"]+\"[^\n]*"
                                             modified
                                             'pre
                                             'post))
                                      (display modified port)))))))
                          (find-files "." "^Cargo\\.toml$")))))

          ;; Phase 4: Set up cargo config
          (add-after 'patch-cargo-toml-git-deps 'setup-cargo
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((rust-xous (assoc-ref inputs "rust-xous-toolchain"))
                     (riscv-ld (search-input-file inputs
                                                  "/bin/riscv32-none-elf-ld"))
                     (ld-lld (search-input-file inputs "/bin/ld.lld"))
                     (vendor-dir (string-append (getcwd) "/vendor"))
                     (vendor-config (string-append "[source.crates-io]\n"
                                     "replace-with = \"vendored-sources\"\n\n"
                                     "[source.vendored-sources]\n"
                                     "directory = \""
                                     vendor-dir
                                     "\"\n\n"
                                     "[net]\n"
                                     "offline = true\n")))
                (setenv "HOME"
                        (getcwd))
                (setenv "CARGO_HOME"
                        (string-append (getcwd) "/.cargo"))
                (mkdir-p (getenv "CARGO_HOME"))
                (setenv "PATH"
                        (string-append rust-xous "/bin:"
                                       (getenv "PATH")))

                (call-with-output-file ".cargo/config.toml"
                  (lambda (port)
                    (display (string-append
                              "[alias]\n"
                              "xtask = \"run --package xtask --\"\n\n"
                              "[build]\n"
                              "rustflags = [\"--cfg\", \"crossbeam_no_atomic_64\"]\n\n"
                              "[target.riscv32imac-unknown-xous-elf]\n"
                              "linker = \"" ld-lld "\"\n"
                              "rustflags = [\"-C\", \"linker-flavor=ld.lld\", "
                              "\"--cfg\", "
                              "'curve25519_dalek_backend=\"u32e_backend\"']\n\n"
                              "[target.riscv32imac-unknown-none-elf]\n"
                              "linker = \"" riscv-ld "\"\n"
                              "rustflags = [\"-C\", \"linker-flavor=ld\", "
                              "\"--cfg\", 'curve25519_dalek_backend=\"fiat\"']\n\n"
                              vendor-config) port)))

                (mkdir-p "locales/.cargo")
                (call-with-output-file "locales/.cargo/config.toml"
                  (lambda (port)
                    (display vendor-config port))))))

          ;; Phase 5: Build
          (replace 'build
            (lambda* (#:key inputs #:allow-other-keys)
              (setenv "CARGO_INCREMENTAL" "0")
              (setenv "RUSTFLAGS"
                      (string-append "-C codegen-units=1 --remap-path-prefix="
                       (getcwd) "=/build"))
              (invoke "cargo"
                      "xtask"
                      #$@(string-split xtask-cmd #\space)
                      "--no-verify"
                      "--git-describe"
                      #$%xous-git-describe
                      "--git-rev"
                      #$%xous-commit)))

          ;; Phase 6: Install
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (target-path (string-append "target/"
                                                 #$target-dir "/release"))
                     ;; Package name is the first word of xtask-cmd
                     (pkg-name #$(car (string-split xtask-cmd #\space)))
                     ;; ELF binary name from mapping (see %elf-binary-names)
                     (elf-name #$(assoc-ref %elf-binary-names
                                            (car (string-split xtask-cmd
                                                               #\space))))
                     (elf-path (string-append target-path "/" elf-name)))
                (mkdir-p out)
                ;; Copy firmware images (.uf2, .img, .bin)
                (for-each (lambda (pattern)
                            (for-each (lambda (file)
                                        (copy-file file
                                                   (string-append out "/"
                                                                  (basename
                                                                   file))))
                                      (find-files target-path pattern)))
                          '("\\.uf2$" "\\.img$" "\\.bin$"))
                ;; Copy raw ELF file for debugging/analysis
                (when (file-exists? elf-path)
                  (copy-file elf-path
                             (string-append out "/" pkg-name ".elf")))))))))
    (native-inputs `(("rust-xous-toolchain" ,rust-xous-toolchain)
                     ;; lld-18 & cross-binutils are propagated from xous sysroots
                     ("git" ,git)
                     ("tar" ,tar)
                     ("gzip" ,gzip)
                     ("coreutils" ,coreutils)
                     ;; Add all crates as inputs
                     ,@(map (lambda (crate)
                              `(,(string-append "crate-"
                                                (origin-file-name crate)) ,crate))
                            crate-inputs)
                     ;; Add git dependency inputs
                     ,@(map (lambda (dep)
                              `(,(git-dependency-name dep) ,(git-dependency-origin
                                                             dep)))
                            %git-dependencies)))
    (home-page "https://github.com/betrusted-io/xous-core")
    (synopsis (string-append "Xous " name " firmware (production)"))
    (description (string-append "Production Xous firmware build for "
                                name
                                " target.  "
                                "Built from xous-core commit "
                                %xous-short-hash
                                ".  "
                                "Built with xtask command: "
                                xtask-cmd
                                "."))
    (license license:asl2.0)))

;;; =============================================================
;;; BUILD TARGETS
;;; =============================================================

(define-public bao1x-boot0
  (make-firmware-build "bao1x-boot0"
                       "bao1x-boot0"
                       #:target-dir "riscv32imac-unknown-none-elf"
                       #:crate-inputs (lookup-cargo-inputs 'bao1x-boot0)))

(define-public bao1x-boot1
  (make-firmware-build "bao1x-boot1"
                       "bao1x-boot1"
                       #:target-dir "riscv32imac-unknown-none-elf"
                       #:crate-inputs (lookup-cargo-inputs 'bao1x-boot1)))

(define-public bao1x-alt-boot1
  (make-firmware-build "bao1x-alt-boot1"
                       "bao1x-alt-boot1"
                       #:target-dir "riscv32imac-unknown-none-elf"
                       #:crate-inputs (lookup-cargo-inputs 'bao1x-alt-boot1)))

(define-public bao1x-baremetal-dabao
  (make-firmware-build "bao1x-baremetal-dabao"
                       "bao1x-baremetal-dabao"
                       #:target-dir "riscv32imac-unknown-none-elf"
                       #:crate-inputs (lookup-cargo-inputs 'bao1x-baremetal-dabao)))

(define-public dabao
  (make-firmware-build "dabao"
                       "dabao"
                       #:target-dir "riscv32imac-unknown-xous-elf"
                       #:crate-inputs (lookup-cargo-inputs 'dabao)))

(define-public dabao-helloworld
  (make-firmware-build "dabao-helloworld"
                       "dabao helloworld"
                       #:target-dir "riscv32imac-unknown-xous-elf"
                       #:crate-inputs (lookup-cargo-inputs 'dabao-helloworld)))

(define-public baosec
  (make-firmware-build "baosec"
                       "baosec"
                       #:target-dir "riscv32imac-unknown-xous-elf"
                       #:crate-inputs (lookup-cargo-inputs 'baosec)))

;;; Combined bootloader package
(define-public bao1x-bootloader
  (package
    (name "bao1x-bootloader")
    (version %xous-git-describe)
    (source
     #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let ((out (assoc-ref %outputs "out"))
                (boot0 #$(this-package-input "bao1x-boot0"))
                (boot1 #$(this-package-input "bao1x-boot1"))
                (alt-boot1 #$(this-package-input "bao1x-alt-boot1")))
            (mkdir-p out)
            (for-each (lambda (src)
                        (for-each (lambda (file)
                                    (copy-file file
                                               (string-append out "/"
                                                              (basename file))))
                                  (find-files src "\\.(uf2|img|bin)$")))
                      (list boot0 boot1 alt-boot1))))))
    (inputs `(("bao1x-boot0" ,bao1x-boot0)
              ("bao1x-boot1" ,bao1x-boot1)
              ("bao1x-alt-boot1" ,bao1x-alt-boot1)))
    (home-page "https://github.com/betrusted-io/xous-core")
    (synopsis "Combined bootloader package for bao1x")
    (description (string-append "Bootloader package containing boot0, boot1, "
                  "and alt-boot1 for bao1x hardware.  "
                  "Built from xous-core commit " %xous-short-hash "."))
    (license license:asl2.0)))

;; Default export
dabao
