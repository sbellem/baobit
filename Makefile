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
#   make boot0 SUBS=baobit ROOT=boot0
#   make boot0 CHECK=1

CHANNELS ?= channels.scm
DRY ?=
ROOT ?=
CHECK ?=

# Substitute URL definitions
SUBS_OFFICIAL   := https://ci.guix.gnu.org https://bordeaux.guix.gnu.org
SUBS_BAOBIT     := https://guix.baobit.one
SUBS_COMMUNITY  := https://ci.guix.moe
SUBS_ALL        := $(SUBS_BAOBIT) $(SUBS_COMMUNITY) $(SUBS_OFFICIAL)

# Default: use all substitutes (baobit + official)
SUBS ?= all

# Resolve preset names to URLs
ifeq ($(SUBS),all)
  _SUBS := $(SUBS_ALL)
else ifeq ($(SUBS),official)
  _SUBS := $(SUBS_OFFICIAL)
else ifeq ($(SUBS),baobit)
  _SUBS := $(SUBS_BAOBIT)
else ifeq ($(SUBS),community)
  _SUBS := $(SUBS_COMMUNITY)
else ifeq ($(SUBS),none)
  _SUBS :=
else
  # Raw URL passthrough for custom values
  _SUBS := $(SUBS)
endif

TM := guix time-machine --channels=$(CHANNELS) -- build -L packages
ifdef DRY
  TM += --dry-run
endif
ifneq ($(_SUBS),)
  TM += --substitute-urls="$(_SUBS)"
endif
ifdef ROOT
  TM += --root=$(ROOT)
endif
ifdef CHECK
  TM += --check --keep-failed
endif

.PHONY: help rust-1.91 rust-1.92 rust-1.93 \
        rv32imac-none rv32imac-xous toolchain \
        boot0 boot1 alt-boot1 baremetal-dabao dabao dabao-helloworld baosec \
        all-dry dry-toolchain xous-core-info

help:
	@echo "Targets:"
	@echo "  Rust toolchain:"
	@echo "    rust-1.91 rust-1.92 rust-1.93"
	@echo "  Sysroots:"
	@echo "    rv32imac-none    - bare-metal sysroot"
	@echo "    rv32imac-xous    - xous sysroot"
	@echo "    toolchain        - rust-xous-toolchain (both sysroots)"
	@echo "  Firmware:"
	@echo "    boot0 boot1 alt-boot1 baremetal-dabao dabao dabao-helloworld baosec"
	@echo "  Release helpers:"
	@echo "    xous-core-info   - get git describe + hash for commit in xous-core-config.scm"
	@echo ""
	@echo "Options:"
	@echo "  CHANNELS=file.scm  - use different channels file"
	@echo "  DRY=1              - dry-run only"
	@echo "  SUBS=all           - baobit + community + official substitutes (default)"
	@echo "  SUBS=official      - official Guix substitutes only"
	@echo "  SUBS=baobit        - baobit substitute only"
	@echo "  SUBS=community     - community substitute (ci.guix.moe) only"
	@echo "  SUBS=none          - disable substitutes (build from source)"
	@echo "  SUBS='url ...'     - custom substitute URLs"
	@echo "  ROOT=name          - create GC root with given name"
	@echo "  CHECK=1            - verify reproducibility"

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
	$(MAKE) DRY=1 rv32imac-none rv32imac-xous toolchain boot0

dry-toolchain:
	$(MAKE) DRY=1 toolchain

# Get xous-core info (git describe + guix hash) for commit in xous-core-config.scm
xous-core-info:
	./xous-core-info.scm
