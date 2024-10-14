#!/usr/bin/env bats

load 'test_helper/secrets-store-csi-driver/test/bats/helpers'

BATS_TESTS_DIR=test/tests/infisical
E2E_PROVIDER_TESTS_DIR=test/test_helper/secrets-store-csi-driver/test/bats/tests/e2e_provider
WAIT_TIME=60
SLEEP_TIME=1
export NAMESPACE=kube-public
export PROVIDER_NAMESPACE=kube-public
NODE_SELECTOR_OS=linux
BASE64_FLAGS="-w 0"
if [[ "$OSTYPE" == *"darwin"* ]]; then
  BASE64_FLAGS="-b 0"
fi

# export secret vars
export SECRET_NAME="${SECRET_NAME:-foo}"
# default secret value returned by the mock provider
export SECRET_VALUE="${SECRET_VALUE:-secret}"

# export node selector var
export NODE_SELECTOR_OS="$NODE_SELECTOR_OS"
# default label value of secret synched to k8s
export LABEL_VALUE="${LABEL_VALUE:-"test"}"

# export the secrets-store API version to be used
export API_VERSION="$(get_secrets_store_api_version)"

export ENV_SLUG="${ENV_SLUG:-dev}"
PROVIDER_MANIFEST='deployment'

setup_file() {
    cp -r "$PROVIDER_MANIFEST" "$BATS_FILE_TMPDIR/$PROVIDER_MANIFEST"
}

teardown_file() {
    # for `init`
    PROVIDER_MANIFEST="$BATS_FILE_TMPDIR/$PROVIDER_MANIFEST"
    kubectl delete -k "$PROVIDER_MANIFEST" || true
    envsubst < "$BATS_TESTS_DIR/infisical_secret.yaml" | kubectl delete -n "$PROVIDER_NAMESPACE" -f - || true
    envsubst < "$BATS_TESTS_DIR/infisical_v1_secretproviderclass.yaml" | kubectl delete -n "$NAMESPACE" -f - || true

    # for `mount`
    envsubst < "$E2E_PROVIDER_TESTS_DIR/pod-secrets-store-inline-volume-crd.yaml" | kubectl delete -n "$NAMESPACE" -f - || true

    # for `sync`
    envsubst < "$BATS_TESTS_DIR/infisical_synck8s_v1_secretproviderclass.yaml" | kubectl delete -n "$NAMESPACE" -f - || true
    envsubst < "$E2E_PROVIDER_TESTS_DIR/deployment-synck8s-e2e-provider.yaml" | kubectl delete -n "$NAMESPACE" -f - || true
    envsubst < "$E2E_PROVIDER_TESTS_DIR/deployment-two-synck8s-e2e-provider.yaml" | kubectl delete -n "$NAMESPACE" -f - || true

    # for `namespaced`
    envsubst < "$BATS_TESTS_DIR/infisical_v1_secretproviderclass_ns.yaml" | kubectl delete -f - || true
    envsubst < "$E2E_PROVIDER_TESTS_DIR/deployment-synck8s-e2e-provider.yaml" | kubectl delete -n test-ns -f - || true
    kubectl create namespace test-ns --dry-run=client -o yaml | kubectl delete -f - || true

    # for `namespaced:neg`
    envsubst < "$E2E_PROVIDER_TESTS_DIR/deployment-synck8s-e2e-provider.yaml" | kubectl delete -n negative-test-ns -f - || true
    kubectl create namespace negative-test-ns --dry-run=client -o yaml | kubectl delete -f - || true
}

setup() {
    [ ! -f ${BATS_PARENT_TMPNAME}.skip ] || skip "skip remaining tests"
}

teardown() {
    [ -n "$BATS_TEST_COMPLETED" ] || touch ${BATS_PARENT_TMPNAME}.skip
}

