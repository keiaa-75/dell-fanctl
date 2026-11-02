PREFIX ?= /usr/local
SBINDIR ?= $(PREFIX)/sbin
SYSCONFDIR ?= $(PREFIX)/etc
LIBDIR ?= $(PREFIX)/lib/dell-fanctl
SYSTEMDDIR ?= /etc/systemd/system

DBFC_DIR = dell-bios-fan-control
DBFC_BIN = $(DBFC_DIR)/dell-bios-fan-control
DBFC_REPO = https://github.com/TomFreudenberg/dell-bios-fan-control.git

.PHONY: all install uninstall enable disable clean help

all: $(DBFC_BIN)

$(DBFC_BIN):
	@if [ ! -d "$(DBFC_DIR)" ]; then \
		git clone $(DBFC_REPO) $(DBFC_DIR); \
	fi
	$(MAKE) -C $(DBFC_DIR)

install: all
	@# remove the pre-rename loop so it can't run alongside dell-fanctl
	@[ -z "$(DESTDIR)" ] && systemctl disable --now i8kfan-init 2>/dev/null || true
	rm -f $(DESTDIR)$(SBINDIR)/fan-control.sh
	rm -f $(DESTDIR)$(SYSTEMDDIR)/i8kfan-init.service
	install -Dm755 $(DBFC_BIN) $(DESTDIR)$(SBINDIR)/dell-bios-fan-control
	install -Dm755 src/dell-fanctl $(DESTDIR)$(SBINDIR)/dell-fanctl
	install -Dm644 lib/parse-config.sh $(DESTDIR)$(LIBDIR)/parse-config.sh
	install -Dm644 lib/config.sh $(DESTDIR)$(LIBDIR)/config.sh
	install -Dm644 services/dell-bios-fan-control.service $(DESTDIR)$(SYSTEMDDIR)/dell-bios-fan-control.service
	install -Dm644 services/dell-fanctl.service $(DESTDIR)$(SYSTEMDDIR)/dell-fanctl.service
	@if [ ! -f "$(DESTDIR)$(SYSCONFDIR)/dell-fanctl.conf" ]; then \
		install -Dm644 config/dell-fanctl.conf $(DESTDIR)$(SYSCONFDIR)/dell-fanctl.conf; \
	fi
	@[ -z "$(DESTDIR)" ] && systemctl daemon-reload || true

uninstall: disable
	rm -f $(DESTDIR)$(SBINDIR)/dell-bios-fan-control
	rm -f $(DESTDIR)$(SBINDIR)/dell-fanctl
	rm -f $(DESTDIR)$(LIBDIR)/parse-config.sh
	rm -f $(DESTDIR)$(LIBDIR)/config.sh
	rmdir $(DESTDIR)$(LIBDIR) 2>/dev/null || true
	rm -f $(DESTDIR)$(SYSTEMDDIR)/dell-bios-fan-control.service
	rm -f $(DESTDIR)$(SYSTEMDDIR)/dell-fanctl.service
	# Note: $(SYSCONFDIR)/dell-fanctl.conf is intentionally preserved to retain user config.
	# Remove it manually if a clean uninstall is needed.
	@[ -z "$(DESTDIR)" ] && systemctl daemon-reload || true

enable:
	@[ -z "$(DESTDIR)" ] || { echo "ERROR: enable target should not be used with DESTDIR set"; exit 1; }
	systemctl disable i8kmon 2>/dev/null || true
	systemctl enable --now dell-bios-fan-control
	systemctl enable --now dell-fanctl

disable:
	@[ -z "$(DESTDIR)" ] || { echo "ERROR: disable target should not be used with DESTDIR set"; exit 1; }
	systemctl disable --now dell-fanctl 2>/dev/null || true
	systemctl disable --now dell-bios-fan-control 2>/dev/null || true

clean:
	@[ -d "$(DBFC_DIR)" ] && $(MAKE) -C $(DBFC_DIR) clean || true

help:
	@echo "Targets:"
	@echo "  all       - Clone and build dell-bios-fan-control (default)"
	@echo "  install   - Install binaries, services, and default config"
	@echo "  uninstall - Remove installed files (preserves config)"
	@echo "  enable    - Enable and start systemd services"
	@echo "  disable   - Stop and disable systemd services"
	@echo "  clean     - Clean build artifacts"
	@echo ""
	@echo "Variables:"
	@echo "  PREFIX=$(PREFIX)"
	@echo "  SBINDIR=$(SBINDIR)"
	@echo "  SYSCONFDIR=$(SYSCONFDIR)"
	@echo "  LIBDIR=$(LIBDIR)"
	@echo "  SYSTEMDDIR=$(SYSTEMDDIR)"
	@echo "  DESTDIR=$(DESTDIR)"
