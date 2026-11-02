# Makefile for dell-fanctl. Run `make help` for the available targets.

# ---------------------------------------------------------------------------
# Install locations (can be overridden, e.g. make install PREFIX=/usr)
# ---------------------------------------------------------------------------

PREFIX     ?= /usr/local
SBINDIR    ?= $(PREFIX)/sbin
SYSCONFDIR ?= $(PREFIX)/etc
LIBDIR     ?= $(PREFIX)/lib/dell-fanctl
SYSTEMDDIR ?= /etc/systemd/system

# ---------------------------------------------------------------------------
# dell-bios-fan-control, built from its own repository
# ---------------------------------------------------------------------------

DBFC_DIR  = dell-bios-fan-control
DBFC_BIN  = $(DBFC_DIR)/dell-bios-fan-control
DBFC_REPO = https://github.com/TomFreudenberg/dell-bios-fan-control.git

# ---------------------------------------------------------------------------
# Names used before the rename to dell-fanctl.
# Kept so upgrading from an old install removes the old loop.
# ---------------------------------------------------------------------------

LEGACY_SERVICE = i8kfan-init
LEGACY_SCRIPT  = fan-control.sh

# ---------------------------------------------------------------------------
# systemctl is skipped when installing into DESTDIR (e.g. for packaging),
# because that is not the running system.
# ---------------------------------------------------------------------------

ifeq ($(DESTDIR),)
SYSTEMCTL = systemctl
else
SYSTEMCTL = :
endif

.PHONY: all install uninstall enable disable clean test help \
        remove-legacy install-bin install-lib install-services install-config \
        no-destdir

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

all: $(DBFC_BIN)

$(DBFC_BIN):
	[ -d "$(DBFC_DIR)" ] || git clone $(DBFC_REPO) $(DBFC_DIR)
	$(MAKE) -C $(DBFC_DIR)

clean:
	[ ! -d "$(DBFC_DIR)" ] || $(MAKE) -C $(DBFC_DIR) clean

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

install: all remove-legacy install-bin install-lib install-services install-config
	$(SYSTEMCTL) daemon-reload

# stop and remove the pre-rename loop, so it can't run alongside dell-fanctl
remove-legacy:
	$(SYSTEMCTL) disable --now $(LEGACY_SERVICE) 2> /dev/null || true
	rm -f $(DESTDIR)$(SBINDIR)/$(LEGACY_SCRIPT)
	rm -f $(DESTDIR)$(SYSTEMDDIR)/$(LEGACY_SERVICE).service

install-bin:
	install -Dm755 $(DBFC_BIN)      $(DESTDIR)$(SBINDIR)/dell-bios-fan-control
	install -Dm755 src/dell-fanctl  $(DESTDIR)$(SBINDIR)/dell-fanctl

install-lib:
	install -Dm644 lib/parse-config.sh  $(DESTDIR)$(LIBDIR)/parse-config.sh
	install -Dm644 lib/config.sh        $(DESTDIR)$(LIBDIR)/config.sh

install-services:
	install -Dm644 services/dell-bios-fan-control.service  $(DESTDIR)$(SYSTEMDDIR)/dell-bios-fan-control.service
	install -Dm644 services/dell-fanctl.service            $(DESTDIR)$(SYSTEMDDIR)/dell-fanctl.service

# the config is only installed once, so user changes are never overwritten
install-config:
	[ -f "$(DESTDIR)$(SYSCONFDIR)/dell-fanctl.conf" ] || \
		install -Dm644 config/dell-fanctl.conf $(DESTDIR)$(SYSCONFDIR)/dell-fanctl.conf


# ---------------------------------------------------------------------------
# Uninstall (the config is kept; remove it by hand for a clean uninstall)
# ---------------------------------------------------------------------------

uninstall: disable
	rm -f $(DESTDIR)$(SBINDIR)/dell-bios-fan-control
	rm -f $(DESTDIR)$(SBINDIR)/dell-fanctl
	rm -f $(DESTDIR)$(LIBDIR)/parse-config.sh
	rm -f $(DESTDIR)$(LIBDIR)/config.sh
	rmdir $(DESTDIR)$(LIBDIR) 2> /dev/null || true
	rm -f $(DESTDIR)$(SYSTEMDDIR)/dell-bios-fan-control.service
	rm -f $(DESTDIR)$(SYSTEMDDIR)/dell-fanctl.service
	$(SYSTEMCTL) daemon-reload

# ---------------------------------------------------------------------------
# Services
# ---------------------------------------------------------------------------

enable: no-destdir
	systemctl disable i8kmon 2> /dev/null || true
	systemctl enable --now dell-bios-fan-control
	systemctl enable --now dell-fanctl

disable: no-destdir
	systemctl disable --now dell-fanctl 2> /dev/null || true
	systemctl disable --now dell-bios-fan-control 2> /dev/null || true

no-destdir:
	@[ -z "$(DESTDIR)" ] || { echo "ERROR: $(MAKECMDGOALS) cannot be used with DESTDIR set."; exit 1; }

# ---------------------------------------------------------------------------
# Tests (they never touch real fans; see tests/README.md)
# ---------------------------------------------------------------------------

test:
	@command -v bats > /dev/null || { echo "ERROR: bats not found. Please install it to run the test suite."; exit 1; }
	bats tests/

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

help:
	@echo "Targets:"
	@echo "  all        Clone and build dell-bios-fan-control (default)"
	@echo "  install    Install binaries, libraries, services and the default config"
	@echo "  uninstall  Stop the services and remove installed files (keeps the config)"
	@echo "  enable     Enable and start the services"
	@echo "  disable    Stop and disable the services"
	@echo "  clean      Remove dell-bios-fan-control build files"
	@echo "  test       Run the tests (needs bats)"
	@echo ""
	@echo "Variables:"
	@echo "  PREFIX=$(PREFIX)"
	@echo "  SBINDIR=$(SBINDIR)"
	@echo "  SYSCONFDIR=$(SYSCONFDIR)"
	@echo "  LIBDIR=$(LIBDIR)"
	@echo "  SYSTEMDDIR=$(SYSTEMDDIR)"
	@echo "  DESTDIR=$(DESTDIR)"