module github.com/gidoichi/secrets-store-csi-driver-provider-infisical/admission-webhook

go 1.24.0

toolchain go1.24.5

require (
	github.com/gidoichi/secrets-store-csi-driver-provider-infisical v0.0.0
	github.com/go-playground/validator/v10 v10.27.0
	github.com/prometheus/client_golang v1.22.0
	github.com/sirupsen/logrus v1.9.3
	github.com/slok/kubewebhook/v2 v2.7.0
	k8s.io/api v0.33.3
	k8s.io/apimachinery v0.33.3
	sigs.k8s.io/secrets-store-csi-driver v1.5.3
)

require (
	github.com/beorn7/perks v1.0.1 // indirect
	github.com/cespare/xxhash/v2 v2.3.0 // indirect
	github.com/fxamacker/cbor/v2 v2.7.0 // indirect
	github.com/gabriel-vasile/mimetype v1.4.8 // indirect
	github.com/go-logr/logr v1.4.3 // indirect
	github.com/go-playground/locales v0.14.1 // indirect
	github.com/go-playground/universal-translator v0.18.1 // indirect
	github.com/goccy/go-yaml v1.18.0 // indirect
	github.com/gogo/protobuf v1.3.2 // indirect
	github.com/json-iterator/go v1.1.12 // indirect
	github.com/kr/text v0.2.0 // indirect
	github.com/leodido/go-urn v1.4.0 // indirect
	github.com/modern-go/concurrent v0.0.0-20180306012644-bacd9c7ef1dd // indirect
	github.com/modern-go/reflect2 v1.0.2 // indirect
	github.com/munnerz/goautoneg v0.0.0-20191010083416-a7dc8b61c822 // indirect
	github.com/prometheus/client_model v0.6.1 // indirect
	github.com/prometheus/common v0.62.0 // indirect
	github.com/prometheus/procfs v0.15.1 // indirect
	github.com/x448/float16 v0.8.4 // indirect
	golang.org/x/crypto v0.38.0 // indirect
	golang.org/x/net v0.40.0 // indirect
	golang.org/x/sys v0.33.0 // indirect
	golang.org/x/text v0.25.0 // indirect
	google.golang.org/protobuf v1.36.6 // indirect
	gopkg.in/inf.v0 v0.9.1 // indirect
	k8s.io/client-go v0.33.3 // indirect
	k8s.io/klog/v2 v2.130.1 // indirect
	k8s.io/utils v0.0.0-20241104100929-3ea5e8cea738 // indirect
	sigs.k8s.io/json v0.0.0-20241010143419-9aa6b5e7a4b3 // indirect
	sigs.k8s.io/randfill v1.0.0 // indirect
	sigs.k8s.io/structured-merge-diff/v4 v4.6.0 // indirect
	sigs.k8s.io/yaml v1.4.0 // indirect
)

replace github.com/gidoichi/secrets-store-csi-driver-provider-infisical => ../
