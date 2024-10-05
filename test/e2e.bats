#!/usr/bin/env bats

load 'test_helper/secrets-store-csi-driver/test/bats/helpers'

BATS_TESTS_DIR=test/tests/infisical
NAMESPACE=kube-public
PROVIDER_MANIFEST='deployment'
NAMESPACE_FILE="$PROVIDER_MANIFEST/namespace-transformer.yaml"
SLEEP_TIME=1
WAIT_TIME=120

NAMESPACE_FILE_COPIED=false

# setup_file() {
# }

teardown_file() {
    run kubectl delete -k "$PROVIDER_MANIFEST"
    if [ "$NAMESPACE_FILE_COPIED" = 'true' ]; then
        mv -f "$NAMESPACE_FILE.bak" "$NAMESPACE_FILE"
    fi

    envsubst < "$BATS_TESTS_DIR/secretproviderclass.yaml" | run kubectl delete -n "$NAMESPACE" -f -

    run kubectl --namespace "$NAMESPACE" delete -f "$BATS_TESTS_DIR/pod.yaml"
}

@test "install infisical provider" {
    :| cp -i "$NAMESPACE_FILE" "$NAMESPACE_FILE.bak"
    diff "$NAMESPACE_FILE" "$NAMESPACE_FILE.bak"
    NAMESPACE_FILE_COPIED='true'

    NAMESPACE="$NAMESPACE" yq -i '.metadata.namespace = env(NAMESPACE)' "$NAMESPACE_FILE"
    kubectl apply -k "$PROVIDER_MANIFEST"
    kubectl --namespace "$NAMESPACE" wait --for=condition=Ready --timeout=12s pod -l app.kubernetes.io/name=secrets-store-csi-driver-provider-infisical

    PROVIDER_POD=$(kubectl --namespace "$NAMESPACE" get pod -l app.kubernetes.io/name=secrets-store-csi-driver-provider-infisical -o jsonpath="{.items[0].metadata.name}")
    kubectl --namespace "$NAMESPACE" get "pod/$PROVIDER_POD"
}

@test "deploy infisical secretproviderclass crd" {
    envsubst < "$BATS_TESTS_DIR/secretproviderclass.yaml" | kubectl apply -n "$NAMESPACE" -f -

    cmd="kubectl get secretproviderclasses.secrets-store.csi.x-k8s.io/infisical -n \"$NAMESPACE\" -o yaml | grep infisical"
    wait_for_process "$WAIT_TIME" "$SLEEP_TIME" "$cmd"
}

@test "CSI inline volume test with pod portability" {
    kubectl --namespace "$NAMESPACE" apply -f "$BATS_TESTS_DIR/pod.yaml"
    kubectl --namespace "$NAMESPACE" wait --for=condition=Ready --timeout=60s pod/secrets-store-inline-crd

    run kubectl --namespace "$NAMESPACE" get pod/secrets-store-inline-crd
    assert_success
}