# bats test_tags=init
@test "install infisical provider" {
    PROVIDER_MANIFEST="$BATS_FILE_TMPDIR/$PROVIDER_MANIFEST"
    NAMESPACE="$PROVIDER_NAMESPACE" yq -i '.metadata.namespace = env(NAMESPACE)' "$PROVIDER_MANIFEST/namespace-transformer.yaml"
    IMAGE_TAG="${IMAGE_TAG:-latest}" yq -i '.images[0].newTag = env(IMAGE_TAG)' "$PROVIDER_MANIFEST/kustomization.yaml"
    kubectl apply -k "$PROVIDER_MANIFEST"
    kubectl wait -n "$PROVIDER_NAMESPACE" --for=condition=Ready --timeout=60s pod -l app.kubernetes.io/name=secrets-store-csi-driver-provider-infisical

    PROVIDER_POD=$(kubectl get -n "$PROVIDER_NAMESPACE" pod -l app.kubernetes.io/name=secrets-store-csi-driver-provider-infisical -o jsonpath="{.items[0].metadata.name}")
    kubectl get -n "$PROVIDER_NAMESPACE" "pod/$PROVIDER_POD"

    envsubst < "$BATS_TESTS_DIR/infisical_secret.yaml" | kubectl apply -n "$PROVIDER_NAMESPACE" -f -
}

# bats test_tags=init
@test "deploy infisical secretproviderclass crd" {
    envsubst < "$BATS_TESTS_DIR/infisical_v1_secretproviderclass.yaml" | kubectl apply -n "$NAMESPACE" -f -

    cmd="kubectl get -n '$NAMESPACE' secretproviderclasses.secrets-store.csi.x-k8s.io/e2e-provider -o yaml | grep infisical"
    wait_for_process "$WAIT_TIME" "$SLEEP_TIME" "$cmd"
}

# bats test_tags=mount
@test "CSI inline volume test with pod portability" {
    envsubst < "$E2E_PROVIDER_TESTS_DIR/pod-secrets-store-inline-volume-crd.yaml" | kubectl apply -n "$NAMESPACE" -f -

    kubectl wait -n "$NAMESPACE" --for=condition=Ready --timeout=60s pod/secrets-store-inline-crd

    run kubectl get -n "$NAMESPACE" pod/secrets-store-inline-crd
    assert_success
}

# bats test_tags=mount
@test "CSI inline volume test with pod portability - read secret from pod" {
    wait_for_process "$WAIT_TIME" "$SLEEP_TIME" "kubectl exec -n '$NAMESPACE' secrets-store-inline-crd -- cat '/mnt/secrets-store/$SECRET_NAME' | grep '$SECRET_VALUE'"

    result=$(kubectl exec -n "$NAMESPACE" secrets-store-inline-crd -- cat "/mnt/secrets-store/$SECRET_NAME")
    [[ "${result//$'\r'}" == "${SECRET_VALUE}" ]]
}

# bats test_tags=mount
@test "CSI inline volume test with pod portability - unmount succeeds" {
    # On Linux a failure to unmount the tmpfs will block the pod from being
    # deleted.
    run kubectl delete -n "$NAMESPACE" pod secrets-store-inline-crd
    assert_success

    run kubectl wait -n "$NAMESPACE" --for=delete --timeout=60s pod/secrets-store-inline-crd
    assert_success

    # Sleep to allow time for logs to propagate.
    sleep 10

    # save debug information to archive in case of failure
    archive_info

    # On Windows, the failed unmount calls from: https://github.com/kubernetes-sigs/secrets-store-csi-driver/pull/545
    # do not prevent the pod from being deleted. Search through the driver logs
    # for the error.
    run bash -c "kubectl logs -n '$NAMESPACE' -l app=secrets-store-csi-driver --tail -1 -c secrets-store | grep '^E.*failed to clean and unmount target path.*$'"
    assert_failure
}

