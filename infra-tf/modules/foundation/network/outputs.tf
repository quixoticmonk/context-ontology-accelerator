# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "aoss_security_group_id" {
  description = "AOSS VPC endpoint security group ID. Consumers reach AOSS by adding an ingress rule to this SG (source: their own SG)."
  value       = aws_security_group.aoss.id
}

output "aoss_vpc_endpoint_id" {
  description = "AOSS data-plane VPC endpoint ID. Null when the VPC is imported."
  value       = local.create_vpc ? aws_vpc_endpoint.interface["aoss_data"].id : null
}

output "connector_security_group_id" {
  description = "Connector security group ID (Glue Connection / Athena federation egress to source databases)."
  value       = aws_security_group.connector.id
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
  description = "NAT gateway ID. Null when the VPC is imported (no NAT is provisioned by this module)."
  value       = local.create_vpc ? aws_nat_gateway.this[0].id : null
}

output "neptune_security_group_id" {
  description = "Neptune cluster security group ID (accepts 8182 ingress from ECS + Lambda SGs)."
  value       = aws_security_group.neptune.id
}

output "private_route_table_ids" {
  description = "Private route table IDs keyed by AZ. Null when the VPC is imported."
  value       = local.create_vpc ? { for az, rt in aws_route_table.private : az => rt.id } : null
}

output "private_subnet_ids" {
  description = "Private subnet IDs, sorted by AZ name for stable ordering. Null when the VPC is imported."
  value = local.create_vpc ? [
    for az in sort(keys(aws_subnet.private)) : aws_subnet.private[az].id
  ] : null
}

output "public_subnet_ids" {
  description = "Public subnet IDs, sorted by AZ name for stable ordering. Null when the VPC is imported."
  value = local.create_vpc ? [
    for az in sort(keys(aws_subnet.public)) : aws_subnet.public[az].id
  ] : null
}

output "service_namespace_arn" {
  description = "Cloud Map private DNS namespace ARN for service discovery."
  value       = aws_service_discovery_private_dns_namespace.this.arn
}

output "service_namespace_id" {
  description = "Cloud Map private DNS namespace ID."
  value       = aws_service_discovery_private_dns_namespace.this.id
}

output "service_namespace_name" {
  description = "Cloud Map private DNS namespace name (e.g. `coa-dev-services.local`)."
  value       = aws_service_discovery_private_dns_namespace.this.name
}

output "vpc_cidr_block" {
  description = "VPC CIDR block (created or imported)."
  value       = local.vpc_cidr
}

output "vpc_id" {
  description = "VPC ID (created or imported)."
  value       = local.vpc_id
}
