;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2024 Gluonix contributors
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

(define-module (rust)
  #:use-module (gnu packages rust)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (guix utils)
  #:use-module (guix platform)
  #:use-module ((guix licenses) #:prefix license:))

;;; Commentary:
;;;
;;; Rust 1.91, 1.92, 1.93 packages extending rust-team's rust-1.90.
;;; This channel provides newer Rust versions until they land upstream.
;;;
;;; Code:

;; Helper function to create bootstrapped rust packages
(define* (rust-bootstrapped-package base-rust version checksum)
  "Bootstrap rust VERSION with source checksum CHECKSUM using BASE-RUST."
  (package
    (inherit base-rust)
    (version version)
    (source
     (origin
       (inherit (package-source base-rust))
       (uri (string-append "https://static.rust-lang.org/dist/"
                           "rustc-" version "-src.tar.gz"))
       (sha256 (base32 checksum))))
    (native-inputs
     (modify-inputs (package-native-inputs base-rust)
       (replace "rustc-bootstrap" base-rust)
       (replace "cargo-bootstrap" (list base-rust "cargo"))))))

(define-public rust-1.91
  (let ((base-rust
         (rust-bootstrapped-package
          rust-1.90 "1.91.0"
          "12iysk87bmhlcdcbr939y8cdfcx0an4z9ixjlbq16c3ma60m4zrj")))
    (package
      (inherit base-rust)
      (source
       (origin
         (inherit (package-source base-rust))
         (snippet
          '(begin
             (for-each delete-file-recursively
                       '("src/llvm-project"
                         "vendor/curl-sys-0.4.79+curl-8.12.0/curl"
                         "vendor/curl-sys-0.4.83+curl-8.15.0/curl"
                         "vendor/jemalloc-sys-0.5.3+5.3.0-patched/jemalloc"
                         "vendor/jemalloc-sys-0.5.4+5.3.0-patched/jemalloc"
                         "vendor/libffi-sys-3.3.2/libffi"
                         "vendor/libz-sys-1.1.21/src/zlib"
                         "vendor/libz-sys-1.1.22/src/zlib"
                         "vendor/libmimalloc-sys-0.1.42/c_src/mimalloc"
                         "vendor/openssl-src-111.28.2+1.1.1w/openssl"
                         "vendor/openssl-src-300.5.0+3.5.0/openssl"
                         "vendor/openssl-src-300.5.2+3.5.2/openssl"
                         "vendor/tikv-jemalloc-sys-0.5.4+5.3.0-patched/jemalloc"
                         "vendor/tikv-jemalloc-sys-0.6.0+5.3.0-1-\
ge13ca993e8ccb9ba9847cc330696e02839f328f7/jemalloc"))
             ;; Remove vendored dynamically linked libraries.
             (for-each delete-file
                       (find-files "vendor" "\\.(a|dll|exe|lib)$"))
             ;; Use the packaged nghttp2.
             (for-each
              (lambda (ver)
                (let ((vendored-dir
                       (format #f "vendor/libnghttp2-sys-~a/nghttp2" ver))
                      (build-rs
                       (format #f "vendor/libnghttp2-sys-~a/build.rs" ver)))
                  (delete-file-recursively vendored-dir)
                  (delete-file build-rs)
                  (call-with-output-file build-rs
                    (lambda (port)
                      (format port "fn main() {~@
                         println!(\"cargo:rustc-link-lib=nghttp2\");~@
                         }~%")))))
              '("0.1.11+1.64.0"))
             ;; Adjust vendored dependency to explicitly use rustix with libc
             ;; backend.
             (substitute* '("vendor/tempfile-3.14.0/Cargo.toml"
                            "vendor/tempfile-3.16.0/Cargo.toml"
                            "vendor/tempfile-3.19.1/Cargo.toml"
                            "vendor/tempfile-3.20.0/Cargo.toml"
                            "vendor/tempfile-3.21.0/Cargo.toml")
               (("features = \\[\"fs\"" all)
                (string-append all ", \"use-libc\"")))))))
      (arguments
       (substitute-keyword-arguments (package-arguments base-rust)
         ((#:phases phases)
	    #~(modify-phases #$phases
              ;; it errored out while compiling due to rustc stack size
	      (add-before 'build 'set-stack-size
                (lambda _
                  (setenv "RUST_MIN_STACK" "16777216")))
              (replace 'install
                ;; Rust 1.91+ outputs to stage2 instead of stage1.
                ;; Cannot use './x.py install' as it runs generate-copyright
                ;; which fails due to patched cargo checksums.
                (lambda* (#:key outputs #:allow-other-keys)
                  (let* ((out (assoc-ref outputs "out"))
                         (cargo-out (assoc-ref outputs "cargo"))
                         (build (string-append "build/"
                                  #$(platform-rust-target
                                     (lookup-platform-by-target-or-system
                                      (or (%current-target-system)
                                          (%current-system)))))))
                    (with-directory-excursion build
                      (install-file "stage2/bin/rustc"
                                    (string-append out "/bin"))
                      (install-file "stage2-tools-bin/cargo"
                                    (string-append cargo-out "/bin"))
                      (for-each delete-file
                                (find-files "stage2/lib" "\\.rmeta$"))
                      (for-each delete-file
                                (find-files "stage2/lib/rustlib"
                                            "^librustc_driver.*\\.so$"))
                      (copy-recursively "stage2/lib"
                                        (string-append out "/lib")))))))))))))

(define-public rust-1.92
  (let ((base-rust
         (rust-bootstrapped-package
          rust-1.91 "1.92.0"
          "1f6305lkp4vwj132fq232mfxdcxg0d5vymc2fpf5y9vybjkjq3cy")))
    (package
      (inherit base-rust)
      (source
       (origin
         (inherit (package-source base-rust))
         (snippet
          '(begin
             ;; Delete directories only if they exist
             (for-each (lambda (dir)
                         (when (file-exists? dir)
                           (delete-file-recursively dir)))
                       '("src/llvm-project"
                         "vendor/curl-sys-0.4.79+curl-8.12.0/curl"
                         "vendor/curl-sys-0.4.83+curl-8.15.0/curl"
                         "vendor/jemalloc-sys-0.5.3+5.3.0-patched/jemalloc"
                         "vendor/jemalloc-sys-0.5.4+5.3.0-patched/jemalloc"
                         "vendor/libffi-sys-4.0.0/libffi"
                         "vendor/libz-sys-1.1.21/src/zlib"
                         "vendor/libz-sys-1.1.22/src/zlib"
                         "vendor/libmimalloc-sys-0.1.44/c_src/mimalloc"
                         "vendor/openssl-src-111.28.2+1.1.1w/openssl"
                         "vendor/openssl-src-300.5.0+3.5.0/openssl"
                         "vendor/openssl-src-300.5.3+3.5.4/openssl"
                         "vendor/tikv-jemalloc-sys-0.5.4+5.3.0-patched/jemalloc"
                         "vendor/tikv-jemalloc-sys-0.6.0+5.3.0-1-\
ge13ca993e8ccb9ba9847cc330696e02839f328f7/jemalloc"))
             ;; Remove vendored dynamically linked libraries.
             (for-each delete-file
                       (find-files "vendor" "\\.(a|dll|exe|lib)$"))
             ;; Use the packaged nghttp2.
             (for-each
              (lambda (ver)
                (let ((vendored-dir
                       (format #f "vendor/libnghttp2-sys-~a/nghttp2" ver))
                      (build-rs
                       (format #f "vendor/libnghttp2-sys-~a/build.rs" ver)))
                  (when (file-exists? vendored-dir)
                    (delete-file-recursively vendored-dir))
                  (when (file-exists? build-rs)
                    (delete-file build-rs)
                    (call-with-output-file build-rs
                      (lambda (port)
                        (format port "fn main() {~@
                           println!(\"cargo:rustc-link-lib=nghttp2\");~@
                           }~%"))))))
              '("0.1.11+1.64.0"))
             ;; Adjust vendored dependency to explicitly use rustix with libc
             ;; backend.
             (for-each
              (lambda (toml)
                (when (file-exists? toml)
                  (substitute* toml
                    (("features = \\[\"fs\"" all)
                     (string-append all ", \"use-libc\"")))))
              '("vendor/tempfile-3.14.0/Cargo.toml"
                "vendor/tempfile-3.16.0/Cargo.toml"
                "vendor/tempfile-3.19.1/Cargo.toml"
                "vendor/tempfile-3.20.0/Cargo.toml"
                "vendor/tempfile-3.21.0/Cargo.toml"
                "vendor/tempfile-3.23.0/Cargo.toml")))))))))

(define-public rust-1.93
  (let ((base-rust
         (rust-bootstrapped-package
          rust-1.92 "1.93.0"
          "01d7a1mvyvqmq9khyw5cbnwyngzgb4pxpdwhqgzl669j7kc2n4b9")))
    (package
      (inherit base-rust)
      (source
       (origin
         (inherit (package-source base-rust))
         (snippet
          '(begin
             ;; Delete directories only if they exist
             (for-each (lambda (dir)
                         (when (file-exists? dir)
                           (delete-file-recursively dir)))
                       '("src/llvm-project"
                         "vendor/curl-sys-0.4.79+curl-8.12.0/curl"
                         "vendor/curl-sys-0.4.83+curl-8.15.0/curl"
                         "vendor/curl-sys-0.4.84+curl-8.17.0/curl"
                         "vendor/jemalloc-sys-0.5.3+5.3.0-patched/jemalloc"
                         "vendor/jemalloc-sys-0.5.4+5.3.0-patched/jemalloc"
                         "vendor/libffi-sys-4.0.0/libffi"
                         "vendor/libz-sys-1.1.21/src/zlib"
                         "vendor/libz-sys-1.1.22/src/zlib"
                         "vendor/libmimalloc-sys-0.1.44/c_src/mimalloc"
                         "vendor/openssl-src-111.28.2+1.1.1w/openssl"
                         "vendor/openssl-src-300.5.0+3.5.0/openssl"
                         "vendor/openssl-src-300.5.2+3.5.4/openssl"
                         "vendor/tikv-jemalloc-sys-0.5.4+5.3.0-patched/jemalloc"
                         "vendor/tikv-jemalloc-sys-0.6.0+5.3.0-1-\
ge13ca993e8ccb9ba9847cc330696e02839f328f7/jemalloc"))
             ;; Remove vendored dynamically linked libraries.
             (for-each delete-file
                       (find-files "vendor" "\\.(a|dll|exe|lib)$"))
             ;; Use the packaged nghttp2.
             (for-each
              (lambda (ver)
                (let ((vendored-dir
                       (format #f "vendor/libnghttp2-sys-~a/nghttp2" ver))
                      (build-rs
                       (format #f "vendor/libnghttp2-sys-~a/build.rs" ver)))
                  (when (file-exists? vendored-dir)
                    (delete-file-recursively vendored-dir))
                  (when (file-exists? build-rs)
                    (delete-file build-rs)
                    (call-with-output-file build-rs
                      (lambda (port)
                        (format port "fn main() {~@
                           println!(\"cargo:rustc-link-lib=nghttp2\");~@
                           }~%"))))))
              '("0.1.11+1.64.0"))
             ;; Adjust vendored dependency to explicitly use rustix with libc
             ;; backend.
             (for-each
              (lambda (toml)
                (when (file-exists? toml)
                  (substitute* toml
                    (("features = \\[\"fs\"" all)
                     (string-append all ", \"use-libc\"")))))
              '("vendor/tempfile-3.14.0/Cargo.toml"
                "vendor/tempfile-3.16.0/Cargo.toml"
                "vendor/tempfile-3.19.1/Cargo.toml"
                "vendor/tempfile-3.20.0/Cargo.toml"
                "vendor/tempfile-3.21.0/Cargo.toml"
                "vendor/tempfile-3.23.0/Cargo.toml")))))))))

;; Make rust-1.93 the default
(define-public rust rust-1.93)
