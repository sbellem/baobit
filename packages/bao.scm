;;; GNU Guix package definitions for production Xous firmware builds
;;;
;;; This module provides packages for building Xous firmware images
;;; using git-fetch for reproducible builds across machines.
;;;
;;; IMPORTANT: When updating xous-core version, edit xous-config.scm

(define-module (bao)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system cargo)
  #:use-module (guix build-system trivial)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:)
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

(define %xous-short-hash
  (substring %xous-commit 0 8))

;;; =============================================================
;;; ELF BINARY NAMES
;;; =============================================================
;;; Maps xtask command to ELF binary name produced by cargo.
;;; alt-boot1 uses bao1x-boot1 binary (substituted by xtask).

(define %elf-binary-names
  '(("bao1x-boot0" . "bao1x-boot0") ("bao1x-boot1" . "bao1x-boot1")
    ("bao1x-boot1-lite" . "bao1x-boot1")
    ("bao1x-alt-boot1" . "bao1x-boot1")
    ("bao1x-alt-boot1-lite" . "bao1x-boot1")
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

;;; =============================================================
;;; GIT-DEP REWRITE TABLE
;;; =============================================================
;;; Maps each xous-core git dependency URL to (vendor-prefix . subpath).
;;; - url-substring: substring of the git URL that uniquely identifies the
;;;   dep (matched against `git = "..."` values in Cargo.toml files).
;;; - vendor-prefix: directory under guix-vendor/ matches
;;;   "^rust-<prefix>-.*-checkout$" (the cargo-build-system unpacks each
;;;   git origin under that name).
;;; - subpath: subdir within the checkout for multi-crate repos, "" for root.
;;;
;;; The patch-cargo-git-deps phase rewrites each `git = "URL"` reference
;;; in any Cargo.toml to `path = "<absolute>/guix-vendor/rust-<prefix>-<ver>-checkout/<subpath>"`
;;; and strips trailing branch=/rev= qualifiers.  This works for inline
;;; (`name = { git = ... }`), section (`[dependencies.name]\ngit = ...`),
;;; and [patch.crates-io.X] forms uniformly.
;;;
;;; Multi-crate repos (atsama5d27 hosts atsama5d27+utralib; curve25519-dalek
;;; hosts curve25519-dalek+curve25519-dalek-derive; hashes hosts sha2) only
;;; need the primary crate's URL entry: the secondary crates are pulled in
;;; via relative-path deps WITHIN the primary crate's vendored checkout.

(define %git-deps
  ;; (url-substring vendor-prefix subpath)
  '(("Foundation-Devices/armv7"           "armv7"            "")
    ("Foundation-Devices/atsama5d27"      "atsama5d27"       "")
    ("betrusted-io/com_rs"                "com-rs"           "")
    ("betrusted-io/curve25519-dalek"      "curve25519-dalek" "curve25519-dalek")
    ("betrusted-io/xous-engine-25519"     "engine-25519"     "")
    ("betrusted-io/engine25519-as"        "engine25519-as"   "")
    ("betrusted-io/ring-xous"             "ring"             "")
    ("betrusted-io/rqrr"                  "rqrr"             "")
    ("betrusted-io/hashes"                "sha2"             "sha2")
    ("betrusted-io/simple-fatfs"          "simple-fatfs"     "")
    ("betrusted-io/usb-device"            "usb-device"       "")
    ("betrusted-io/usbd-serial"           "usbd-serial"      "")
    ("betrusted-io/xous-usb-hid"          "xous-usb-hid"     "")))

;;; =============================================================
;;; Helper to create firmware build packages
;;; =============================================================

