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

(define %xous-url
  (string-append "https://github.com/" %xous-owner "/xous-core"))
(define %config-file "packages/xous-core-config.scm")

;; ANSI colors
(define %red "\x1b[31m")
(define %blue "\x1b[34m")
(define %green "\x1b[32m")
(define %cyan "\x1b[36m")
(define %reset "\x1b[0m")

(define (run-command cmd)
  "Run CMD and return stdout as string, trimmed."
  (let* ((port (open-input-pipe cmd))
         (output (read-line port)))
    (close-pipe port)
    output))

(define (make-temp-dir)
  (run-command "mktemp -d"))

(define (run-git . args)
  "Run git with ARGS, showing the command. Error if non-zero exit."
  (format #t "  ~a$ git ~a~a~%~%" %blue (string-join args " ") %reset)
  (unless (zero? (apply system* "git" args))
    (error "git command failed")))

(define (update-config! var value)
  "Update VAR in the config file with VALUE."
  (let* ((content (call-with-input-file %config-file get-string-all))
         (pattern (string-append "\\(define " var " \"[^\"]*\"\\)"))
         (replacement (string-append "(define " var " \"" value "\")"))
         (updated (regexp-substitute/global #f pattern content 'pre replacement 'post)))
    (call-with-output-file %config-file
      (lambda (port)
        (put-string port updated)))))

(define (main)
  (let ((tmpdir (make-temp-dir))
        (start-dir (getcwd)))
    (dynamic-wind
      (lambda () #t)
      (lambda ()
        (format #t "~%")
        (run-git "clone" "--depth" (number->string %xous-clone-depth)
                 "--tags" %xous-url tmpdir)
        (chdir tmpdir)
        (run-git "fetch" "--depth" (number->string %xous-clone-depth)
                 "origin" %xous-commit)
        (run-git "-c" "advice.detachedHead=false" "checkout" %xous-commit)
        (let ((describe (run-command "git describe --long"))
              (hash (run-command "guix hash -rx .")))
          (format #t "~%")
          (format #t "  commit:  ~a~a~a~%" %red %xous-commit %reset)
          (format #t "  version: ~a~a~a~%" %green describe %reset)
          (format #t "  hash:    ~a~a~a~%" %cyan hash %reset)
          (format #t "~%")
          (chdir start-dir)
          (update-config! "%xous-version" describe)
          (update-config! "%xous-hash" hash)
          (format #t "~a✓ Updated ~a~a~%~%" %cyan %config-file %reset)))
      (lambda ()
        (chdir start-dir)
        (system* "rm" "-rf" tmpdir)))))

(main)
