;; Channels configuration for baobit
;; Usage: guix time-machine --channels=channels/guix.scm -- build -L packages bao1x-boot0

(list (channel
        (name 'guix)
        (url "https://github.com/sbellem/guix.git")
        (branch "rust-team-v1.5.0-4274-ga832f7e68d")
        (commit "a832f7e68d098837bc81e05b03d78adfa13e6cf7")
        (introduction
         (make-channel-introduction "9edb3f66fd807b096b48283debdcddccfea34bad"
          (openpgp-fingerprint
           "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA")))))
