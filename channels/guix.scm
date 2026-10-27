;; Channels configuration for baobit
;; Usage: guix time-machine --channels=channels/guix.scm -- build -L packages bao1x-boot0
;;
;; CI builds against this file and channels/guix-savannah.scm (same commit,
;; different mirror) so a single flaky host does not block a release.  Keep
;; the commit identical in both and in channels/baobit.template.scm.

(list (channel
        (name 'guix)
        (url "https://codeberg.org/guix/guix.git")
        (branch "master")
        (commit "fa73e816fdeadfc29c388b7892f7ce41028dd56e")
        (introduction
         (make-channel-introduction "9edb3f66fd807b096b48283debdcddccfea34bad"
          (openpgp-fingerprint
           "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA")))))
