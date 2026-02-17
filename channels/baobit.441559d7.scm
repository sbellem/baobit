;; Verification channels for baobit 441559d7e1984623ec0a52f60f90240c740b6c41
;;
;; Usage: guix time-machine --channels=baobit.441559d7.scm -- build bao1x-boot0

(list (channel
        (name 'guix)
        (url "https://github.com/sbellem/guix.git")
        (commit "4ad3747669d7fbda177850cff1d4a9d6478adb84")
        (introduction
         (make-channel-introduction
          "9edb3f66fd807b096b48283debdcddccfea34bad"
          (openpgp-fingerprint
           "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA"))))
      (channel
        (name 'baobit)
        (url "https://github.com/sbellem/baobit")
        (commit "441559d7e1984623ec0a52f60f90240c740b6c41")
        (introduction
         (make-channel-introduction
          "06e8707cac44731b16bfc46b3fb5c34427fc5efe"
          (openpgp-fingerprint
           "E39D 2B3D 0564 BA43 7BD9  2756 C38A E0EC CAB7 D5C8")))))
