# secrets-store-csi-driver-provider-infisical
[![Helm charts](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/secrets-store-csi-driver-provider-infisical&label=Helm+charts)](https://artifacthub.io/packages/search?repo=secrets-store-csi-driver-provider-infisical)

Unofficial Infisical provider for the Secret Store CSI Driver.

## Install
1. Prepare a Kubernetes Cluser running [Secret Store SCI Driver](https://secrets-store-csi-driver.sigs.k8s.io/getting-started/installation.html)
1. Install Infisical secret proivder
   - If you can use [HELM](https://helm.sh/):
     ```
     helm install secrets-store-csi-driver-provider-infisical charts/secrets-store-csi-driver-provider-infisical
     ```
   - If you want to use kubectl (Using HELM is recommended, as some features are excluded from `./deployment`):
     ```
     kubectl apply -k ./deployment
     ```

## Usage
1. Create a new Infisical client using [Universal Auth](https://infisical.com/docs/documentation/platform/identities/universal-auth)
1. Store the Client ID and the Client Secret to a Kubernetes Secret as `client-id` key and `client-secret` key respectively
   ```
   # You can create a secret using the following command or applying `./examples/secret.yaml` after it is edited
   kubectl create secret generic infisical-secret-provider-auth-credentials --from-literal="client-id=$id" --from-literal="client-secret=$secret"
   ```
1. Create an SecretProviderClass referencing the secret
   ```
   # You should edit secretproviderclass.yaml to get secrets from provider
   kubectl apply -f ./examples/secretproviderclass.yaml
   ```
1. Create an Pod using the SecretProviderClass
   ```
   # This deployment lists and reads all secrets, then output logs of their contents
   kubectl apply -f ./examples/deployment.yaml
   ```

## Supported Features
Some features are not supported by this provider. Please refer to [this](https://secrets-store-csi-driver.sigs.k8s.io/providers#features-supported-by-current-providers) link for the list of features supported by the Secret Store CSI Driver.

| Features                            | Supported |
|-------------------------------------|-----------|
| [Sync as Kubernetes Secret][secret] | Yes       |
| [Rotation][rotation]                | No        |
| Windows                             | No        |
| Helm Chart                          | Yes       |

[secret]: https://secrets-store-csi-driver.sigs.k8s.io/topics/sync-as-kubernetes-secret
[rotation]: https://secrets-store-csi-driver.sigs.k8s.io/topics/secret-auto-rotation

### Test
E2E [Testing](https://github.com/kubernetes-sigs/secrets-store-csi-driver/tree/v1.4.5/test)

| Test Category                                                                                                                                                                                                                                         | Status                           |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------|
| Mount tests<ul><li>CSI Inline volume test with Pod Portability</li></ul>                                                                                                                                                                              | [![mount-badge]][mount-ci]       |
| Sync as Kubernetes secrets<ul><li>Check Kubernetes secret</li><li>Check owner references in secret with multiple owners</li><li>Check owner references updated when a owner is deleted</li><li>Check secret deleted when all owners deleted</li></ul> | [![sync-badge]][sync-ci]         |
| Namespaced Scope SecretProviderClass<ul><li>Check `SecretProviderClass` in same namespace as pod</li></ul>                                                                                                                                            | [![ns-badge]][ns-ci]             |
| Namespaced Scope SecretProviderClass negative test<ul><li>Check volume mount fails when `SecretProviderClass` not found in same namespace as pod</li></ul>                                                                                            | [![nsneg-badge]][nsneg-ci]       |
| Multiple SecretProviderClass<ul><li>Check multiple CSI Inline volumes with different SecretProviderClass</li></ul>                                                                                                                                    | [![multiple-badge]][multiple-ci] |
| Autorotation of mount contents and Kubernetes secrets<ul><li>Check mount content and Kubernetes secret updated after rotation</li></ul>                                                                                                               | [![rotate-badge]][rotate-ci]     |
| Test filtered watch for `nodePublishSecretRef` feature<ul><li>Check labelled nodePublishSecretRef accessible after upgrade to enable `filteredWatchSecret` feature</li></ul>                                                                          | [![filtered-badge]][filtered-ci] |
| Windows tests                                                                                                                                                                                                                                         | [![windows-badge]][windows-ci]   |

[mount-badge]: https://github.com/gidoichi/secrets-store-csi-driver-provider-infisical/actions/workflows/test-mount.yml/badge.svg?branch=e2e
[mount-ci]: https://github.com/gidoichi/secrets-store-csi-driver-provider-infisical/actions/workflows/test-mount.yml?query=branch%3Ae2e
[sync-badge]: https://github.com/gidoichi/secrets-store-csi-driver-provider-infisical/actions/workflows/test-sync.yml/badge.svg?branch=e2e
[sync-ci]: https://github.com/gidoichi/secrets-store-csi-driver-provider-infisical/actions/workflows/test-sync.yml?query=branch%3Ae2e
[ns-badge]: https://github.com/gidoichi/secrets-store-csi-driver-provider-infisical/actions/workflows/test-namespaced.yml/badge.svg?branch=e2e
[ns-ci]: https://github.com/gidoichi/secrets-store-csi-driver-provider-infisical/actions/workflows/test-namespaced.yml?query=branch%3Ae2e
[nsneg-badge]: https://github.com/gidoichi/secrets-store-csi-driver-provider-infisical/actions/workflows/test-namespaced-neg.yml/badge.svg?branch=e2e
[nsneg-ci]: https://github.com/gidoichi/secrets-store-csi-driver-provider-infisical/actions/workflows/test-namespaced-neg.yml?query=branch%3Ae2e
[multiple-badge]: https://github.com/gidoichi/secrets-store-csi-driver-provider-infisical/actions/workflows/test-multiple.yml/badge.svg?branch=e2e
[multiple-ci]: https://github.com/gidoichi/secrets-store-csi-driver-provider-infisical/actions/workflows/test-multiple.yml?query=branch%3Ae2e
[rotate-badge]: https://github.com/gidoichi/secrets-store-csi-driver-provider-infisical/actions/workflows/test-rotate.yml/badge.svg?branch=e2e
[rotate-ci]: https://github.com/gidoichi/secrets-store-csi-driver-provider-infisical/actions/workflows/test-rotate.yml?query=branch%3Ae2e
[filtered-badge]: https://github.com/gidoichi/secrets-store-csi-driver-provider-infisical/actions/workflows/test-filtered.yml/badge.svg?branch=e2e
[filtered-ci]: https://github.com/gidoichi/secrets-store-csi-driver-provider-infisical/actions/workflows/test-filtered.yml?query=branch%3Ae2e
[windows-badge]: https://github.com/gidoichi/secrets-store-csi-driver-provider-infisical/actions/workflows/test-windows.yml/badge.svg?branch=e2e
[windows-ci]: https://github.com/gidoichi/secrets-store-csi-driver-provider-infisical/actions/workflows/test-windows.yml?query=branch%3Ae2e
