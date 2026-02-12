(define-module (xous-core-config)
  #:export (%xous-commit %xous-guix-hash %xous-git-describe %xous-clone-depth %xous-owner
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

(define %xous-git-describe "v0.10.0-30-g7c98a8689")

(define %xous-commit "7c98a868999861b5b029eb779e2c81be8ceda9da")

(define %xous-guix-hash "180glaiwd2mkc4cmb19i4qzkspb30srgl4shp6ngqfzrdsz72xdg")

;; Git clone depth for xous-core-info.scm (increase if git describe fails)
(define %xous-clone-depth 30)

;; Rust toolchain version (e.g., "1.90", "1.91")
;; Package modules resolve this to rust-X.YZ
(define %rust-version "1.93")
