package server

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net"
	"os"

	"github.com/gidoichi/secrets-store-csi-driver-provider-infisical/auth"
	"github.com/gidoichi/secrets-store-csi-driver-provider-infisical/provider"
	"github.com/go-playground/validator/v10"
	infisical "github.com/infisical/go-sdk"
	"google.golang.org/grpc"
	"gopkg.in/yaml.v2"
	"k8s.io/apimachinery/pkg/types"
	"sigs.k8s.io/secrets-store-csi-driver/provider/v1alpha1"
)

var (
	ErrorInvalidSecretProviderClass = "InvalidSecretProviderClass"
	ErrorUnauthorized               = "Unauthorized"
	ErrorBadRequest                 = "BadRequest"
)

type CSIProviderServer struct {
	grpcServer             *grpc.Server
	listener               net.Listener
	socketPath             string
	auth                   auth.Auth
	infisicalClientFactory provider.InfisicalClientFactory
	validator              *validator.Validate
}

var _ v1alpha1.CSIDriverProviderServer = &CSIProviderServer{}

// NewCSIProviderServer returns a mock csi-provider grpc server
func NewCSIProviderServer(socketPath string, auth auth.Auth, infisicalClientFactory provider.InfisicalClientFactory) *CSIProviderServer {
	server := grpc.NewServer()
	s := &CSIProviderServer{
		grpcServer:             server,
		socketPath:             socketPath,
		auth:                   auth,
		infisicalClientFactory: infisicalClientFactory,
		validator:              validator.New(validator.WithRequiredStructEnabled()),
	}
	v1alpha1.RegisterCSIDriverProviderServer(server, s)
	return s
}

func (m *CSIProviderServer) Start() error {
	var err error
	m.listener, err = net.Listen("unix", m.socketPath)
	if err != nil {
		return err
	}
	go func() {
		if err = m.grpcServer.Serve(m.listener); err != nil {
			return
		}
	}()
	return nil
}

func (m *CSIProviderServer) Stop() {
	m.grpcServer.GracefulStop()
}

// TODO: specify these fields are required or optional
type attributes struct {
	Project             string `json:"projectSlug" validate:"required"`
	Env                 string `json:"envSlug" validate:"required"`
	Path                string `json:"secretsPath"`
	AuthSecretName      string `json:"authSecretName" validate:"required"`
	AuthSecretNamespace string `json:"authSecretNamespace" validate:"required"`
	Objects             string `json:"objects"`
}

type object struct {
	Name string `yaml:"objectName"`
}

func (a *attributes) ParseObjects() ([]object, error) {
	var objects []object
	if err := yaml.Unmarshal([]byte(a.Objects), &objects); err != nil {
		return nil, err
	}
	return objects, nil
}

// Mount implements provider csi-provider method
func (s *CSIProviderServer) Mount(ctx context.Context, req *v1alpha1.MountRequest) (*v1alpha1.MountResponse, error) {
	mountResponse := &v1alpha1.MountResponse{
		Error: &v1alpha1.Error{},
	}
	var attrib attributes
	var secret map[string]string
	var filePermission os.FileMode

	slog.Info("mount", "request", req)

	if err := json.Unmarshal([]byte(req.GetAttributes()), &attrib); err != nil {
		mountResponse.Error.Code = ErrorInvalidSecretProviderClass
		return mountResponse, fmt.Errorf("failed to unmarshal parameters, error: %w", err)
	}
	if err := s.validator.Struct(attrib); err != nil {
		mountResponse.Error.Code = ErrorInvalidSecretProviderClass
		return mountResponse, fmt.Errorf("failed to validate parameters, error: %w", err)
	}
	if err := json.Unmarshal([]byte(req.GetSecrets()), &secret); err != nil {
		return nil, fmt.Errorf("failed to unmarshal secrets, error: %w", err)
	}
	if err := json.Unmarshal([]byte(req.GetPermission()), &filePermission); err != nil {
		return nil, fmt.Errorf("failed to unmarshal file permission, error: %w", err)
	}

	// objects, err := attrib.ParseObjects()
	// if err != nil {
	// 	mountResponse.Error.Code = ErrorInvalidSecretProviderClass
	// 	return mountResponse, fmt.Errorf("failed to get objects, error: %w", err)
	// }

	kubeSecret := types.NamespacedName{
		Namespace: attrib.AuthSecretNamespace,
		Name:      attrib.AuthSecretName,
	}
	credentials, err := s.auth.TokenFromKubeSecret(ctx, kubeSecret)
	if err != nil {
		mountResponse.Error.Code = ErrorBadRequest
		return mountResponse, fmt.Errorf("failed to get credentials, error: %w", err)
	}

	infisicalClient := s.infisicalClientFactory.NewClient(infisical.Config{})
	if _, err := infisicalClient.UniversalAuthLogin(credentials.ID, credentials.Secret); err != nil {
		mountResponse.Error.Code = ErrorUnauthorized
		return mountResponse, fmt.Errorf("failed to login infisical, error: %w", err)
	}
	secrets, err := infisicalClient.ListSecrets(infisical.ListSecretsOptions{
		ProjectSlug:            attrib.Project,
		Environment:            attrib.Env,
		SecretPath:             attrib.Path,
		ExpandSecretReferences: true,
	})
	if err != nil {
		mountResponse.Error.Code = ErrorBadRequest
		return mountResponse, fmt.Errorf("failed to list secrets, error: %w", err)
	}

	// var objectVersions []*v1alpha1.ObjectVersion
	// toIndex := func(objects []object) map[string]int {
	// 	index := make(map[string]int)
	// 	for i, object := range objects {
	// 		index[object.Name] = i
	// 	}
	// 	return index
	// }(objects)
	// for _, secret := range secrets {
	// 	if index, ok := toIndex[secret.SecretKey]; ok {
	// 		objectVersions = append(objectVersions, &v1alpha1.ObjectVersion{
	// 			Id:      objects[index].Name,
	// 			Version: fmt.Sprint(secret.Version),
	// 		})
	// 	}
	// }

	var objectVersions []*v1alpha1.ObjectVersion
	var files []*v1alpha1.File
	mode := int32(filePermission)
	for _, secret := range secrets {
		objectVersions = append(objectVersions, &v1alpha1.ObjectVersion{
			Id:      secret.SecretKey,
			Version: fmt.Sprint(secret.Version),
		})
		files = append(files, &v1alpha1.File{
			Path:     secret.SecretKey,
			Mode:     mode,
			Contents: []byte(secret.SecretValue),
		})
	}
	mountResponse.ObjectVersion = objectVersions
	mountResponse.Files = files

	return mountResponse, nil
}

// Version implements provider csi-provider method
func (m *CSIProviderServer) Version(ctx context.Context, req *v1alpha1.VersionRequest) (*v1alpha1.VersionResponse, error) {
	return &v1alpha1.VersionResponse{
		Version:        "v1alpha1",
		RuntimeName:    "secrets-store-csi-driver-provider-infisical",
		RuntimeVersion: "0.0.1",
	}, nil
}
