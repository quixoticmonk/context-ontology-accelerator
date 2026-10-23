# modules/foundation/network

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.13 |
| aws | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 6.0 |

## Resources

| Name | Type |
|------|------|
| [aws_ec2_transit_gateway_vpc_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_vpc_attachment) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.peering](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.private_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.aoss](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.authorizer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.connector](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.discovery_ocsp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.interface_endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.neptune](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.privatelink](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_service_discovery_private_dns_namespace.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_private_dns_namespace) | resource |
| [aws_ssm_parameter.service_namespace_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.service_namespace_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.vpc_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_endpoint.gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.interface](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.jdbc_privatelink](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_peering_connection.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection) | resource |
| [aws_vpc_security_group_egress_rule.authorizer_all_outbound](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.connector_db_ports](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.connector_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.connector_ocsp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.connector_self](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.discovery_ocsp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.ecs_https_anywhere](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.ecs_to_neptune](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.jdbc_client_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.lambda_db_ports](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.lambda_https_anywhere](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.lambda_to_ecs_ontology_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.lambda_to_neptune](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.aoss_from_ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.connector_self](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.interface_endpoints_https_from_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.neptune_from_ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.neptune_from_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.privatelink_from_connector](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.privatelink_from_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name\_prefix | Physical resource name prefix (<resource\_prefix>-<env>). | `string` | n/a | yes |
| region | AWS region — used to build service names for AOSS control-plane and AOSS-data VPC endpoints (no CDK constant for the AOSS suffix pair). | `string` | n/a | yes |
| ssm\_prefix | SSM parameter root (e.g. /coa). Runtime services read config under this path. | `string` | n/a | yes |
| azs | Availability zone names to place subnets in when this module creates the VPC. Length must be >= 2 in that path. Ignored (and may be empty) when vpc\_name is set — the AZ set is derived from the imported private subnets. | `list(string)` | `[]` | no |
| component | Component tag applied to every resource in this module. | `string` | `"foundation"` | no |
| connector\_egress\_cidrs | Remote CIDRs the connector security group is allowed to reach on source-database ports. Empty list allows egress to anywhere (matches the CDK default). Set to narrow egress to a known NAT/proxy range. | `list(string)` | `[]` | no |
| connector\_ocsp\_egress | Enable the connector security group's port-80 egress rule for OCSP certificate revocation checks. Required for the Snowflake driver to avoid a ~5-30s per-responder soft-fail latency; harmless for other engines. | `bool` | `true` | no |
| create\_igw | Provision the internet gateway. Defaults to true when this module creates the VPC and false when it imports one (customers are expected to own IGW in their own VPC). | `bool` | `null` | no |
| create\_jdbc\_connectivity | Provision VPC peering, Transit Gateway attachment, and PrivateLink resources when their inputs are set. Defaults to true when this module creates the VPC and false when it imports one (cross-VPC routing in a customer VPC is theirs to own). | `bool` | `null` | no |
| create\_nat\_gateway | Provision NAT gateway + EIP. Defaults to true when this module creates the VPC and false when it imports one. Requires create\_igw. | `bool` | `null` | no |
| create\_route\_tables | Provision public + per-AZ private route tables and subnet associations. Defaults to true when this module creates the VPC and false when it imports one — customers own route tables in their own VPC. | `bool` | `null` | no |
| create\_service\_discovery\_namespace | Provision the Cloud Map private DNS namespace ({prefix}-services.local). Required for in-VPC service-to-service DNS (ontology-engine, VKG per-namespace instances). Defaults to true — most BYOVPC deployments still want a namespace inside their VPC. Set to false to consume an externally-managed namespace via SSM. | `bool` | `true` | no |
| create\_vpc\_endpoints | Provision the S3/DDB gateway endpoint and the AWS-service interface VPC endpoints listed in locals.tf. Defaults to true when this module creates the VPC and false when it imports one. Interface endpoints are attached to the effective private subnets in either case; gateway endpoints require create\_route\_tables=true because they attach to private route tables. | `bool` | `null` | no |
| jdbc\_peer\_cidrs | Remote CIDRs reachable via VPC peering. Empty list disables peering. | `list(string)` | `[]` | no |
| jdbc\_peer\_owner\_id | AWS account ID of the peer VPC (cross-account peering). Null for same-account. | `string` | `null` | no |
| jdbc\_peer\_region | Region of the peer VPC (cross-region peering). Null for same-region. | `string` | `null` | no |
| jdbc\_peer\_vpc\_id | Peer VPC ID for VPC peering. Null disables peering. | `string` | `null` | no |
| jdbc\_privatelink\_port | PrivateLink endpoint port. Null disables PrivateLink. | `number` | `null` | no |
| jdbc\_privatelink\_private\_dns | Enable private DNS for the PrivateLink endpoint. | `bool` | `false` | no |
| jdbc\_privatelink\_service | PrivateLink endpoint service name (e.g. com.amazonaws.vpce.us-east-1.vpce-svc-xxx). Null disables PrivateLink. | `string` | `null` | no |
| jdbc\_tgw\_cidrs | Remote CIDRs reachable via Transit Gateway. Empty list disables TGW routing. | `list(string)` | `[]` | no |
| jdbc\_tgw\_id | Transit Gateway ID to attach the VPC to. Null disables TGW. | `string` | `null` | no |
| private\_subnet\_name\_pattern | Wildcard pattern matched against subnet tag:Name to select private subnets in the imported VPC. Ignored when vpc\_name is null. Default '*private*' picks up common naming conventions; override for VPCs whose subnets are tagged differently. | `string` | `"*private*"` | no |
| vpc\_cidr | CIDR block for the created VPC. Ignored when vpc\_name is set. | `string` | `"10.0.0.0/16"` | no |
| vpc\_name | Name tag of the existing VPC to import. When set, the module looks the VPC up via data.aws\_vpc filtered on tag:Name = vpc\_name (exactly one VPC must match), and reads private subnets from that VPC whose tag:Name matches private\_subnet\_name\_pattern (at least two must match). Networking primitives (IGW, NAT, route tables, VPC endpoints, JDBC connectivity) default to off in this path — customers are expected to manage them in their own VPC. Override per-primitive via the create\_* flags. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| aoss\_security\_group\_id | AOSS VPC endpoint security group ID. Consumers reach AOSS by adding an ingress rule to this SG (source: their own SG). |
| aoss\_vpc\_endpoint\_id | AOSS data-plane VPC endpoint ID. Null when create\_vpc\_endpoints is false. |
| authorizer\_security\_group\_id | API authorizer Lambda security group ID. Dedicated SG with unrestricted outbound so an external OIDC IdP's JWKS endpoint can be reached on any port. Isolated from the shared Lambda SG so the broader egress stance does not leak to every other VPC Lambda. |
| connector\_security\_group\_id | Connector security group ID (Glue Connection / Athena federation egress to source databases). |
| discovery\_ocsp\_security\_group\_id | Snowflake discovery OCSP security group ID. Attached as a second SG on the sources-db-connector Lambda to allow port-80 OCSP egress WITHOUT granting it to every other Lambda on the shared lambda SG. |
| ecs\_security\_group\_id | ECS Fargate task security group ID. |
| lambda\_security\_group\_id | Lambda function security group ID. |
| nat\_gateway\_id | NAT gateway ID. Null when create\_nat\_gateway is false. |
| neptune\_security\_group\_id | Neptune cluster security group ID (accepts 8182 ingress from ECS + Lambda SGs). |
| private\_route\_table\_ids | Private route table IDs keyed by AZ. Empty map when create\_route\_tables is false. |
| private\_subnet\_azs | Availability zones spanned by the effective private subnets — the input `azs` when this module creates the VPC, or the AZs read from the imported subnets in BYOVPC mode. Sorted for stable ordering. |
| private\_subnet\_ids | Effective private subnet IDs — created by this module or provided via `private_subnet_ids` in BYOVPC mode. Sorted by AZ for stable ordering. |
| public\_subnet\_ids | Effective public subnet IDs — created by this module or provided via `public_subnet_ids` in BYOVPC mode. Empty list when BYOVPC mode has no public\_subnet\_ids set. |
| service\_namespace\_arn | Cloud Map private DNS namespace ARN for service discovery. Null when create\_service\_discovery\_namespace is false. |
| service\_namespace\_id | Cloud Map private DNS namespace ID. Null when create\_service\_discovery\_namespace is false. |
| service\_namespace\_name | Cloud Map private DNS namespace name (e.g. `coa-dev-services.local`). Null when create\_service\_discovery\_namespace is false. |
| vpc\_cidr\_block | VPC CIDR block (created or imported). |
| vpc\_id | VPC ID (created or imported). |
<!-- END_TF_DOCS -->
