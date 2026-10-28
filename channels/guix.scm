;; Channels configuration for baobit
;; Usage: guix time-machine --channels=channels/guix.scm -- build -L packages bao1x-boot0
;;
;; CI builds against this file and channels/guix-savannah.scm (same commit,
;; different mirror) so a single flaky host does not block a release.  Keep
;; the commit identical in both and in channels/baobit.template.scm.
;;
;; Pinned to the rust-team branch, not master: master caps the Rust series at
;; rust-1.96, rust-team adds rust-1.97 and rust-1.98.  The pinned commit is
;; master@fa73e816fde (the previous pin) plus the 49-commit rust-team queue,
;; so nothing outside the Rust stack moves.  Go back to master once rust-team
;; is merged there; the branch is rebased, so this commit may eventually stop
;; being reachable from the branch head.

(list (channel
        (name 'guix)
        (url "https://codeberg.org/guix/guix.git")
        (branch "rust-team")
        (commit "e55929f3c2e15ef8aff893e33ab553fee567d2e2")
        (introduction
         (make-channel-introduction "9edb3f66fd807b096b48283debdcddccfea34bad"
          (openpgp-fingerprint
           "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA")))))
