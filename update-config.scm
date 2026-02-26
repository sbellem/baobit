#!/usr/bin/env -S guix repl -L packages --
!#
;;; Update xous-config.scm with commit hashes, git describe, and guix hashes
;;;
;;; Usage:
;;;   ./update-config.scm --xous-core-commit COMMIT
;;;   ./update-config.scm --rust-xous-commit COMMIT
;;;   ./update-config.scm --xous-core-commit COMMIT --rust-xous-commit COMMIT
;;;   ./update-config.scm -x COMMIT --clone-depth 100
;;;
;;; Options:
;;;   -x, --xous-core-commit COMMIT   Update xous-core config
;;;   -r, --rust-xous-commit COMMIT   Update betrusted-io/rust config
;;;   -d, --clone-depth N             Git clone depth (default: 60)

(use-modules (xous-config)
             (ice-9 popen)
             (ice-9 rdelim)
             (ice-9 textual-ports)
             (ice-9 regex)
             (ice-9 getopt-long))

(define %default-clone-depth
  60)
(define %config-file
  "packages/xous-config.scm")

;; ANSI colors
(define %red
  "\x1b[31m")
(define %blue
  "\x1b[34m")
(define %green
  "\x1b[32m")
(define %cyan
  "\x1b[36m")
(define %reset
  "\x1b[0m")

(define option-spec
  '((xous-core-commit (single-char #\x)
                      (value #t))
    (rust-xous-commit (single-char #\r)
                      (value #t))
    (clone-depth (single-char #\d)
                 (value #t))
    (help (single-char #\h))))

(define (usage)
  (format #t "Usage: ~a [OPTIONS]~%"
          (car (command-line)))
  (format #t "~%")
  (format #t "Options:~%")
  (format #t "  -x, --xous-core-commit COMMIT   Update xous-core config~%")
  (format #t
   "  -r, --rust-xous-commit COMMIT   Update betrusted-io/rust config~%")
  (format #t
          "  -d, --clone-depth N             Git clone depth (default: ~a)~%"
          %default-clone-depth)
  (format #t "  -h, --help                      Show this help~%")
  (format #t "~%")
  (format #t "Examples:~%")
  (format #t "  ~a -x abc123~%"
          (car (command-line)))
  (format #t "  ~a -x abc123 -r def456~%"
          (car (command-line)))
  (format #t "  ~a --xous-core-commit abc123 --clone-depth 100~%"
          (car (command-line)))
  (exit 1))

(define (run-command cmd)
  "Run CMD and return stdout as string, trimmed."
  (let* ((port (open-input-pipe cmd))
         (output (read-line port)))
    (close-pipe port) output))

(define (make-temp-dir)
  (run-command "mktemp -d"))

(define (run-git . args)
  "Run git with ARGS, showing the command. Error if non-zero exit."
  (format #t "  ~a$ git ~a~a~%~%" %blue
          (string-join args " ") %reset)
  (unless (zero? (apply system* "git" args))
    (error "git command failed")))

(define (update-config! var value)
  "Update VAR in the config file with VALUE."
  (let* ((content (call-with-input-file %config-file
                    get-string-all))
         (pattern (string-append "\\(define " var " \"[^\"]*\"\\)"))
         (replacement (string-append "(define " var " \"" value "\")"))
         (updated (regexp-substitute/global #f
                                            pattern
                                            content
                                            'pre
                                            replacement
                                            'post)))
    (call-with-output-file %config-file
      (lambda (port)
        (put-string port updated)))))

(define (update-repo! commit
                      url
                      owner
                      upstream-url
                      clone-depth
                      vars)
  "Clone repo, compute hash and git-describe, update config vars."
  (let ((tmpdir (make-temp-dir))
        (start-dir (getcwd)))
    (dynamic-wind (lambda ()
                    #t)
                  (lambda ()
                    (format #t "~%")
                    (run-git "clone"
                             "--depth"
                             (number->string clone-depth)
                             "--tags"
                             url
                             tmpdir)
                    (chdir tmpdir)
                    ;; Fetch tags from upstream (needed when building from forks)
                    (when upstream-url
                      (unless (string=? owner "betrusted-io")
                        (run-git "remote" "add" "upstream" upstream-url)
                        (run-git "fetch" "--tags" "upstream")))
                    (run-git "fetch" "--depth"
                             (number->string clone-depth) "origin" commit)
                    (run-git "-c" "advice.detachedHead=false" "checkout"
                             commit)
                    (let ((describe (run-command
                                     "git describe --long --abbrev=9"))
                          (hash (run-command "guix hash -rx .")))
                      (format #t "~%")
                      (format #t "  commit:  ~a~a~a~%" %red commit %reset)
                      (when describe
                        (format #t "  version: ~a~a~a~%" %green describe
                                %reset))
                      (format #t "  hash:    ~a~a~a~%" %cyan hash %reset)
                      (format #t "~%")
                      (chdir start-dir)
                      ;; Update config variables
                      (update-config! (assoc-ref vars
                                                 'commit) commit)
                      (when (and (assoc-ref vars
                                            'describe) describe)
                        (update-config! (assoc-ref vars
                                                   'describe) describe))
                      (update-config! (assoc-ref vars
                                                 'hash) hash)
                      (format #t "~a✓ Updated ~a~a~%~%" %cyan %config-file
                              %reset)))
                  (lambda ()
                    (chdir start-dir)
                    (system* "rm" "-rf" tmpdir)))))

(define (main args)
  (let* ((options (getopt-long args option-spec))
         (xous-commit (option-ref options
                                  'xous-core-commit #f))
         (rust-commit (option-ref options
                                  'rust-xous-commit #f))
         (clone-depth (or (and=> (option-ref options
                                             'clone-depth #f) string->number)
                          %default-clone-depth))
         (help? (option-ref options
                            'help #f)))
    (when (or help?
              (and (not xous-commit)
                   (not rust-commit)))
      (usage))
    ;; Update xous-core
    (when xous-commit
      (format #t "~%~a=== Updating xous-core ===~a~%" %green %reset)
      (update-repo! xous-commit
                    (string-append "https://github.com/" %xous-owner
                                   "/xous-core")
                    %xous-owner
                    "https://github.com/betrusted-io/xous-core"
                    clone-depth
                    '((commit . "%xous-commit")
                      (describe . "%xous-git-describe")
                      (hash . "%xous-guix-hash"))))
    ;; Update rust-xous
    (when rust-commit
      (format #t "~%~a=== Updating betrusted-io/rust ===~a~%" %green %reset)
      (update-repo! rust-commit
                    "https://github.com/betrusted-io/rust"
                    "betrusted-io"
                    #f ;no upstream for rust fork
                    clone-depth
                    '((commit . "%rust-xous-commit") (describe . #f) ;no git-describe for rust
                      (hash . "%rust-xous-guix-hash"))))))

(main (command-line))
