//go:generate mockgen -destination=mock_$GOPACKAGE/mock_$GOFILE -source=$GOFILE
package provider

import (
	"log/slog"

	"github.com/Infisical/infisical-merge/packages/models"
	"github.com/Infisical/infisical-merge/packages/util"
	infisical "github.com/infisical/go-sdk"
)

type InfisicalClientFactory interface {
	NewClient(config infisical.Config) InfisicalClient
}

func NewInfisicalClientFactory() InfisicalClientFactory {
	return &infisicalClientFactory{}
}

type infisicalClientFactory struct{}

func (f *infisicalClientFactory) NewClient(config infisical.Config) InfisicalClient {
	return NewInfisicalClient(config)
}

type InfisicalClient interface {
	UniversalAuthLogin(string, string) (infisical.MachineIdentityCredential, error)
	ListSecrets(infisical.ListSecretsOptions) ([]infisical.Secret, error)
}

type infisicalClient struct {
	client infisical.InfisicalClientInterface
	auth   *infisical.MachineIdentityCredential
}

func NewInfisicalClient(config infisical.Config) InfisicalClient {
	return &infisicalClient{
		client: infisical.NewInfisicalClient(config),
	}
}

func (c *infisicalClient) UniversalAuthLogin(clientID, clientSecret string) (infisical.MachineIdentityCredential, error) {
	credential, err := c.client.Auth().UniversalAuthLogin(clientID, clientSecret)
	c.auth = &credential
	slog.Info("login", "credential", credential)

	return credential, err
}

func (c *infisicalClient) ListSecrets(options infisical.ListSecretsOptions) ([]infisical.Secret, error) {
	token := &models.TokenDetails{
		Type:  util.UNIVERSAL_AUTH_TOKEN_IDENTIFIER,
		Token: c.auth.AccessToken,
	}

	shouldExpandSecrets := options.ExpandSecretReferences

	secretOverriding := false

	request := models.GetAllSecretsParameters{
		Environment:   options.Environment,
		WorkspaceId:   options.ProjectID,
		SecretsPath:   options.SecretPath,
		IncludeImport: options.IncludeImports,
		Recursive:     options.Recursive,
	}

	// This is a copy of the code from the CLI package
	// https://github.com/Infisical/infisical/blob/a6f4a95821d2dd597a801af7ec873a98d46b5ff8/cli/packages/cmd/secrets.go#L90-L119

	if token != nil && token.Type == util.SERVICE_TOKEN_IDENTIFIER {
		request.InfisicalToken = token.Token
	} else if token != nil && token.Type == util.UNIVERSAL_AUTH_TOKEN_IDENTIFIER {
		request.UniversalAuthAccessToken = token.Token
	}

	secrets, err := util.GetAllEnvironmentVariables(request, "")
	if err != nil {
		util.HandleError(err)
	}

	if secretOverriding {
		secrets = util.OverrideSecrets(secrets, util.SECRET_TYPE_PERSONAL)
	} else {
		secrets = util.OverrideSecrets(secrets, util.SECRET_TYPE_SHARED)
	}

	if shouldExpandSecrets {
		authParams := models.ExpandSecretsAuthentication{}
		if token != nil && token.Type == util.SERVICE_TOKEN_IDENTIFIER {
			authParams.InfisicalToken = token.Token
		} else if token != nil && token.Type == util.UNIVERSAL_AUTH_TOKEN_IDENTIFIER {
			authParams.UniversalAuthAccessToken = token.Token
		}

		secrets = util.ExpandSecrets(secrets, authParams, "")
	}

	// Sort the secrets by key so we can create a consistent output
	secrets = util.SortSecretsByKeys(secrets)

	return c.toSDKSecrets(secrets), nil
}

func (c *infisicalClient) toSDKSecrets(secrets []models.SingleEnvironmentVariable) []infisical.Secret {
	var sdkSecrets []infisical.Secret
	for _, secret := range secrets {
		sdkSecrets = append(sdkSecrets, infisical.Secret{
			SecretKey:   secret.Key,
			SecretValue: secret.Value,
			Version:     1, // because version is not available in the response
		})
	}

	return sdkSecrets
}
