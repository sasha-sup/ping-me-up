.PHONY: help build musl strip install uninstall systemd-install systemd-uninstall fmt lint test clean run dist
.DEFAULT_GOAL := help

PREFIX        ?= /usr/local
BIN_DIR       := $(PREFIX)/bin
CONFIG_DIR    := /etc/pingmeup
SYSTEMD_DIR   := /etc/systemd/system
CARGO         ?= cargo
TARGET_GLIBC  := target/release/pingmeup
TARGET_MUSL   := target/x86_64-unknown-linux-musl/release/pingmeup

help:  ## Show this help
	@awk 'BEGIN { FS = ":.*##"; printf "Targets:\n" } /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build:  ## Build release binary (glibc dynamic)
	$(CARGO) build --release --locked
	@strip $(TARGET_GLIBC) 2>/dev/null || true
	@ls -lh $(TARGET_GLIBC)

musl:  ## Build fully static binary (requires musl-tools)
	rustup target add x86_64-unknown-linux-musl
	$(CARGO) build --release --target x86_64-unknown-linux-musl --locked
	@strip $(TARGET_MUSL) 2>/dev/null || true
	@ls -lh $(TARGET_MUSL)

install: build  ## Install binary to $(BIN_DIR)/pingmeup
	install -Dm755 $(TARGET_GLIBC) $(DESTDIR)$(BIN_DIR)/pingmeup
	install -d $(DESTDIR)$(CONFIG_DIR)
	@if [ ! -f $(DESTDIR)$(CONFIG_DIR)/config.toml ]; then \
		install -m600 config.example.toml $(DESTDIR)$(CONFIG_DIR)/config.toml; \
		echo "Wrote $(DESTDIR)$(CONFIG_DIR)/config.toml — edit it before running."; \
	fi

uninstall:  ## Remove installed binary
	rm -f $(DESTDIR)$(BIN_DIR)/pingmeup

systemd-install: install  ## Install + enable systemd timer (per-minute)
	install -m644 systemd/pingmeup-monitor.service $(DESTDIR)$(SYSTEMD_DIR)/
	install -m644 systemd/pingmeup-monitor.timer   $(DESTDIR)$(SYSTEMD_DIR)/
	systemctl daemon-reload
	systemctl enable --now pingmeup-monitor.timer

systemd-uninstall:  ## Disable + remove systemd units
	-systemctl disable --now pingmeup-monitor.timer
	rm -f $(DESTDIR)$(SYSTEMD_DIR)/pingmeup-monitor.service
	rm -f $(DESTDIR)$(SYSTEMD_DIR)/pingmeup-monitor.timer
	systemctl daemon-reload

fmt:  ## Format source
	$(CARGO) fmt --all

lint:  ## Run clippy with -D warnings
	RUSTFLAGS='-D warnings' $(CARGO) clippy --all-targets --locked

test:  ## Run tests
	$(CARGO) test --release --locked

run:  ## Run pingmeup once with the local config.toml
	PINGMEUP_CONFIG=./config.toml $(CARGO) run --release --locked

clean:  ## Remove build artifacts
	$(CARGO) clean

dist: build musl  ## Build both glibc + musl, package as tar.gz with sha256
	@mkdir -p dist
	@tar -czf dist/pingmeup-x86_64-linux-gnu.tar.gz  -C target/release pingmeup
	@tar -czf dist/pingmeup-x86_64-linux-musl.tar.gz -C target/x86_64-unknown-linux-musl/release pingmeup
	@cd dist && sha256sum *.tar.gz > SHA256SUMS
	@ls -lh dist/
