;; Channels configuration for baobit
;; Usage: guix time-machine --channels=channels/savannah.scm -- build -L packages bao1x-boot0

(list (channel
        (name 'guix)
        (url "https://git.savannah.gnu.org/git/guix.git")
        (branch "rust-team")
        (commit "11a833db3f00042d0dcfd23bca1fbc51e741a822")
        (introduction
         (make-channel-introduction "9edb3f66fd807b096b48283debdcddccfea34bad"
          (openpgp-fingerprint
           "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA")))))
