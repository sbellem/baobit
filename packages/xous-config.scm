(define-module (xous-config)
  #:export (%xous-commit %xous-guix-hash %xous-git-describe %xous-owner
            %rust-version %rust-xous-commit %rust-xous-guix-hash))

;;; Xous-core release configuration
;;;
;;; To prepare a new release:
;;;   make update-config XOUS_CORE_COMMIT=abc123...
;;;   make boot0
;;;
;;; If you see "fatal: No names found, cannot describe anything",
;;; pass a larger clone depth: CLONE_DEPTH=100

;; GitHub owner (user or org)
(define %xous-owner "betrusted-io")
(define %xous-git-describe "v0.10.0-52-g4efe50d87")
(define %xous-commit "4efe50d87048b47ce9f0765415df615dbeba985c")
(define %xous-guix-hash "0sfzray3zirkghx17273hg039l7m540wy6ifgbg0cbwvz1ip680r")

;; Rust toolchain version (e.g., "1.90", "1.91")
;; Package modules resolve this to rust-X.YZ
(define %rust-version "1.90")

;; betrusted-io/rust fork for Xous sysroot
;; Must match %rust-version (e.g., 1.90.0-xous branch)
(define %rust-xous-commit "ca03bea71ce37fac6696f67020d27d4172f65771")
(define %rust-xous-guix-hash "01y6dl7f7ag4pgagav0qp4chir90qraidqsh7r8ml97mcsxwfkfl")