(define* (make-firmware-build name xtask-cmd
                              #:key (target-dir "riscv32imac-unknown-none-elf"))
  (package
    (name name)
    (version %xous-git-describe)
    (source xous-core-source)
    (build-system cargo-build-system)
    (arguments
     (list
      #:tests? #f
      #:skip-build? #t  ;custom build phase calls `cargo xtask`, not `cargo build`
      #:install-source? #f
      #:vendor-dir "guix-vendor"
      #:phases
      #~(modify-phases %standard-phases
          ;; Don't run upstream's check-for-pregenerated-files: it walks the
          ;; entire source tree (including the unpacked vendor dir) and trips
          ;; on the many pre-built artefacts vendored crates ship.
          (delete 'check-for-pregenerated-files)

          ;; Upstream's patch-cargo-checksums writes `{"files":{}}` stubs.
          ;; That's enough when Cargo.lock is deleted (and cargo regenerates
          ;; resolution from scratch).  We KEEP the lockfile to preserve
          ;; xous-core's pinning, which means cargo validates each crate's
          ;; checksum against the lockfile's "checksum = " field.  Without a
          ;; "package" field in .cargo-checksum.json, cargo errors with
          ;; "could not be calculated".  Replace the stub generation: for
          ;; tarball-derived vendor dirs, write the tarball's sha256 hex
          ;; as the "package" field; for git checkouts (no lockfile checksum
          ;; expected), the {"files":{}} stub stays adequate.
          (replace 'patch-cargo-checksums
            (lambda* (#:key inputs #:allow-other-keys)
              (use-modules (ice-9 popen)
                           (ice-9 rdelim))
              (define (tarball-sha256 path)
                (let* ((port (open-pipe* OPEN_READ "sha256sum" path))
                       (line (read-line port)))
                  (close-pipe port)
                  (car (string-split line #\space))))
              (let ((vendor     (string-append (getcwd) "/guix-vendor"))
                    (git-vendor (string-append (getcwd) "/git-vendor")))
                (for-each
                 (lambda (input)
                   (let ((name (car input))
                         (path (cdr input)))
                     (when (and (string-prefix? "rust-" name)
                                (string-suffix? ".tar.gz" path)
                                (file-exists? path))
                       (let* ((basepath (strip-store-file-name path))
                              (crate-dir (string-append vendor "/" basepath))
                              (stub (string-append crate-dir
                                                   "/.cargo-checksum.json")))
                         (when (file-exists? crate-dir)
                           (call-with-output-file stub
                             (lambda (port)
                               (format port
                                       "{\"files\":{},\"package\":\"~a\"}"
                                       (tarball-sha256 path)))))))))
                 inputs)
                ;; Git checkouts live in git-vendor/ (moved there by
                ;; move-git-checkouts so they don't shadow same-named
                ;; crates.io tarballs in the cargo directory source).  They
                ;; are consumed as path deps, which don't strictly need a
                ;; checksum file, but the stub keeps the tree uniform.
                (for-each
                 (lambda (entry)
                   (let* ((dir (string-append git-vendor "/" entry))
                          (stub (string-append dir "/.cargo-checksum.json")))
                     (when (and (string-suffix? "-checkout" entry)
                                (file-exists? dir)
                                (not (file-exists? stub)))
                       (call-with-output-file stub
                         (lambda (port)
                           (display "{\"files\":{}}" port))))))
                 (or (scandir git-vendor) '())))))

          ;; Upstream's unpack-rust-crates uses crate-src? to filter inputs,
          ;; which requires each git checkout's root Cargo.toml to contain a
          ;; [package] section.  Several of our git deps host multiple
          ;; workspace members with no root package (e.g. betrusted-io/
          ;; curve25519-dalek, betrusted-io/hashes) and get silently dropped.
          ;; Copy those in too.
          (add-after 'unpack-rust-crates 'unpack-rust-workspaces
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((vendor (string-append (getcwd) "/guix-vendor")))
                (for-each
                 (lambda (input)
                   (let ((name (car input))
                         (path (cdr input)))
                     ;; Filter: rust-NAME-VERSION-checkout sources only,
                     ;; not toolchains (rust-xous-toolchain) or sysroots
                     ;; (rust-sysroot-*).
                     (when (and (string-prefix? "rust-" name)
                                (string-suffix? "-checkout" name)
                                (directory-exists? path)
                                (file-exists? (string-append path
                                                             "/Cargo.toml")))
                       (let ((dest (string-append vendor "/"
                                                  (strip-store-file-name path))))
                         (unless (file-exists? dest)
                           (format #t "Copying workspace crate ~a~%" name)
                           (copy-recursively path dest))))))
                 inputs))))

          ;; Vendored git checkouts that ship as workspaces (e.g.
          ;; betrusted-io/curve25519-dalek, Foundation-Devices/atsama5d27)
          ;; trip cargo's "multiple workspace roots" check.  Two cases:
          ;;
          ;; - Root has both [workspace] and [package] (atsama5d27, ring,
          ;;   engine25519-as): we path-dep to root, so it must look like
          ;;   a standalone package.  Strip [workspace] entirely.
          ;;
          ;; - Root has only [workspace], no [package] (curve25519-dalek,
          ;;   hashes/sha2): we path-dep to a subdir whose Cargo.toml has
          ;;   only [package].  Keep [workspace] (empty) at root so cargo's
          ;;   walk-up finds a workspace boundary instead of escaping into
          ;;   xous-core's workspace.
          ;;
          ;; In both cases also strip members/exclude lists, which reference
          ;; sibling crates that may or may not be present in the vendor copy.
          ;; Crates.io tarballs never ship [workspace], so this only affects
          ;; -checkout directories.
          (add-after 'unpack-rust-workspaces 'strip-vendor-workspaces
            (lambda _
              (use-modules (ice-9 textual-ports)
                           (ice-9 regex)
                           (ice-9 ftw))
              ;; Strip [dev-dependencies] sections from a TOML string.
              ;; Multi-line — section ends at next `[...]` header or EOF.
              ;; dev-deps typically list crates we never vendor (test-only).
              (define (strip-dev-dependencies content)
                (let loop ((lines (string-split content #\newline))
                           (in-dev #f)
                           (acc '()))
                  (cond
                   ((null? lines)
                    (string-join (reverse acc) "\n"))
                   ((string-prefix? "[dev-dependencies]"
                                    (string-trim (car lines)))
                    (loop (cdr lines) #t acc))
                   ((and in-dev
                         (string-prefix? "[" (string-trim (car lines))))
                    (loop (cdr lines) #f (cons (car lines) acc)))
                   (in-dev
                    (loop (cdr lines) #t acc))
                   (else
                    (loop (cdr lines) #f (cons (car lines) acc))))))
              (let* ((vendor (string-append (getcwd) "/guix-vendor"))
                     (entries (or (scandir vendor) '())))
                ;; Pass 1: strip [dev-dependencies] from every Cargo.toml in
                ;; every -checkout vendor dir.  dev-deps reference crates
                ;; we never vendor (test-only); leaving them in causes cargo
                ;; offline resolution to fail (e.g. usb-device → rand 0.6.1).
                (for-each
                 (lambda (entry)
                   (let ((checkout (string-append vendor "/" entry)))
                     (when (string-suffix? "-checkout" entry)
                       (for-each
                        (lambda (f)
                          (chmod f #o644)
                          (let ((content (call-with-input-file f get-string-all)))
                            (when (string-contains content "[dev-dependencies]")
                              (call-with-output-file f
                                (lambda (port)
                                  (display (strip-dev-dependencies content)
                                           port))))))
                        (find-files checkout "^Cargo\\.toml$")))))
                 entries)
                ;; Pass 2: handle [workspace] at each -checkout root.
                (for-each
                 (lambda (entry)
                   (let ((cargo-toml (string-append vendor "/" entry
                                                    "/Cargo.toml")))
                     (when (and (string-suffix? "-checkout" entry)
                                (file-exists? cargo-toml))
                       (let* ((content (call-with-input-file cargo-toml
                                         get-string-all))
                              (has-workspace?
                               (string-contains content "[workspace]"))
                              (has-package?
                               (or (string-prefix? "[package]" content)
                                   (string-contains content "\n[package]"))))
                         (cond
                          ;; Root has both [workspace] and [package]: this is
                          ;; a single-package workspace.  Strip [workspace]
                          ;; (with its members/exclude) so cargo sees a plain
                          ;; package.  Our path-dep targets the root.
                          ((and has-workspace? has-package?)
                           (call-with-output-file cargo-toml
                             (lambda (port)
                               (let* ((m content)
                                      (m (regexp-substitute/global
                                          #f
                                          "members *= *\\[([^]]|\n)*\\]\n?"
                                          m 'pre 'post))
                                      (m (regexp-substitute/global
                                          #f
                                          "exclude *= *\\[([^]]|\n)*\\]\n?"
                                          m 'pre 'post))
                                      (m (regexp-substitute/global
                                          #f "\\[workspace\\]\n?" m
                                          'pre 'post)))
                                 (display m port)))))
                          ;; Root has [workspace] but no [package]: virtual
                          ;; manifest.  Cargo's vendored-sources scanner
                          ;; errors on virtual manifests, so delete the file.
                          ;; Our path-deps target subdirs (sha2/, etc.)
                          ;; directly; cargo's walk-up from the path-dep will
                          ;; escape to xous-core's workspace, which doesn't
                          ;; claim these vendor dirs.
                          (has-workspace?
                           (delete-file cargo-toml)))))))
                 entries))))

          ;; Move every git checkout out of guix-vendor/ (the cargo directory
          ;; source) into a sibling git-vendor/.  Git-forked crates are
          ;; consumed via git=→path= rewrites (patch-cargo-git-deps), so they
          ;; never need to be served by the directory source.  Leaving them in
          ;; guix-vendor is actively harmful: a checkout and a crates.io
          ;; tarball can declare the SAME package-id (e.g. usbd-serial 0.1.1,
          ;; pulled both as the betrusted git fork by usb-bao1x and from
          ;; crates.io by usb-device-xous).  The directory source then indexes
          ;; both under one id and non-deterministically serves the checkout
          ;; (a {"files":{}} stub with no "package" field) for the registry
          ;; consumer, which fails with "checksum ... could not be calculated,
          ;; but a checksum is listed in the existing lock file".  Keeping
          ;; checkouts in a separate tree leaves the directory source holding
          ;; only crates.io tarballs, one per id.
          (add-after 'strip-vendor-workspaces 'move-git-checkouts
            (lambda _
              (let ((vendor     (string-append (getcwd) "/guix-vendor"))
                    (git-vendor (string-append (getcwd) "/git-vendor")))
                (mkdir-p git-vendor)
                (for-each
                 (lambda (entry)
                   (when (string-suffix? "-checkout" entry)
                     (let ((src (string-append vendor "/" entry))
                           (dst (string-append git-vendor "/" entry)))
                       (when (file-exists? src)
                         ;; A pre-existing dst means two checkouts resolved
                         ;; to the same target name: fail loud instead of
                         ;; silently picking a winner.
                         (when (file-exists? dst)
                           (error "move-git-checkouts: destination exists" dst))
                         (rename-file src dst)))))
                 (or (scandir vendor) '()))
                ;; Invariant: guix-vendor (the cargo directory source) must
                ;; hold NO git checkouts afterwards.  A leftover -checkout
                ;; shares the cargo index with same-id crates.io tarballs and
                ;; is served non-deterministically (the boot0 CI failure that
                ;; this split exists to prevent).  Assert it loudly.
                (let ((leftover
                       (filter (lambda (e) (string-suffix? "-checkout" e))
                               (or (scandir vendor) '()))))
                  (unless (null? leftover)
                    (error "move-git-checkouts: checkouts remain in guix-vendor"
                           leftover))))))

          ;; cargo-build-system's configure deletes Cargo.lock; we want to
          ;; preserve xous-core's lockfile pinning, so replace configure
          ;; entirely.
          (replace 'configure
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((rust-xous   (assoc-ref inputs "rust-xous-toolchain"))
                     (riscv-ld    (search-input-file inputs "/bin/riscv32-none-elf-ld"))
                     (ld-lld      (search-input-file inputs "/bin/ld.lld"))
                     (vendor-dir  (string-append (getcwd) "/guix-vendor"))
                     (vendor-config
                      (string-append "[source.crates-io]\n"
                                     "replace-with = \"vendored-sources\"\n\n"
                                     "[source.vendored-sources]\n"
                                     "directory = \"" vendor-dir "\"\n\n"
                                     "[net]\n"
                                     "offline = true\n")))
                (setenv "HOME" (getcwd))
                (setenv "CARGO_HOME" (string-append (getcwd) "/.cargo"))
                (mkdir-p (getenv "CARGO_HOME"))
                (setenv "PATH" (string-append rust-xous "/bin:" (getenv "PATH")))

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

          ;; Rewrite every `git = "..."` reference in Cargo.toml files to
          ;; `path = "<git-vendor>/rust-NAME-VERSION-checkout[/subpath]"`,
          ;; and strip trailing branch=/rev= qualifiers.  Runs after
          ;; move-git-checkouts so git-vendor/ holds the checkouts.
          (add-after 'configure 'patch-cargo-git-deps
            (lambda _
              (use-modules (ice-9 textual-ports)
                           (ice-9 regex)
                           (ice-9 ftw))
              (let* ((git-vendor (string-append (getcwd) "/git-vendor"))
                     (vendor-entries (or (scandir git-vendor) '()))
                     (resolve
                      (lambda (prefix subpath)
                        (let* ((re (make-regexp
                                    (string-append "^rust-" (regexp-quote prefix)
                                                   "-[0-9].*-checkout$")))
                               (matches (filter (lambda (e) (regexp-exec re e))
                                                vendor-entries)))
                          (when (null? matches)
                            (error "no vendor dir for prefix" prefix))
                          (unless (= 1 (length matches))
                            (error "ambiguous vendor dir for prefix" prefix matches))
                          (let ((base (string-append git-vendor "/" (car matches))))
                            (if (string=? subpath "")
                                base
                                (string-append base "/" subpath)))))))
                (for-each
                 (lambda (cargo-toml)
                   (let ((content (call-with-input-file cargo-toml get-string-all)))
                     ;; Only rewrite files that actually reference a github git dep.
                     (when (string-contains content "git = \"https://github.com")
                       ;; Vendor Cargo.toml files are read-only (copied from
                       ;; the store).  Restore write so we can rewrite them.
                       (chmod cargo-toml #o644)
                       (call-with-output-file cargo-toml
                         (lambda (port)
                           (let ((modified content))
                             ;; URL-keyed git→path rewrite.  Covers inline
                             ;; (`name = { git = "URL", ... }`), section
                             ;; (`[deps.name]\ngit = "URL"`), and
                             ;; [patch.crates-io.X] forms uniformly — they
                             ;; all share the `git = "URL"` token.
                             (for-each
                              (lambda (entry)
                                (let* ((url-substr (car entry))
                                       (prefix    (cadr entry))
                                       (subpath   (caddr entry))
                                       (path      (resolve prefix subpath))
                                       (replacement
                                        (string-append "path = \"" path "\"")))
                                  (set! modified
                                        (regexp-substitute/global
                                         #f
                                         (string-append
                                          "git *= *\"https://github\\.com/"
                                          (regexp-quote url-substr)
                                          "(\\.git)?\"")
                                         modified
                                         'pre replacement 'post))))
                              '#$%git-deps)
                             ;; Strip `, branch = "..."` and `, rev = "..."`
                             ;; that trailed the git=... we just replaced (inline).
                             (set! modified
                                   (regexp-substitute/global
                                    #f ", *branch *= *\"[^\"]+\""
                                    modified 'pre 'post))
                             (set! modified
                                   (regexp-substitute/global
                                    #f ", *rev *= *\"[^\"]+\""
                                    modified 'pre 'post))
                             ;; Strip standalone branch/rev lines (section form).
                             (set! modified
                                   (regexp-substitute/global
                                    #f "\n *branch *= *\"[^\"]+\"[^\n]*"
                                    modified 'pre 'post))
                             (set! modified
                                   (regexp-substitute/global
                                    #f "\n *rev *= *\"[^\"]+\"[^\n]*"
                                    modified 'pre 'post))
                             (display modified port)))))))
                 (find-files "." "^Cargo\\.toml$")))))

          ;; Custom build: invoke xous-core's xtask driver instead of
          ;; `cargo build`.
          (replace 'build
            (lambda* (#:key inputs #:allow-other-keys)
              (setenv "CARGO_INCREMENTAL" "0")
              (setenv "RUSTFLAGS"
                      (string-append "-C codegen-units=1 --remap-path-prefix="
                                     (getcwd) "=/build"))
              (invoke "cargo" "xtask"
                      #$@(string-split xtask-cmd #\space)
                      "--no-verify"
                      "--git-describe" #$%xous-git-describe
                      "--git-rev"      #$%xous-commit)))

          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (target-path (string-append "target/" #$target-dir "/release"))
                     (pkg-name #$(car (string-split xtask-cmd #\space)))
                     (elf-name #$(assoc-ref %elf-binary-names
                                            (car (string-split xtask-cmd #\space))))
                     (elf-path (string-append target-path "/" elf-name)))
                (mkdir-p out)
                (for-each (lambda (pattern)
                            (for-each (lambda (file)
                                        (copy-file file
                                                   (string-append out "/"
                                                                  (basename file))))
                                      (find-files target-path pattern)))
                          '("\\.uf2$" "\\.img$" "\\.bin$"))
                (when (file-exists? elf-path)
                  (copy-file elf-path
                             (string-append out "/" pkg-name ".elf")))))))))
    (native-inputs `(("rust-xous-toolchain" ,rust-xous-toolchain)
                     ;; lld-18 & cross-binutils are propagated from xous sysroots
                     ("git" ,git)
                     ("tar" ,tar)
                     ("gzip" ,gzip)
                     ("coreutils" ,coreutils)))
    (inputs (append (lookup-cargo-inputs 'xous-core)
                    (lookup-cargo-inputs 'locales)))
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
                       #:target-dir "riscv32imac-unknown-none-elf"))

(define-public bao1x-boot1
  (make-firmware-build "bao1x-boot1"
                       "bao1x-boot1"
                       #:target-dir "riscv32imac-unknown-none-elf"))

(define-public bao1x-boot1-lite
  (make-firmware-build "bao1x-boot1-lite"
                       "bao1x-boot1-lite"
                       #:target-dir "riscv32imac-unknown-none-elf"
                       #:crate-inputs (lookup-cargo-inputs 'bao1x-boot1-lite)))

(define-public bao1x-alt-boot1
  (make-firmware-build "bao1x-alt-boot1"
                       "bao1x-alt-boot1"
                       #:target-dir "riscv32imac-unknown-none-elf"))

(define-public bao1x-alt-boot1-lite
  (make-firmware-build "bao1x-alt-boot1-lite"
                       "bao1x-alt-boot1-lite"
                       #:target-dir "riscv32imac-unknown-none-elf"
                       #:crate-inputs (lookup-cargo-inputs 'bao1x-alt-boot1-lite)))

(define-public bao1x-baremetal-dabao
  (make-firmware-build "bao1x-baremetal-dabao"
                       "bao1x-baremetal-dabao"
                       #:target-dir "riscv32imac-unknown-none-elf"))

(define-public dabao
  (make-firmware-build "dabao"
                       "dabao"
                       #:target-dir "riscv32imac-unknown-xous-elf"))

(define-public dabao-helloworld
  (make-firmware-build "dabao-helloworld"
                       "dabao helloworld"
                       #:target-dir "riscv32imac-unknown-xous-elf"))

(define-public baosec
  (make-firmware-build "baosec"
                       "baosec"
                       #:target-dir "riscv32imac-unknown-xous-elf"))

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
