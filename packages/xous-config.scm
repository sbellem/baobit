(define-module (xous-config)
  #:export (%xous-commit %xous-guix-hash
                         %xous-git-describe
                         %xous-owner
                         %rust-version
                         %rust-xous-commit
                         %rust-xous-guix-hash))

;;; Xous-core release configuration
;;;
;;; To prepare a new release:
;;;   make update-config XOUS_CORE_COMMIT=abc123...
;;;   make boot0
;;;
;;; If you see "fatal: No names found, cannot describe anything",
;;; pass a larger clone depth: CLONE_DEPTH=100

;; GitHub owner (user or org)
(define %xous-owner
  "betrusted-io")
(define %xous-git-describe
  "v0.10.0-61-g5397e1b48")
(define %xous-commit
  "5397e1b488c081566cef2c0e597e05426f67c1c3")
(define %xous-guix-hash
  "1ylzls6v4y5gbjx4yibkg5ndd90h4rlcvmdagkdkapa7wmhw8dbx")

;; Rust toolchain version (e.g., "1.90", "1.91")
;; Package modules resolve this to rust-X.YZ
(define %rust-version
  "1.90")

;; betrusted-io/rust fork for Xous sysroot
;; Must match %rust-version (e.g., 1.90.0-xous branch)
(define %rust-xous-commit
  "ca03bea71ce37fac6696f67020d27d4172f65771")
(define %rust-xous-guix-hash
  "01y6dl7f7ag4pgagav0qp4chir90qraidqsh7r8ml97mcsxwfkfl")
