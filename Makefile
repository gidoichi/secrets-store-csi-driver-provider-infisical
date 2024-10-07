BATS := ./test/bats/bin/bats
BATSFLAGS := -t test/e2e.bats --show-output-of-passing-tests --timing --trace --verbose-run

.PHONY: e2e
e2e:
	$(BATS) $(BATSFLAGS)

.PHONY: e2e-mount
e2e-mount:
	$(BATS) $(BATSFLAGS) --filter '^CSI inline volume test with pod portability($$| - )'
