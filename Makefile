# Makefile for baobit Guix channel
#
# Usage:
#   make rv32imac-none          # Build bare-metal sysroot
#   make rv32imac-xous          # Build xous sysroot
#   make toolchain              # Build rust-xous-toolchain
#   make boot0                  # Build bao1x-boot0
#   make all-dry                # Dry-run all packages
#
#   CHANNELS=channels-codeberg.scm make toolchain
#   make rv32imac-none DRY=1

CHANNELS ?= channels.scm
DRY ?=

TM := guix time-machine --channels=$(CHANNELS) -- build -L packages
ifdef DRY
  TM += --dry-run
endif

.PHONY: help rust-1.91 rust-1.92 rust-1.93 \
        rv32imac-none rv32imac-xous toolchain \
        boot0 boot1 alt-boot1 baremetal-dabao dabao dabao-helloworld baosec \
        all-dry dry-toolchain

help:
	@echo "Targets:"
	@echo "  Rust toolchain:"
	@echo "    rust-1.91 rust-1.92 rust-1.93"
	@echo "  Sysroots:"
	@echo "    rv32imac-none    - bare-metal sysroot"
	@echo "    rv32imac-xous    - xous sysroot"
	@echo "    toolchain        - rust-xous-toolchain (both sysroots)"
	@echo "  Firmware:"
	@echo "    boot0 boot1 dabao baosec"
	@echo ""
	@echo "Options:"
	@echo "  CHANNELS=file.scm  - use different channels file"
	@echo "  DRY=1              - dry-run only"

# Rust versions
rust-1.91:
	$(TM) -e '(@ (rust) rust-1.91)'

rust-1.92:
	$(TM) -e '(@ (rust) rust-1.92)'

rust-1.93:
	$(TM) -e '(@ (rust) rust-1.93)'

# Sysroots
rv32imac-none:
	$(TM) -e '(@ (embedded) rust-sysroot-riscv32imac-none-elf)'

rv32imac-xous:
	$(TM) -e '(@ (rust-xous-toolchain) rust-sysroot-riscv32imac-xous-elf)'

toolchain:
	$(TM) -e '(@ (rust-xous-toolchain) rust-xous-toolchain)'

# Firmware
boot0:
	$(TM) -e '(@ (bao) bao1x-boot0)'

boot1:
	$(TM) -e '(@ (bao) bao1x-boot1)'

alt-boot1:
	$(TM) -e '(@ (bao) bao1x-alt-boot1)'

baremetal-dabao:
	$(TM) -e '(@ (bao) bao1x-baremetal-dabao)'

dabao:
	$(TM) -e '(@ (bao) dabao)'

dabao-helloworld:
	$(TM) -e '(@ (bao) dabao-helloworld)'

baosec:
	$(TM) -e '(@ (bao) baosec)'

# Dry-run shortcuts
all-dry:
	$(MAKE) DRY=1 rust-1.93 rv32imac-none rv32imac-xous toolchain boot0

dry-toolchain:
	$(MAKE) DRY=1 toolchain
