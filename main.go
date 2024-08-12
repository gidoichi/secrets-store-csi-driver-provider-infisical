package main

import (
	"fmt"
	"log"
	"os"
	"os/signal"

	"github.com/gidoichi/secrets-store-csi-driver-provider-infisical/server"
)

func main() {
	socketPath := "/etc/kubernetes/secrets-store-csi-providers/infisical.sock"
	_ = os.MkdirAll("/etc/kubernetes/secrets-store-csi-providers", 0755)
	_ = os.Remove(socketPath)
	provider, err := server.NewCSIProviderServer(socketPath)
	if err != nil {
		panic(fmt.Errorf("unable to create server: %v", err))
	}
	defer provider.Stop()

	if err := provider.Start(); err != nil {
		panic(fmt.Errorf("unable to start server: %v", err))
	}

	log.Printf("server started at: %s\n", socketPath)
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt)
	<-quit
	log.Println("shutting down server")
}
