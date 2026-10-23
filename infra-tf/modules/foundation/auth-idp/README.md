# modules/foundation/auth-idp

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.13 |
| aws | ~> 6.0 |
| random | ~> 3.6 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 6.0 |
| random | ~> 3.6 |

## Resources

| Name | Type |
|------|------|
| [aws_cognito_identity_provider.oidc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_identity_provider) | resource |
| [aws_cognito_identity_provider.saml](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_identity_provider) | resource |
| [aws_cognito_user.admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user) | resource |
| [aws_cognito_user_group.admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_group) | resource |
| [aws_cognito_user_in_group.admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_in_group) | resource |
| [aws_cognito_user_pool.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool) | resource |
| [aws_cognito_user_pool_client.mcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client) | resource |
| [aws_cognito_user_pool_client.userpool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client) | resource |
| [aws_cognito_user_pool_domain.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_domain) | resource |
| [aws_ssm_parameter.group_token_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.issuer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.jwks_uri](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.mcp_client_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.user_pool_domain](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.user_pool_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.userpool_client_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [random_password.admin_temp](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name\_prefix | Physical resource name prefix (<resource\_prefix>-<env>). | `string` | n/a | yes |
| ssm\_prefix | SSM parameter root (e.g. /coa). Runtime services read auth config under this path. | `string` | n/a | yes |
| callback\_urls | OAuth callback (redirect) URLs for the web app user pool client. Must be a non-empty list; Cognito requires at least one. | `list(string)` | ```[ "https://localhost/authenticate/" ]``` | no |
| cognito\_custom\_attributes | Custom Cognito user pool attributes. Map key is the attribute name, value is the data type: "string" or "number". Applied only in COGNITO/SAML modes. | `map(string)` | `{}` | no |
| component | Component tag applied to every resource in this module. | `string` | `"foundation"` | no |
| custom\_domain\_ui\_domain\_name | Custom UI domain name. When set, an authenticate callback URL derived from this domain is merged into the web app client callback URLs. Null to skip. | `string` | `null` | no |
| idp\_type | Identity provider mode. COGNITO provisions a standalone Cognito user pool, SAML federates enterprise IdPs through Cognito, OIDC integrates a direct external OIDC IdP with no Cognito resources. | `string` | `"COGNITO"` | no |
| initial\_admin\_email | Email address for the initial admin user seeded in COGNITO/SAML modes. Also used as the user pool username. | `string` | `"nobody@amazon.com"` | no |
| logout\_urls | OAuth logout (sign-out redirect) URLs for the web app user pool client. | `list(string)` | ```[ "https://localhost/" ]``` | no |
| oidc\_providers | OIDC identity providers federated through Cognito (COGNITO/SAML modes). Each entry registers an aws\_cognito\_identity\_provider of type OIDC keyed by name. | ```list(object({ name = string client_id = string client_secret = string issuer_url = string scopes = optional(list(string), ["openid", "email", "profile"]) }))``` | `[]` | no |
| oidc\_settings | Direct external OIDC IdP settings. Required when idp\_type is OIDC (no Cognito is provisioned). issuer\_url and client\_id must be non-empty; group\_claim defaults to "groups". | ```object({ issuer_url = string client_id = string jwks_uri = optional(string) group_claim = optional(string, "groups") })``` | `null` | no |
| refresh\_token\_validity\_hours | Refresh token validity in hours for the web app user pool client. | `number` | `12` | no |
| saml\_providers | SAML identity providers to register with the Cognito user pool (SAML mode). Provide exactly one of metadata\_url or metadata\_content per entry. | ```list(object({ name = string metadata_url = optional(string) metadata_content = optional(string) }))``` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| issuer\_url | OIDC issuer URL. Cognito modes derive it from the user pool; OIDC mode passes through oidc\_settings.issuer\_url. |
| mcp\_client\_id | MCP/CLI client ID. Null-safe: Cognito modes give the MCP client ID, OIDC mode reuses oidc\_settings.client\_id. |
| user\_pool\_arn | Cognito user pool ARN. Null in OIDC mode (no user pool is provisioned). |
| user\_pool\_client\_id | Web app user pool client ID. Cognito modes give the userpool client ID; OIDC mode gives oidc\_settings.client\_id. |
| user\_pool\_domain | Cognito hosted UI domain prefix. Null in OIDC mode. |
| user\_pool\_id | Cognito user pool ID. Null in OIDC mode. |
<!-- END_TF_DOCS -->
