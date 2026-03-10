#!/usr/bin/env -S guix repl -L packages --
!#
;;; Read user-defined values from baobit.toml, compute derived values
;;; (guix hashes, git-describe), and write everything to xous-config.scm.
;;;
;;; Usage:
;;;   ./update-config.scm
;;;   ./update-config.scm --config path/to/config.toml
;;;   ./update-config.scm --help

(use-modules (guix build toml)
             (ice-9 popen)
             (ice-9 rdelim)
             (ice-9 textual-ports)
             (ice-9 regex)
             (ice-9 getopt-long))

(define %default-toml
  "baobit.toml")
(define %config-file
  "packages/xous-config.scm")

;; ANSI colors
(define %red "\x1b[31m")
(define %blue "\x1b[34m")
(define %green "\x1b[32m")
(define %cyan "\x1b[36m")
(define %reset "\x1b[0m")

(define option-spec
  '((config (single-char #\c) (value #t))
    (help (single-char #\h))))

(define (usage)
  (format #t "Usage: ~a [OPTIONS]~%"
          (car (command-line)))
  (format #t "~%")
  (format #t "Read baobit.toml, compute guix hashes, update xous-config.scm.~%")
  (format #t "~%")
  (format #t "Options:~%")
  (format #t "  -c, --config FILE   Config file (default: ~a)~%"
          %default-toml)
  (format #t "  -h, --help          Show this help~%")
  (exit 1))

(define (run-command cmd)
  "Run CMD and return stdout as string, or #f on failure/no output."
  (let* ((port (open-input-pipe cmd))
         (output (read-line port))
         (status (close-pipe port)))
    (if (and (zero? (status:exit-val status))
             (not (eof-object? output)))
        output
        #f)))

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
         (pattern (string-append "\\(define " var "[ \n]+\"[^\"]*\"\\)"))
         (replacement (string-append "(define " var "\n  \"" value "\")"))
         (updated (regexp-substitute/global #f
                                            pattern
                                            content
                                            'pre
                                            replacement
                                            'post)))
    (call-with-output-file %config-file
      (lambda (port)
        (put-string port updated)))))

(define (update-repo! commit url owner upstream-url vars)
  "Clone repo, compute hash and git-describe, update config vars."
  (let ((tmpdir (make-temp-dir))
        (start-dir (getcwd))
        (need-describe? (assoc-ref vars 'describe)))
    (dynamic-wind
      (lambda () #t)
      (lambda ()
        (format #t "~%")
        (if need-describe?
            (run-git "clone" url tmpdir)
            (run-git "clone" "--depth" "1" url tmpdir))
        (chdir tmpdir)
        ;; Fetch tags from upstream (needed when building from forks)
        (when upstream-url
          (unless (string=? owner "betrusted-io")
            (run-git "remote" "add" "upstream" upstream-url)
            (run-git "fetch" "--tags" "upstream")))
        (run-git "fetch" "origin" commit)
        (run-git "-c" "advice.detachedHead=false" "checkout" commit)
        (let ((describe (if need-describe?
                            (run-command "git describe --long --abbrev=9")
                            #f))
              (hash (run-command "guix hash -rx .")))
          (format #t "~%")
          (format #t "  commit:  ~a~a~a~%" %red commit %reset)
          (when describe
            (format #t "  version: ~a~a~a~%" %green describe %reset))
          (format #t "  hash:    ~a~a~a~%" %cyan hash %reset)
          (format #t "~%")
          (chdir start-dir)
          ;; Update config variables
          (update-config! (assoc-ref vars 'commit) commit)
          (when (and need-describe? describe)
            (update-config! need-describe? describe))
          (update-config! (assoc-ref vars 'hash) hash)
          (format #t "~a✓ Updated ~a~a~%~%" %cyan %config-file %reset)))
      (lambda ()
        (chdir start-dir)
        (system* "rm" "-rf" tmpdir)))))

(define (toml-ref config keys)
  "Look up KEYS in parsed TOML CONFIG. KEYS is a list of strings."
  (recursive-assoc-ref config keys))

(define (main args)
  (let* ((options (getopt-long args option-spec
                               #:stop-at-first-non-option #t))
         (help? (option-ref options 'help #f))
         (rest (option-ref options '() '()))
         (toml-path (option-ref options 'config %default-toml)))
    (when (or help? (not (null? rest))) (usage))
    (unless (file-exists? toml-path)
      (format (current-error-port) "Error: ~a not found~%" toml-path)
      (exit 1))
    (let* ((config (parse-toml-file toml-path))
           ;; xous-core settings
           (xous-owner (toml-ref config '("xous-core" "owner")))
           (xous-commit (toml-ref config '("xous-core" "commit")))
           ;; rust-xous settings
           (rust-version (toml-ref config '("rust-xous" "version")))
           (rust-commit (toml-ref config '("rust-xous" "commit"))))
      ;; Update xous-core
      (format #t "~%~a=== Updating xous-core ===~a~%" %green %reset)
      (update-config! "%xous-owner" xous-owner)
      (update-config! "%rust-version" rust-version)
      (update-repo! xous-commit
                    (string-append "https://github.com/" xous-owner
                                   "/xous-core")
                    xous-owner
                    "https://github.com/betrusted-io/xous-core"
                    '((commit . "%xous-commit")
                      (describe . "%xous-git-describe")
                      (hash . "%xous-guix-hash")))
      ;; Update rust-xous
      (format #t "~%~a=== Updating betrusted-io/rust ===~a~%" %green %reset)
      (update-repo! rust-commit
                    "https://github.com/betrusted-io/rust"
                    "betrusted-io"
                    #f
                    '((commit . "%rust-xous-commit")
                      (describe . #f)
                      (hash . "%rust-xous-guix-hash"))))))

(main (command-line))
