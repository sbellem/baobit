;; Channels configuration for baobit (Codeberg mirror)
;; Usage: guix time-machine --channels=channels/guix.scm -- build -L packages bao1x-boot0

(list (channel
        (name 'guix)
        (url "https://codeberg.org/guix/guix.git")
        (branch "master")
        (commit "28dcf1364ede4060aeb26b6b668afcbe4a6fb7f7")
        (introduction
         (make-channel-introduction "9edb3f66fd807b096b48283debdcddccfea34bad"
          (openpgp-fingerprint
           "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA")))))
