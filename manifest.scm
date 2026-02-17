;;; Guix manifest for Baochip production firmware builds
;;;
;;; Build all production artifacts:
;;;   guix time-machine -C channels/guix.scm -- build -L packages -m manifest.scm
;;;
;;; Verify reproducibility:
;;;   guix time-machine -C channels/guix.scm -- build -L packages -m manifest.scm --check

(use-modules (guix packages)
             (bao))

(packages->manifest (list bao1x-boot0
                          bao1x-boot1
                          bao1x-alt-boot1
                          bao1x-baremetal-dabao
                          dabao
                          dabao-helloworld
                          baosec))
