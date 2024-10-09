BATS := ./test/bats/bin/bats
BATSFLAGS := -t test/e2e.bats --show-output-of-passing-tests --timing --trace --verbose-run

.PHONY: e2e
e2e:
	$(BATS) $(BATSFLAGS)

.PHONY: e2e-mount
e2e-mount:
	$(BATS) $(BATSFLAGS) --filter-tags 'init' --filter-tags 'mount'

.PHONY: e2e-sync
e2e-sync:
	$(BATS) $(BATSFLAGS) --filter-tags 'init' --filter-tags 'mount'

.PHONY: e2e-namespaced
e2e-namespaced:
	$(BATS) $(BATSFLAGS) --filter-tags 'init' --filter-tags 'namespaced'

.PHONY: e2e-multiple
e2e-multiple:
	$(BATS) $(BATSFLAGS) --filter-tags 'init' --filter-tags 'multiple'

.PHONY: e2e-rotate
e2e-rotate:
	$(BATS) $(BATSFLAGS) --filter-tags 'init' --filter-tags 'rotate'

.PHONY: e2e-filtered
e2e-filtered:
	$(BATS) $(BATSFLAGS) --filter-tags 'init' --filter-tags 'filtered'

.PHONY: e2e-windows
e2e-windows:
	$(BATS) $(BATSFLAGS) --filter-tags 'init' --filter-tags 'windows'
