;; Verification channels for baobit 4be6e2d6f6a694942ef6cc333ff2b91f73966644
;;
;; Usage: guix time-machine --channels=baobit.4be6e2d6.scm -- build bao1x-boot1-lite

(list (channel
        (name 'guix)
        (url "https://codeberg.org/guix/guix.git")
        (branch "master")
        (commit "fb78838c613212a5d202f45d7ef27e953aea77b4")
        (introduction
         (make-channel-introduction
          "9edb3f66fd807b096b48283debdcddccfea34bad"
          (openpgp-fingerprint
           "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA"))))
      (channel
        (name 'baobit)
        (url "https://github.com/sbellem/baobit")
        (commit "4be6e2d6f6a694942ef6cc333ff2b91f73966644")
        (introduction
         (make-channel-introduction
          "06e8707cac44731b16bfc46b3fb5c34427fc5efe"
          (openpgp-fingerprint
           "E39D 2B3D 0564 BA43 7BD9  2756 C38A E0EC CAB7 D5C8")))))
