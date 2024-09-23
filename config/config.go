package config

import (
	"fmt"
	"reflect"
	"strings"

	"github.com/go-playground/validator/v10"
	"gopkg.in/yaml.v2"
)

type MountConfig struct {
	Project                  string  `json:"projectSlug" validate:"required"`
	Env                      string  `json:"envSlug" validate:"required"`
	Path                     string  `json:"secretsPath" validate:"required"`
	AuthSecretName           string  `json:"authSecretName" validate:"required"`
	AuthSecretNamespace      string  `json:"authSecretNamespace" validate:"required"`
	RawObjects               *string `json:"objects"`
	CSIPodName               string  `json:"csi.storage.k8s.io/pod.name"`
	CSIPodNamespace          string  `json:"csi.storage.k8s.io/pod.namespace"`
	CSIPodUID                string  `json:"csi.storage.k8s.io/pod.uid"`
	CSIPodServiceAccountName string  `json:"csi.storage.k8s.io/serviceAccount.name"`
	CSIEphemeral             string  `json:"csi.storage.k8s.io/ephemeral"`
	SecretProviderClass      string  `json:"secretProviderClass"`
	parsedObjects            []object
	validator                validator.Validate
}

type object struct {
	Name  string `yaml:"objectName" validate:"required"`
	Alias string `yaml:"objectAlias" validate:"excludes=/"`
}

func NewValidator() *validator.Validate {
	validator := validator.New(validator.WithRequiredStructEnabled())
	validator.RegisterTagNameFunc(func(fld reflect.StructField) string {
		name := strings.SplitN(fld.Tag.Get("json"), ",", 2)[0]
		// skip if tag key says it should be ignored
		if name == "-" {
			return ""
		}
		return name
	})

	return validator
}

func NewMountConfig(validator validator.Validate) *MountConfig {
	return &MountConfig{
		Path:      "/",
		validator: validator,
	}
}

func (a *MountConfig) Objects() ([]object, error) {
	if a.parsedObjects != nil {
		return a.parsedObjects, nil
	}

	if a.RawObjects == nil {
		return nil, nil
	}

	var objects []object
	if err := yaml.Unmarshal([]byte(*a.RawObjects), &objects); err != nil {
		return nil, err
	}

	a.parsedObjects = objects
	return objects, nil
}

func (a *MountConfig) Validate() error {
	if err := a.validator.Struct(a); err != nil {
		return err
	}

	objects, err := a.Objects()
	if err != nil {
		return fmt.Errorf("objects: %w", err)
	}
	for i, object := range objects {
		if err := a.validator.Struct(object); err != nil {
			return fmt.Errorf("objects[%d]: %w", i, err)
		}
	}

	return nil
}
