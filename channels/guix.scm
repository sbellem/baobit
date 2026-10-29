;; Channels configuration for baobit
;; Usage: guix time-machine --channels=channels/guix.scm -- build -L packages bao1x-boot0
;;
;; CI builds against this file and channels/guix-savannah.scm (same commit,
;; different mirror) so a single flaky host does not block a release.  Keep
;; the commit identical in both and in channels/baobit.template.scm.
;;
;; This baobit branch (rust-team) pins guix's rust-team branch, which carries
;; newer Rust series (rust-1.97, rust-1.98) before they reach master; baobit
;; main stays on guix master.  The pinned commit is main's master pin
;; (fa73e816fde) plus the rust-team queue, so only the Rust stack differs.
;; Maintenance: rebase this branch onto main whenever main moves; when guix
;; merges rust-team into master, bump main to that master commit and reset
;; this branch on top of it.  Upstream rebases rust-team, so an old pin may
;; stop being reachable from the branch head.

(list (channel
        (name 'guix)
        (url "https://codeberg.org/guix/guix.git")
        (branch "rust-team")
        (commit "e55929f3c2e15ef8aff893e33ab553fee567d2e2")
        (introduction
         (make-channel-introduction "9edb3f66fd807b096b48283debdcddccfea34bad"
          (openpgp-fingerprint
           "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA")))))
