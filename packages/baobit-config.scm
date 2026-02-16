;;; Baobit channel configuration
;;;
;;; This file is updated by CI before builds.
;;; The commit here refers to the baobit channel commit used for building.
;;; Note: This file cannot contain its own commit (self-referential).

(define-module (baobit-config)
  #:export (%baobit-commit))

;; Updated by CI: git rev-parse HEAD
(define %baobit-commit "unspecified")
