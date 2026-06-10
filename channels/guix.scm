;; Channels configuration for baobit (GitHub fork mirror)
;; Usage: guix time-machine --channels=channels/guix.scm -- build -L packages bao1x-boot0
;;
;; CI fetches the Guix channel from our own GitHub fork rather than
;; codeberg.org: codeberg throttles/resets large clones under load (libgit2
;; "Resource temporarily unavailable"), and the GitHub-hosted runners reach a
;; GitHub remote over the intra-provider network reliably.  The commit below is
;; an ancestor of the fork's master; channels/guix-savannah.scm mirrors the
;; same commit.  Keep the fork's master in sync with upstream before bumping.

(list (channel
        (name 'guix)
        (url "https://github.com/sbellem/guix.git")
        (branch "master")
        (commit "b5e047ff9b400585cff590b7ee2f1629b24f6148")
        (introduction
         (make-channel-introduction "9edb3f66fd807b096b48283debdcddccfea34bad"
          (openpgp-fingerprint
           "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA")))))
