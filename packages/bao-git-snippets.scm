;;; Snippet overlays for git-fetched crates whose Cargo.toml needs editing
;;; before `cargo vendor` can succeed without pulling extra dependencies.
;;;
;;; These vars are referenced from packages/bao-crates.scm.  The script
;;; scripts/update-bao-crates.sh injects (snippet bao-<NAME>-snippet) into
;;; the corresponding (define rust-<name>-<ver>.<sha> (origin ...)) blocks
;;; that `guix import crate` emits.
;;;
;;; To add a snippet for a new git crate:
;;;   1. Add a (define bao-<NAME>-snippet #~(begin ...)) below.
;;;   2. Export it.
;;;   3. Add an entry to the snippet table in scripts/update-bao-crates.sh.

(define-module (bao-git-snippets)
  #:use-module (guix gexp)
  #:export (bao-atsama5d27-snippet
            bao-rqrr-snippet
            bao-xous-usb-hid-snippet))

;; Strip optional dependencies and feature arrays that would otherwise
;; require vendoring extra crates not in xous-core's lockfile.
(define bao-atsama5d27-snippet
  #~(begin
      (use-modules (guix build utils))
      (substitute* "Cargo.toml"
        ;; Remove dependency entries: name = {...}
        (("rtt-target *= *\\{[^}]*\\}\n?")    "")
        (("ft3269 *= *\\{[^}]*\\}\n?")        "")
        (("ovm7690-rs *= *\\{[^}]*\\}\n?")    "")
        (("bq24157 *= *\\{[^}]*\\}\n?")       "")
        (("bq27421 *= *\\{[^}]*\\}\n?")       "")
        (("ehci *= *\\{[^}]*\\}\n?")          "")
        (("mass-storage *= *\\{[^}]*\\}\n?")  "")
        (("drv2605 *= *\\{[^}]*\\}\n?")       "")
        (("is31fl32xx *= *\\{[^}]*\\}\n?")    "")
        (("embedded-sdmmc *= *\\{[^}]*\\}\n?") "")
        (("hex *= *\\{[^}]*\\}\n?")           "")
        ;; Remove feature arrays: name = [...]
        (("camera *= *\\[[^]]*\\]\n?")        "")
        (("charger *= *\\[[^]]*\\]\n?")       "")
        (("usb-host *= *\\[[^]]*\\]\n?")      "")
        (("rtt *= *\\[[^]]*\\]\n?")           "")
        (("fitment *= *\\[[^]]*\\]\n?")       "")
        (("mmc *= *\\[[^]]*\\]\n?")           "")
        (("sha *= *\\[[^]]*\\]\n?")           ""))))

;; Drop the default 'img' feature and the optional 'image' dep so we don't
;; have to vendor the image crate (xous firmware doesn't decode images here).
(define bao-rqrr-snippet
  #~(begin
      (use-modules (guix build utils))
      (substitute* "Cargo.toml"
        (("default *= *\\[\"img\"\\]\n?")     "")
        (("img *= *\\[\"image\"\\]\n?")       "")
        (("image *= *\\{[^}]*\\}\n?")         ""))))

;; The 'defmt' feature references usb-device/defmt, which isn't enabled in
;; our usb-device vendor; drop that part of the feature spec.
(define bao-xous-usb-hid-snippet
  #~(begin
      (use-modules (guix build utils))
      (substitute* "Cargo.toml"
        (("defmt *= *\\[\"dep:defmt\", *\"usb-device/defmt\"\\]")
         "defmt = [\"dep:defmt\"]"))))
