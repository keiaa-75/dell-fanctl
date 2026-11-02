# Makefile for dell-fanctl. Run `make help` for the available targets.
# Commands are hidden; only results are shown. Run with VERBOSE=1 to see them.

# ---------------------------------------------------------------------------
# Install locations (can be overridden, e.g. make install PREFIX=/usr)
# ---------------------------------------------------------------------------

PREFIX     ?= /usr/local
SBINDIR    ?= $(PREFIX)/sbin
SYSCONFDIR ?= $(PREFIX)/etc
LIBDIR     ?= $(PREFIX)/lib/dell-fanctl
SYSTEMDDIR ?= /etc/systemd/system

CONFIG = $(DESTDIR)$(SYSCONFDIR)/dell-fanctl.conf

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
SYSTEMCTL = systemctl --quiet
else
SYSTEMCTL = :
endif

# ---------------------------------------------------------------------------
# Output: hide commands and "Entering directory" lines
# ---------------------------------------------------------------------------

ifndef VERBOSE
.SILENT:
endif
MAKEFLAGS += --no-print-directory

.PHONY: all install uninstall enable disable clean test help \
        remove-legacy install-bin install-lib install-services install-config \
        no-destdir need-root

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

all: $(DBFC_BIN)
	echo "Build complete. Next: sudo make install"

$(DBFC_BIN):
	echo "Building dell-bios-fan-control..."
	[ -d "$(DBFC_DIR)" ] || git clone --quiet $(DBFC_REPO) $(DBFC_DIR)
	$(MAKE) -C $(DBFC_DIR) > /dev/null

clean:
	[ ! -d "$(DBFC_DIR)" ] || $(MAKE) -C $(DBFC_DIR) clean > /dev/null
	echo "Removed build files."

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

install: need-root remove-legacy install-bin install-lib install-services install-config
	$(SYSTEMCTL) daemon-reload
	echo "Installed dell-fanctl to $(DESTDIR)$(PREFIX)."

# stop and remove the pre-rename loop, so it can't run alongside dell-fanctl
remove-legacy:
	if [ -e "$(DESTDIR)$(SBINDIR)/$(LEGACY_SCRIPT)" ] || [ -e "$(DESTDIR)$(SYSTEMDDIR)/$(LEGACY_SERVICE).service" ]; then \
		$(SYSTEMCTL) disable --now $(LEGACY_SERVICE) 2> /dev/null || true; \
		rm -f "$(DESTDIR)$(SBINDIR)/$(LEGACY_SCRIPT)" "$(DESTDIR)$(SYSTEMDDIR)/$(LEGACY_SERVICE).service"; \
		echo "Removed the old $(LEGACY_SERVICE) install."; \
	fi

install-bin: $(DBFC_BIN)
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
	if [ -f "$(CONFIG)" ]; then \
		echo "Kept the existing config at $(CONFIG)."; \
	else \
		install -Dm644 config/dell-fanctl.conf "$(CONFIG)"; \
		echo "Installed the default config to $(CONFIG)."; \
	fi

# ---------------------------------------------------------------------------
# Uninstall (the config is kept; remove it by hand for a clean uninstall)
# ---------------------------------------------------------------------------

uninstall: need-root disable
	rm -f $(DESTDIR)$(SBINDIR)/dell-bios-fan-control
	rm -f $(DESTDIR)$(SBINDIR)/dell-fanctl
	rm -f $(DESTDIR)$(LIBDIR)/parse-config.sh
	rm -f $(DESTDIR)$(LIBDIR)/config.sh
	rmdir $(DESTDIR)$(LIBDIR) 2> /dev/null || true
	rm -f $(DESTDIR)$(SYSTEMDDIR)/dell-bios-fan-control.service
	rm -f $(DESTDIR)$(SYSTEMDDIR)/dell-fanctl.service
	$(SYSTEMCTL) daemon-reload
	echo "Removed dell-fanctl. The config at $(CONFIG) was kept."

# ---------------------------------------------------------------------------
# Services
# ---------------------------------------------------------------------------

enable: no-destdir need-root
	systemctl --quiet disable i8kmon 2> /dev/null || true
	systemctl --quiet enable --now dell-bios-fan-control
	systemctl --quiet enable --now dell-fanctl
	if systemctl --quiet is-active dell-fanctl; then \
		echo "dell-fanctl is enabled and running."; \
	else \
		echo "ERROR: dell-fanctl did not start. See: journalctl -u dell-fanctl"; exit 1; \
	fi

disable: no-destdir need-root
	systemctl --quiet disable --now dell-fanctl 2> /dev/null || true
	systemctl --quiet disable --now dell-bios-fan-control 2> /dev/null || true
	echo "dell-fanctl is stopped and disabled. BIOS fan control is back on."

no-destdir:
	[ -z "$(DESTDIR)" ] || { echo "ERROR: make $(MAKECMDGOALS) cannot be used with DESTDIR set."; exit 1; }

# root is only needed for the real system, not when installing into DESTDIR
need-root:
	[ -n "$(DESTDIR)" ] || [ "$$(id -u)" -eq 0 ] || { echo "ERROR: this needs root. Run: sudo make $(MAKECMDGOALS)"; exit 1; }

# ---------------------------------------------------------------------------
# Tests (they never touch real fans; see tests/README.md)
# ---------------------------------------------------------------------------

test:
	command -v bats > /dev/null || { echo "ERROR: bats not found. Install it with: sudo apt install bats"; exit 1; }
	bats tests/

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

help:
	echo "Targets:"
	echo "  all        Clone and build dell-bios-fan-control (default)"
	echo "  install    Install binaries, libraries, services and the default config"
	echo "  uninstall  Stop the services and remove installed files (keeps the config)"
	echo "  enable     Enable and start the services"
	echo "  disable    Stop and disable the services"
	echo "  clean      Remove dell-bios-fan-control build files"
	echo "  test       Run the tests (needs bats)"
	echo ""
	echo "Variables:"
	echo "  PREFIX=$(PREFIX)"
	echo "  SBINDIR=$(SBINDIR)"
	echo "  SYSCONFDIR=$(SYSCONFDIR)"
	echo "  LIBDIR=$(LIBDIR)"
	echo "  SYSTEMDDIR=$(SYSTEMDDIR)"
	echo "  DESTDIR=$(DESTDIR)"
	echo "  VERBOSE=1  show the commands as they run"
