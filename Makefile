.PHONY: e2e
e2e:
	./test/bats/bin/bats -t test/e2e.bats --verbose-run --show-output-of-passing-tests
