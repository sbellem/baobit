;; Channels configuration for baobit (Codeberg mirror)
;; Fallback when Savannah is unavailable

(list (channel
        (name 'guix)
        (url "https://codeberg.org/gluonix/guix.git")
        (branch "rust-team-v1.5.0-4384-gc678e65a77")
        (commit "c678e65a77ee0d983bfd48cd23cdada30e172be8")
        (introduction
         (make-channel-introduction "9edb3f66fd807b096b48283debdcddccfea34bad"
          (openpgp-fingerprint
           "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA")))))
