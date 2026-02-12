(define-module (xous-core-config)
  #:export (%xous-commit %xous-hash %xous-version %xous-clone-depth %xous-owner
            %rust-version))

;;; Xous-core release configuration
;;;
;;; To prepare a new release:
;;; 1. Update %xous-commit to the target commit
;;; 2. Run `make xous-core-info` - computes hash and git describe
;;; 3. Run `make boot0`
;;;
;;; If you see "fatal: No names found, cannot describe anything",
;;; increase %xous-clone-depth (need more history to reach a tag).

;; GitHub owner (user or org)
(define %xous-owner "betrusted-io")

(define %xous-version "v0.10.0-25-g94e4fc28d")

(define %xous-commit "94e4fc28d8976e49375ca583c5ff08b62e001c4a")

(define %xous-hash "15d0dyc312cplya0w71waqlvlslxmlcjlvvgm7k814d3am811hla")

;; Git clone depth for xous-core-info.scm (increase if git describe fails)
(define %xous-clone-depth 50)

;; Rust toolchain version (e.g., "1.90", "1.91")
;; Package modules resolve this to rust-X.YZ
(define %rust-version "1.90")
