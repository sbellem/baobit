(define-module (xous-core-config)
  #:export (%xous-commit %xous-hash %xous-version %xous-clone-depth %xous-owner))

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

(define %xous-version "0.10.0")

(define %xous-commit "0d934e1078955c46abc7d6f9f6eb44956f12751a")

(define %xous-hash "17gibh0z7j1kz5i96xbwq7s4nlp6gxnpnsn0j8arihl9sgnzvbqf")

;; Git clone depth for xous-core-info.scm (increase if git describe fails)
(define %xous-clone-depth 20)
