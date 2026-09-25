# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "aoss_security_group_id" {
  description = "AOSS VPC endpoint security group ID. Consumers reach AOSS by adding an ingress rule to this SG (source: their own SG)."
  value       = aws_security_group.aoss.id
}

output "aoss_vpc_endpoint_id" {
  description = "AOSS data-plane VPC endpoint ID. Null when create_vpc_endpoints is false."
  value       = local.create_vpc_endpoints ? aws_vpc_endpoint.interface["aoss_data"].id : null
}

output "connector_security_group_id" {
  description = "Connector security group ID (Glue Connection / Athena federation egress to source databases)."
  value       = aws_security_group.connector.id
}

output "discovery_ocsp_security_group_id" {
  description = "Snowflake discovery OCSP security group ID. Attached as a second SG on the sources-db-connector Lambda to allow port-80 OCSP egress WITHOUT granting it to every other Lambda on the shared lambda SG."
  value       = aws_security_group.discovery_ocsp.id
}

output "ecs_security_group_id" {
  description = "ECS Fargate task security group ID."
  value       = aws_security_group.ecs.id
}

output "lambda_security_group_id" {
  description = "Lambda function security group ID."
  value       = aws_security_group.lambda.id
}

output "nat_gateway_id" {
  description = "NAT gateway ID. Null when create_nat_gateway is false."
  value       = local.create_nat_gateway ? aws_nat_gateway.this[0].id : null
}

output "neptune_security_group_id" {
  description = "Neptune cluster security group ID (accepts 8182 ingress from ECS + Lambda SGs)."
  value       = aws_security_group.neptune.id
}

output "private_route_table_ids" {
  description = "Private route table IDs keyed by AZ. Empty map when create_route_tables is false."
  value       = local.private_route_table_ids
}

output "private_subnet_azs" {
  description = "Availability zones spanned by the effective private subnets — the input `azs` when this module creates the VPC, or the AZs read from the imported subnets in BYOVPC mode. Sorted for stable ordering."
  value       = local.private_subnet_azs
}

output "private_subnet_ids" {
  description = "Effective private subnet IDs — created by this module or provided via `private_subnet_ids` in BYOVPC mode. Sorted by AZ for stable ordering."
  value       = local.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Effective public subnet IDs — created by this module or provided via `public_subnet_ids` in BYOVPC mode. Empty list when BYOVPC mode has no public_subnet_ids set."
  value       = local.public_subnet_ids
}

output "service_namespace_arn" {
  description = "Cloud Map private DNS namespace ARN for service discovery. Null when create_service_discovery_namespace is false."
  value       = var.create_service_discovery_namespace ? aws_service_discovery_private_dns_namespace.this[0].arn : null
}

output "service_namespace_id" {
  description = "Cloud Map private DNS namespace ID. Null when create_service_discovery_namespace is false."
  value       = var.create_service_discovery_namespace ? aws_service_discovery_private_dns_namespace.this[0].id : null
}

output "service_namespace_name" {
  description = "Cloud Map private DNS namespace name (e.g. `coa-dev-services.local`). Null when create_service_discovery_namespace is false."
  value       = var.create_service_discovery_namespace ? aws_service_discovery_private_dns_namespace.this[0].name : null
}

output "vpc_cidr_block" {
  description = "VPC CIDR block (created or imported)."
  value       = local.vpc_cidr
}

output "vpc_id" {
  description = "VPC ID (created or imported)."
  value       = local.vpc_id
}