# bats test_tags=sync
@test "Sync as K8s secrets - create deployment" {
    envsubst < "$BATS_TESTS_DIR/infisical_synck8s_v1_secretproviderclass.yaml" | kubectl apply -n "$NAMESPACE" -f -

    cmd="kubectl get -n '$NAMESPACE' secretproviderclasses.secrets-store.csi.x-k8s.io/e2e-provider-sync -o yaml | grep infisical"
    wait_for_process "$WAIT_TIME" "$SLEEP_TIME" "$cmd"

    envsubst < "$E2E_PROVIDER_TESTS_DIR/deployment-synck8s-e2e-provider.yaml" | kubectl apply -n "$NAMESPACE" -f -
    envsubst < "$E2E_PROVIDER_TESTS_DIR/deployment-two-synck8s-e2e-provider.yaml" | kubectl apply -n "$NAMESPACE" -f -

    kubectl wait -n "$NAMESPACE" --for=condition=Ready --timeout=60s pod -l app=busybox || true
    kubectl wait -n "$NAMESPACE" --for=condition=Ready --timeout=0 pod -l app=busybox # TODO: remove
}

# bats test_tags=sync
@test "Sync as K8s secrets - read secret from pod, read K8s secret, read env var, check secret ownerReferences with multiple owners" {
    POD=$(kubectl get -n "$NAMESPACE" pod -l app=busybox -o jsonpath="{.items[0].metadata.name}")

    result=$(kubectl exec -n "$NAMESPACE" "$POD" -- cat "/mnt/secrets-store/$SECRET_NAME")
    [[ "${result//$'\r'}" == "${SECRET_VALUE}" ]]

    result=$(kubectl get -n "$NAMESPACE" secret foosecret -o jsonpath="{.data.username}" | base64 -d)
    [[ "${result//$'\r'}" == "${SECRET_VALUE}" ]]

    result=$(kubectl exec -n "$NAMESPACE" "$POD" -- printenv | grep SECRET_USERNAME) | awk -F"=" '{ print $2}'
    [[ "${result//$'\r'}" == "${SECRET_VALUE}" ]]

    result=$(kubectl get -n "$NAMESPACE" secret foosecret -o jsonpath="{.metadata.labels.environment}")
    [[ "${result//$'\r'}" == "${LABEL_VALUE}" ]]

    result=$(kubectl get -n "$NAMESPACE" secret foosecret -o jsonpath="{.metadata.labels.secrets-store\.csi\.k8s\.io/managed}")
    [[ "${result//$'\r'}" == "true" ]]

    run wait_for_process "$WAIT_TIME" "$SLEEP_TIME" "compare_owner_count foosecret '$NAMESPACE' 2"
    assert_success
}

# bats test_tags=sync
@test "Sync as K8s secrets - delete deployment, check owner ref updated, check secret deleted" {
    run kubectl delete -n "$NAMESPACE" -f "$E2E_PROVIDER_TESTS_DIR/deployment-synck8s-e2e-provider.yaml"
    assert_success

    run wait_for_process "$WAIT_TIME" "$SLEEP_TIME" "compare_owner_count foosecret '$NAMESPACE' 1"
    assert_success

    run kubectl delete -n "$NAMESPACE" -f "$E2E_PROVIDER_TESTS_DIR/deployment-two-synck8s-e2e-provider.yaml"
    assert_success

    run wait_for_process "$WAIT_TIME" "$SLEEP_TIME" "check_secret_deleted foosecret '$NAMESPACE'"
    assert_success

    envsubst < "$BATS_TESTS_DIR/infisical_synck8s_v1_secretproviderclass.yaml" | kubectl delete -n "$NAMESPACE" -f -
}

