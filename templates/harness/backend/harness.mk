# kit-harness: managed file (the kit's harness-install.sh updates it; local edits are overwritten)
# Integration harness (see docs/HARNESS.md).
.PHONY: test-integration

test-integration:
	@bash scripts/test-integration.sh
