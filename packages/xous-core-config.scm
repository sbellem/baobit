(define-module (xous-core-config)
  #:export (%xous-commit %xous-hash %xous-version %xous-clone-depth))

;;; Xous-core release configuration
;;;
;;; To prepare a new release:
;;; 1. Update %xous-commit to the target commit
;;; 2. Run `make xous-core-info` - computes hash and git describe
;;; 3. Run `make boot0`
;;;
;;; If you see "fatal: No names found, cannot describe anything",
;;; increase %xous-clone-depth (need more history to reach a tag).

(define %xous-commit "893057958027dce8b5ab11b2ddacfc504fe20781")

(define %xous-version "0.10.0")

(define %xous-hash "0031fw8w63ah3araqj5d1gyr5gcsvhf17x1b4xsmldkzns5j2b41")

;; Git clone depth for xous-core-info.scm (increase if git describe fails)
(define %xous-clone-depth 20)
