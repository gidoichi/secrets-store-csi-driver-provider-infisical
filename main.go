package main

import (
	"fmt"
	"log"
	"os"
	"os/signal"

	"sigs.k8s.io/secrets-store-csi-driver/provider/fake"
	providerv1alpha1 "sigs.k8s.io/secrets-store-csi-driver/provider/v1alpha1"
)

func main() {
	socketPath := "/etc/kubernetes/secrets-store-csi-providers/infisical.sock"
	os.MkdirAll("/etc/kubernetes/secrets-store-csi-providers", 0755)
	server, err := fake.NewMocKCSIProviderServer(socketPath)
	if err != nil {
		panic(fmt.Errorf("unable to create server: %v", err))
	}
	defer server.Stop()

	objectVersions := map[string]string{"foo": "v1"}
	server.SetObjects(objectVersions)
	files := []*providerv1alpha1.File{
		{
			Path:     "foo",
			Mode:     0666,
			Contents: []byte("foo"),
		},
	}
	server.SetFiles(files)

	if err := server.Start(); err != nil {
		panic(fmt.Errorf("unable to start server: %v", err))
	}

	log.Printf("server started at: %s\n", socketPath)
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt)
	<-quit
	log.Println("shutting down server")
}
