package server

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"os"

	"encoding/base64"

	"google.golang.org/grpc"
	"gopkg.in/yaml.v2"
	"sigs.k8s.io/secrets-store-csi-driver/provider/v1alpha1"
)

var (
	ErrorInvalidSecretProviderClass = "InvalidSecretProviderClass"
)

type CSIProviderServer struct {
	grpcServer *grpc.Server
	listener   net.Listener
	socketPath string
}

var _ v1alpha1.CSIDriverProviderServer = &CSIProviderServer{}

// NewCSIProviderServer returns a mock csi-provider grpc server
func NewCSIProviderServer(socketPath string) (*CSIProviderServer, error) {
	server := grpc.NewServer()
	s := &CSIProviderServer{
		grpcServer: server,
		socketPath: socketPath,
	}
	v1alpha1.RegisterCSIDriverProviderServer(server, s)
	return s, nil
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
	Project        string `json:"projectSlug"`
	Env            string `json:"envSlug"`
	Path           string `json:"secretsPath"`
	AuthSecretName string `json:"authSecretName"`
	Objects        string `json:"objects"`
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
func (m *CSIProviderServer) Mount(ctx context.Context, req *v1alpha1.MountRequest) (*v1alpha1.MountResponse, error) {
	mountResponse := &v1alpha1.MountResponse{
		Error: &v1alpha1.Error{},
	}
	var attrib attributes
	var secret map[string]string
	var filePermission os.FileMode

	if err := json.Unmarshal([]byte(req.GetAttributes()), &attrib); err != nil {
		mountResponse.Error.Code = ErrorInvalidSecretProviderClass
		return mountResponse, fmt.Errorf("failed to unmarshal parameters, error: %w", err)
	}
	if err := json.Unmarshal([]byte(req.GetSecrets()), &secret); err != nil {
		return nil, fmt.Errorf("failed to unmarshal secrets, error: %w", err)
	}
	if err := json.Unmarshal([]byte(req.GetPermission()), &filePermission); err != nil {
		return nil, fmt.Errorf("failed to unmarshal file permission, error: %w", err)
	}

	objects, err := attrib.ParseObjects()
	if err != nil {
		mountResponse.Error.Code = ErrorInvalidSecretProviderClass
		return mountResponse, fmt.Errorf("failed to get objects, error: %w", err)
	}

	var objectVersions []*v1alpha1.ObjectVersion
	for _, object := range objects {
		objectVersions = append(objectVersions, &v1alpha1.ObjectVersion{
			Id:      object.Name,
			Version: "v1", // TODO: set secret version
		})
	}
	mountResponse.ObjectVersion = objectVersions

	var files []*v1alpha1.File
	mode := int32(filePermission)
	for _, object := range objects {
		files = append(files, &v1alpha1.File{
			Path:     object.Name,
			Mode:     mode,
			Contents: []byte(base64.StdEncoding.EncodeToString([]byte(object.Name))),
		})
	}
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
