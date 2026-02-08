;; Channels configuration for baobit
;; Usage: guix time-machine --channel=channels.scm -- build --load-path=packages -e '(@ (rust-xous) rust-xous)'

(list
 (channel
  (name 'guix)
  (url "https://git.savannah.gnu.org/git/guix.git")
  (branch "rust-team")
  (commit "bb39e69d3865da3745b107fac95ae0e7087f529a")
  (introduction
    (make-channel-introduction
      "9edb3f66fd807b096b48283debdcddccfea34bad"
      (openpgp-fingerprint
        "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA")))))
