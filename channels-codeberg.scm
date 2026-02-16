;; Channels configuration for baobit (Codeberg mirror)
;; Fallback when Savannah is unavailable

(list (channel
        (name 'guix)
        (url "https://codeberg.org/gluonix/guix.git")
        ;; tag rust-team-v1.5.0-3488-g4ad3747669
        (commit "4ad3747669d7fbda177850cff1d4a9d6478adb84")
        (introduction
         (make-channel-introduction "9edb3f66fd807b096b48283debdcddccfea34bad"
          (openpgp-fingerprint
           "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA")))))
