#!/usr/bin/env bats

load 'test_helper/secrets-store-csi-driver/test/bats/helpers'

BATS_TESTS_DIR=test/tests/infisical
NAMESPACE=kube-public
PROVIDER_MANIFEST='deployment'
SLEEP_TIME=1
WAIT_TIME=120

setup_file() {
    cp -r "$PROVIDER_MANIFEST" "$BATS_FILE_TMPDIR/$PROVIDER_MANIFEST"
}

install_infisical_provider() {
    PROVIDER_MANIFEST="$BATS_FILE_TMPDIR/$PROVIDER_MANIFEST"
    NAMESPACE="$NAMESPACE" yq -i '.metadata.namespace = env(NAMESPACE)' "$PROVIDER_MANIFEST/namespace-transformer.yaml"
    IMAGE_TAG="${IMAGE_TAG:-latest}" yq -i '.images[0].newTag = env(IMAGE_TAG)' "$PROVIDER_MANIFEST/kustomization.yaml"
    kubectl apply -k "$PROVIDER_MANIFEST"
    kubectl --namespace "$NAMESPACE" wait --for=condition=Ready --timeout=60s pod -l app.kubernetes.io/name=secrets-store-csi-driver-provider-infisical

    PROVIDER_POD=$(kubectl --namespace "$NAMESPACE" get pod -l app.kubernetes.io/name=secrets-store-csi-driver-provider-infisical -o jsonpath="{.items[0].metadata.name}")
    kubectl --namespace "$NAMESPACE" get "pod/$PROVIDER_POD"
}

deploy_infisical_secretproviderclass_crd() {
    envsubst < "$BATS_TESTS_DIR/secretproviderclass.yaml" | kubectl apply -n "$NAMESPACE" -f -

    cmd="kubectl get secretproviderclasses.secrets-store.csi.x-k8s.io/infisical -n \"$NAMESPACE\" -o yaml | grep infisical"
    wait_for_process "$WAIT_TIME" "$SLEEP_TIME" "$cmd"
}

teardown_file() {
    # for `install infisical provider`
    PROVIDER_MANIFEST="$BATS_FILE_TMPDIR/$PROVIDER_MANIFEST"
    kubectl delete -k "$PROVIDER_MANIFEST" || true

    # for `deploy infisical secretproviderclass crd`
    envsubst < "$BATS_TESTS_DIR/secretproviderclass.yaml" | kubectl delete -n "$NAMESPACE" -f - || true

    # for `CSI inline volume test with pod portability`
    kubectl --namespace "$NAMESPACE" delete -f "$BATS_TESTS_DIR/pod.yaml" || true
}

@test "install infisical provider" {
    install_infisical_provider
}

@test "deploy infisical secretproviderclass crd" {
    deploy_infisical_secretproviderclass_crd
}

@test "CSI inline volume test with pod portability" {
    install_infisical_provider
    deploy_infisical_secretproviderclass_crd

    kubectl --namespace "$NAMESPACE" apply -f "$BATS_TESTS_DIR/pod.yaml"
    kubectl --namespace "$NAMESPACE" wait --for=condition=Ready --timeout=60s pod/secrets-store-inline-crd

    run kubectl --namespace "$NAMESPACE" get pod/secrets-store-inline-crd
    assert_success
}

@test "CSI inline volume test with pod portability - read infisical kv secret from pod" {
    :
}

@test "CSI inline volume test with pod portability - unmount succeeds" {
    :
}

@test "Sync with K8s secrets - create deployment" {
    :
}

@test "Sync with K8s secrets - read secret from pod, read K8s secret, read env var, check secret ownerReferences with multiple owners" {
    :
}

@test "Sync with K8s secrets - delete deployment, check owner ref updated, check secret deleted" {
    :
}

@test "Test Namespaced scope SecretProviderClass - create deployment" {
    :
}

@test "Test Namespaced scope SecretProviderClass - Sync with K8s secrets - read secret from pod, read K8s secret, read env var, check secret ownerReferences" {
    :
}

@test "Test Namespaced scope SecretProviderClass - Sync with K8s secrets - delete deployment, check secret deleted" {
    :
}

@test "Test Namespaced scope SecretProviderClass - Should fail when no secret provider class in same namespace" {
    :
}

@test "deploy multiple infisical secretproviderclass crd" {
    :
}

@test "deploy pod with multiple secret provider class" {
    :
}

@test "CSI inline volume test with multiple secret provider class" {
    :
}
