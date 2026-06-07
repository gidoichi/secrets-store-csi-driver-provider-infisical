.PHONY: deployment
deployment:
	helm template --namespace kube-system --skip-tests secrets-store-csi-driver-provider-infisical charts/secrets-store-csi-driver-provider-infisical | grep -v -e '^ *helm\.sh/chart: ' -e '^ *app\.kubernetes\.io/managed-by: Helm$$' -e '^# Source: ' > deployment/infisical-csi-provider.yaml

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
	$(BATS) $(BATSFLAGS) --filter-tags 'init' --filter-tags 'sync'

.PHONY: e2e-namespaced
e2e-namespaced:
	$(BATS) $(BATSFLAGS) --filter-tags 'init' --filter-tags 'namespaced'

.PHONY: e2e-namespaced-neg
e2e-namespaced-neg:
	$(BATS) $(BATSFLAGS) --filter-tags 'init' --filter-tags 'namespaced' --filter-tags 'namespaced:neg'

.PHONY: e2e-multiple
e2e-multiple:
	$(BATS) $(BATSFLAGS) --filter-tags 'init' --filter-tags 'multiple'