# bats test_tags=namespaced
@test "Test Namespaced scope SecretProviderClass - create deployment" {
    kubectl create namespace test-ns --dry-run=client -o yaml | kubectl apply -f -

    envsubst < "$BATS_TESTS_DIR/infisical_v1_secretproviderclass_ns.yaml" | kubectl apply -f -

    kubectl wait --for condition=established --timeout=60s crd/secretproviderclasses.secrets-store.csi.x-k8s.io

    cmd="kubectl get secretproviderclasses.secrets-store.csi.x-k8s.io/e2e-provider-sync -o yaml | grep e2e-provider"
    wait_for_process "$WAIT_TIME" "$SLEEP_TIME" "$cmd"

    cmd="kubectl get secretproviderclasses.secrets-store.csi.x-k8s.io/e2e-provider-sync -n test-ns -o yaml | grep e2e-provider"
    wait_for_process "$WAIT_TIME" "$SLEEP_TIME" "$cmd"

    envsubst < "$E2E_PROVIDER_TESTS_DIR/deployment-synck8s-e2e-provider.yaml" | kubectl apply -n test-ns -f -

    kubectl wait --for=condition=Ready --timeout=60s pod -l app=busybox -n test-ns
}

# bats test_tags=namespaced
@test "Test Namespaced scope SecretProviderClass - Sync as K8s secrets - read secret from pod, read K8s secret, read env var, check secret ownerReferences" {
    POD=$(kubectl get pod -l app=busybox -n test-ns -o jsonpath="{.items[0].metadata.name}")

    result=$(kubectl exec -n test-ns "$POD" -- cat "/mnt/secrets-store/$SECRET_NAME")
    [[ "${result//$'\r'}" == "${SECRET_VALUE}" ]]

    result=$(kubectl get secret foosecret -n test-ns -o jsonpath="{.data.username}" | base64 -d)
    [[ "${result//$'\r'}" == "${SECRET_VALUE}" ]]

    result=$(kubectl exec -n test-ns "$POD" -- printenv | grep SECRET_USERNAME) | awk -F"=" '{ print $2}'
    [[ "${result//$'\r'}" == "${SECRET_VALUE}" ]]

    run wait_for_process "$WAIT_TIME" "$SLEEP_TIME" "compare_owner_count foosecret test-ns 1"
    assert_success
}

# bats test_tags=namespaced
@test "Test Namespaced scope SecretProviderClass - Sync as K8s secrets - delete deployment, check secret deleted" {
    run kubectl delete -f "$E2E_PROVIDER_TESTS_DIR/deployment-synck8s-e2e-provider.yaml" -n test-ns
    assert_success

    run wait_for_process "$WAIT_TIME" "$SLEEP_TIME" "check_secret_deleted foosecret test-ns"
    assert_success
}

# bats test_tags=namespaced:neg
@test "Test Namespaced scope SecretProviderClass - Should fail when no secret provider class in same namespace" {
    kubectl create namespace negative-test-ns --dry-run=client -o yaml | kubectl apply -f -

    envsubst < "$E2E_PROVIDER_TESTS_DIR/deployment-synck8s-e2e-provider.yaml" | kubectl apply -n negative-test-ns -f -
    sleep 5

    POD=$(kubectl get pod -l app=busybox -n negative-test-ns -o jsonpath="{.items[0].metadata.name}")
    cmd="kubectl describe pod '$POD' -n negative-test-ns | grep 'FailedMount.*failed to get secretproviderclass negative-test-ns/e2e-provider-sync.*not found'"
    wait_for_process "$WAIT_TIME" "$SLEEP_TIME" "$cmd"

    run kubectl delete -f "$E2E_PROVIDER_TESTS_DIR/deployment-synck8s-e2e-provider.yaml" -n negative-test-ns
    assert_success

    run kubectl delete ns negative-test-ns
    assert_success
}

# bats test_tags=multiple
@test "deploy multiple infisical secretproviderclass crd" {
    :
}

# bats test_tags=multiple
@test "deploy pod with multiple secret provider class" {
    :
}

# bats test_tags=multiple
@test "CSI inline volume test with multiple secret provider class" {
    :
}

# bats test_tags=rotate
@test "Autorotation of mount contents and Kubernetes secrets" {
    :
}

# bats test_tags=filtered
@test "Test filtered watch for nodePublishSecretRef feature" {
    :
}
