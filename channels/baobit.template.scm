;; Verification channels template for baobit
;; Replace BAOBIT_COMMIT with the commit from your device's audit output.
;;
;; Usage: guix time-machine --channels=baobit.scm -- build bao1x-boot0

(list (channel
        (name 'guix)
        (url "https://github.com/sbellem/guix.git")
        (branch "rust-team-v1.5.0-4274-ga832f7e68d")
        (commit "a832f7e68d098837bc81e05b03d78adfa13e6cf7")
        (introduction
         (make-channel-introduction
          "9edb3f66fd807b096b48283debdcddccfea34bad"
          (openpgp-fingerprint
           "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA"))))
      (channel
        (name 'baobit)
        (url "https://github.com/sbellem/baobit")
        (commit "BAOBIT_COMMIT")
        (introduction
         (make-channel-introduction
          "06e8707cac44731b16bfc46b3fb5c34427fc5efe"
          (openpgp-fingerprint
           "E39D 2B3D 0564 BA43 7BD9  2756 C38A E0EC CAB7 D5C8")))))
