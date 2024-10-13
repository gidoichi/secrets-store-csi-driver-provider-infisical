#!/usr/bin/env bats

load 'test_helper/secrets-store-csi-driver/test/bats/helpers'

BATS_TESTS_DIR=test/tests/infisical
E2E_PROVIDER_TESTS_DIR=test/test_helper/secrets-store-csi-driver/test/bats/tests/e2e_provider
WAIT_TIME=120
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
    envsubst < "$BATS_TESTS_DIR/infisical_secret.yaml" | kubectl delete -n "$NAMESPACE" -f - || true
    envsubst < "$BATS_TESTS_DIR/infisical_v1_secretproviderclass.yaml" | kubectl delete -n "$NAMESPACE" -f - || true

    # for `mount`
    envsubst < "$E2E_PROVIDER_TESTS_DIR/pod-secrets-store-inline-volume-crd.yaml" | kubectl delete -n "$NAMESPACE" -f - || true
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
    kubectl wait -n "$PROVIDER_NAMESPACE" --for=condition=Ready --timeout="${WAIT_TIME}s" pod -l app.kubernetes.io/name=secrets-store-csi-driver-provider-infisical

    PROVIDER_POD=$(kubectl get -n "$PROVIDER_NAMESPACE" pod -l app.kubernetes.io/name=secrets-store-csi-driver-provider-infisical -o jsonpath="{.items[0].metadata.name}")
    kubectl get -n "$PROVIDER_NAMESPACE" "pod/$PROVIDER_POD"
}

# bats test_tags=init
@test "deploy infisical secretproviderclass crd" {
    envsubst < "$BATS_TESTS_DIR/infisical_secret.yaml" | kubectl apply -n "$NAMESPACE" -f -
    envsubst < "$BATS_TESTS_DIR/infisical_v1_secretproviderclass.yaml" | kubectl apply -n "$NAMESPACE" -f -

    cmd="kubectl get -n '$NAMESPACE' secretproviderclasses.secrets-store.csi.x-k8s.io/e2e-provider -o yaml | grep infisical"
    wait_for_process "$WAIT_TIME" "$SLEEP_TIME" "$cmd"
}

# bats test_tags=mount
@test "CSI inline volume test with pod portability" {
    envsubst < "$E2E_PROVIDER_TESTS_DIR/pod-secrets-store-inline-volume-crd.yaml" | kubectl apply -n "$NAMESPACE" -f -

    kubectl wait -n "$NAMESPACE" --for=condition=Ready --timeout="${WAIT_TIME}s" pod/secrets-store-inline-crd

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

    run kubectl wait -n "$NAMESPACE" --for=delete --timeout="${WAIT_TIME}s" pod/secrets-store-inline-crd
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
    :
}

# bats test_tags=sync
@test "Sync as K8s secrets - read secret from pod, read K8s secret, read env var, check secret ownerReferences with multiple owners" {
    :
}

# bats test_tags=sync
@test "Sync as K8s secrets - delete deployment, check owner ref updated, check secret deleted" {
    :
}

# bats test_tags=namespaced
@test "Test Namespaced scope SecretProviderClass - create deployment" {
    :
}

# bats test_tags=namespaced
@test "Test Namespaced scope SecretProviderClass - Sync as K8s secrets - read secret from pod, read K8s secret, read env var, check secret ownerReferences" {
    :
}

# bats test_tags=namespaced
@test "Test Namespaced scope SecretProviderClass - Sync as K8s secrets - delete deployment, check secret deleted" {
    :
}

# bats test_tags=namespaced
@test "Test Namespaced scope SecretProviderClass negative test - Should fail when no secret provider class in same namespace" {
    :
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

# bats test_tags=windows
@test "Windows tests" {
    false
}
