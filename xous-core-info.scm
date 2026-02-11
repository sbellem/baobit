#!/usr/bin/env -S guix repl -L packages
!#
;;; Get git describe and guix hash for the commit in xous-core-config.scm
;;;
;;; Usage: ./xous-core-info.scm
;;;    or: guix repl -L packages xous-core-info.scm

(use-modules (xous-core-config)
             (ice-9 popen)
             (ice-9 rdelim)
             (ice-9 textual-ports)
             (ice-9 regex))

(define %xous-url "https://github.com/betrusted-io/xous-core")
(define %config-file "packages/xous-core-config.scm")

(define (run-command cmd)
  "Run CMD and return stdout as string, trimmed."
  (let* ((port (open-input-pipe cmd))
         (output (read-line port)))
    (close-pipe port)
    output))

(define (make-temp-dir)
  (run-command "mktemp -d"))

(define (update-config-hash! hash)
  "Update %xous-hash in the config file."
  (let* ((content (call-with-input-file %config-file get-string-all))
         (updated (regexp-substitute/global
                   #f
                   "\\(define %xous-hash \"[^\"]*\"\\)"
                   content
                   'pre
                   (string-append "(define %xous-hash \"" hash "\")")
                   'post)))
    (call-with-output-file %config-file
      (lambda (port)
        (put-string port updated)))))

(define (main)
  (let ((tmpdir (make-temp-dir))
        (start-dir (getcwd)))
    (dynamic-wind
      (lambda () #t)
      (lambda ()
        (format #t "commit=~a~%" %xous-commit)
        (system* "git" "clone" "--depth" (number->string %xous-clone-depth)
                 "--tags" %xous-url tmpdir "--quiet")
        (chdir tmpdir)
        (system* "git" "checkout" %xous-commit "--quiet")
        (let ((describe (run-command "git describe"))
              (hash (run-command "guix hash -rx .")))
          (format #t "describe=~a~%" describe)
          (format #t "hash=~a~%" hash)
          (chdir start-dir)
          (update-config-hash! hash)
          (format #t "~%Updated ~a with hash.~%" %config-file)))
      (lambda ()
        (chdir start-dir)
        (system* "rm" "-rf" tmpdir)))))

(main)
