# Thin wrappers around scripts/sandbox/*. All real logic lives in those scripts, so they work the
# same from a shell, a make target or an agent command. Desktop developers can keep using plain cargo.
SB := scripts/sandbox
SCOPE ?= core

.PHONY: help setup verify verify-bundle fmt fmt-check check lint test gates cli bundle bg-status
help:
	@echo "make setup        install the offline toolchain + vendored crates from the bundle (idempotent)"
	@echo "make verify       fmt check + layers/assets gates + cargo check (core crates)  [run before concluding]"
	@echo "make check|lint|test [SCOPE=core|full]   (EC_TIMEOUT=270 makes long runs resumable)"
	@echo "make fmt | fmt-check | gates | cli ARGS='--help' | bg-status"
	@echo "make verify-bundle [ARGS=\"--livrable DIR\"]   check sandbox/BUNDLE.json against Cargo.lock (and the mirrored tarball)"
	@echo "make bundle OUT=dir   ONLINE only: build the offline bundle"

setup:      ; bash $(SB)/setup.sh $(BUNDLE)
verify:     ; bash $(SB)/verify.sh $(VERIFY_ARGS)
verify-bundle: ; python3 $(SB)/verify_bundle.py $(ARGS)
fmt:        ; bash $(SB)/fmt.sh
fmt-check:  ; bash $(SB)/fmt.sh --check
check:      ; bash $(SB)/check.sh $(SCOPE)
lint:       ; bash $(SB)/lint.sh $(SCOPE)
test:       ; bash $(SB)/test.sh $(if $(TEST_ARGS),$(TEST_ARGS),$(SCOPE))
gates:      ; bash $(SB)/gates.sh
cli:        ; bash $(SB)/run-cli.sh $(ARGS)
bg-status:  ; bash $(SB)/bg.sh status
bundle:     ; bash $(SB)/build-bundle.sh $(or $(OUT),dist/sandbox-bundle)
