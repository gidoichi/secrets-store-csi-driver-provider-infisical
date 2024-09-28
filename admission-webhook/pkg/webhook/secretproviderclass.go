package webhook

import (
	"bytes"
	"context"
	"encoding/json"

	"github.com/gidoichi/secrets-store-csi-driver-provider-infisical/config"
	"github.com/go-playground/validator/v10"
	kwhlog "github.com/slok/kubewebhook/v2/pkg/log"
	kwhmodel "github.com/slok/kubewebhook/v2/pkg/model"
	kwhwebhook "github.com/slok/kubewebhook/v2/pkg/webhook"
	kwhmutating "github.com/slok/kubewebhook/v2/pkg/webhook/mutating"
	kwhvalidating "github.com/slok/kubewebhook/v2/pkg/webhook/validating"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	secretstorecsidriverv1 "sigs.k8s.io/secrets-store-csi-driver/apis/v1"
)

const (
	InfisicalSecretProviderName = "infisical"
)

type secretProviderClassWebhook struct {
	logger    kwhlog.Logger
	validator *validator.Validate
}

var _ kwhmutating.Mutator = &secretProviderClassWebhook{}

// NewSecretProviderClassMutatingWebhook returns a new secretproviderclass mutating webhook.
func NewSecretProviderClassMutatingWebhook(logger kwhlog.Logger) (kwhwebhook.Webhook, error) {
	// Create mutators.
	mutators := []kwhmutating.Mutator{
		&secretProviderClassWebhook{
			logger: logger,
		},
	}

	return kwhmutating.NewWebhook(kwhmutating.WebhookConfig{
		ID:      "secretproviderclass-mutator",
		Obj:     &secretstorecsidriverv1.SecretProviderClass{},
		Mutator: kwhmutating.NewChain(logger, mutators...),
		Logger:  logger,
	})
}

func (w *secretProviderClassWebhook) Mutate(_ context.Context, _ *kwhmodel.AdmissionReview, obj metav1.Object) (*kwhmutating.MutatorResult, error) {
	spc, ok := obj.(*secretstorecsidriverv1.SecretProviderClass)
	if !ok {
		// If not a secretproviderclass just continue the mutation chain(if there is one) and don't do nothing.
		return &kwhmutating.MutatorResult{}, nil
	}
	if spc.Spec.Provider != InfisicalSecretProviderName {
		return &kwhmutating.MutatorResult{}, nil
	}

	return &kwhmutating.MutatorResult{MutatedObject: spc}, nil
}

var _ kwhvalidating.Validator = &secretProviderClassWebhook{}

// NewSecretProviderClassValidatingWebhook returns a new secretproviderclass validating webhook.
func NewSecretProviderClassValidatingWebhook(logger kwhlog.Logger) (kwhwebhook.Webhook, error) {
	// Create validators.
	validators := []kwhvalidating.Validator{
		&secretProviderClassWebhook{
			logger:    logger,
			validator: config.NewValidator(),
		},
	}

	return kwhvalidating.NewWebhook(kwhvalidating.WebhookConfig{
		ID:        "secretproviderclass-validator",
		Obj:       &secretstorecsidriverv1.SecretProviderClass{},
		Validator: kwhvalidating.NewChain(logger, validators...),
		Logger:    logger,
	})
}

func (w *secretProviderClassWebhook) Validate(_ context.Context, _ *kwhmodel.AdmissionReview, obj metav1.Object) (*kwhvalidating.ValidatorResult, error) {
	spc, ok := obj.(*secretstorecsidriverv1.SecretProviderClass)
	if !ok {
		// If not a secretproviderclass just continue the validation chain(if there is one) and don't do nothing.
		return w.validateSkip()
	}
	if spc.Spec.Provider != InfisicalSecretProviderName {
		return w.validateSkip()
	}

	const path = "spec.parameters"

	mountConfig := config.NewMountConfig(*w.validator)
	attributes, err := json.Marshal(spc.Spec.Parameters)
	if err != nil {
		return w.validateFailed(config.NewConfigError(path, err))
	}
	attributesDecoder := json.NewDecoder(bytes.NewReader(attributes))
	attributesDecoder.DisallowUnknownFields()
	if err := attributesDecoder.Decode(mountConfig); err != nil {
		return w.validateFailed(config.NewConfigError(path, err))
	}

	if err := mountConfig.Validate(); err != nil {
		return w.validateFailed(config.NewConfigError(path, err))
	}

	// TODO: check secretObjects

	return w.validateSucceeded()
}

func (w *secretProviderClassWebhook) validateSkip() (*kwhvalidating.ValidatorResult, error) {
	return w.validateSucceeded()
}

func (w *secretProviderClassWebhook) validateSucceeded() (*kwhvalidating.ValidatorResult, error) {
	return &kwhvalidating.ValidatorResult{
		Valid: true,
	}, nil
}

func (w *secretProviderClassWebhook) validateFailed(err error) (*kwhvalidating.ValidatorResult, error) {
	return &kwhvalidating.ValidatorResult{
		Valid:   false,
		Message: err.Error(),
	}, nil
}
