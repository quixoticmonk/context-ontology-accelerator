# modules/foundation/storage

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
| [aws_neptune_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/neptune_cluster) | resource |
| [aws_neptune_cluster_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/neptune_cluster_instance) | resource |
| [aws_neptune_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/neptune_subnet_group) | resource |
| [aws_opensearchserverless_access_policy.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_access_policy) | resource |
| [aws_opensearchserverless_collection.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_collection) | resource |
| [aws_opensearchserverless_collection_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_collection_group) | resource |
| [aws_opensearchserverless_security_policy.encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_security_policy) | resource |
| [aws_opensearchserverless_security_policy.network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_security_policy) | resource |
| [aws_s3_bucket.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.athena_results](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.athena_spill](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.ontology_artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_cors_configuration.ontology_artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.athena_results](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.athena_spill](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.logged](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_policy.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_policy.logged](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.logged](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.logged](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_versioning.athena_results](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_versioning.athena_spill](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_versioning.ontology_artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_ssm_parameter.athena_results_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.athena_spill_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.neptune_cluster_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.neptune_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.ontology_bucket_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.opensearch_collection_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.opensearch_collection_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.opensearch_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aoss\_security\_group\_id | Security group attached to the AOSS VPC endpoint (from the network module). Referenced so the storage module orders after network connectivity is in place. | `string` | n/a | yes |
| aoss\_vpc\_endpoint\_id | AOSS data-plane VPC endpoint ID (from the network module). Referenced by the AOSS network security policy to scope collection + dashboard access to VPC-internal traffic. In `dev` an additional AllowFromPublic rule is added; every other env is VPCE-only. | `string` | n/a | yes |
| env | Deployment environment name. Gates prod retain-vs-destroy behavior on Neptune and S3 buckets. | `string` | n/a | yes |
| name\_prefix | Physical resource name prefix (<resource\_prefix>-<env>). | `string` | n/a | yes |
| neptune\_security\_group\_id | Security group attached to the Neptune cluster (from the network module). | `string` | n/a | yes |
| private\_subnet\_ids | Private subnet IDs (from the network module) for the Neptune DB subnet group. | `list(string)` | n/a | yes |
| region | AWS region — used to construct the Neptune data-access ARN. | `string` | n/a | yes |
| ssm\_prefix | SSM parameter root (e.g. /coa). Runtime services read storage config under this path. | `string` | n/a | yes |
| allowed\_origin | Browser origin allowed to PUT/GET directly to the ontology-artifacts bucket via presigned URLs. Defaults to * in non-prod; without a matching CORS rule the browser blocks the presigned PUT. | `string` | `"*"` | no |
| aoss\_max\_ocu | Maximum OCUs for both indexing and search on the NEXTGEN collection group. Caps cost; mirrors CDK context `aoss_max_ocu`. Must be 2, 4, 8, 16, or a multiple of 16, up to 1696. | `number` | `96` | no |
| aoss\_min\_ocu | Minimum OCUs for both indexing and search on the NEXTGEN collection group. Set to 0 for NEXTGEN scale-to-zero. Valid NEXTGEN values: 0, 2, 4, 8, 16, or multiples of 16, up to 1696. Mirrors CDK context `aoss_min_ocu`. CAUTION with 0: indexing capacity can scale to zero, so under load the NEXTGEN circuit breaker sheds bulk writes with HTTP 429. Ingest re-submits and fails LOUD on unrecoverable partial writes (upstream #173), but 0 makes throttling far more likely. Use a non-zero floor (e.g. 2) for ingest-heavy environments. | `number` | `2` | no |
| component | Component tag applied to every resource in this module. | `string` | `"foundation"` | no |
| neptune\_instance\_class | Instance class for the Neptune primary writer. Default db.r8g.large matches upstream CDK; override via `-var 'neptune_instance_class=db.r8g.xlarge'` for dev-benchmark environments where SPARQL under concurrent reasoning/metric load has OOM'd (MemoryLimitExceededException). NG.9 — never silently downgrade; only raise. | `string` | `"db.r8g.large"` | no |

## Outputs

| Name | Description |
|------|-------------|
| athena\_results\_bucket\_arn | ARN of the Athena query results bucket. |
| athena\_results\_bucket\_name | Name of the Athena query results bucket. |
| athena\_spill\_bucket\_arn | ARN of the Athena federated connector spill bucket. |
| athena\_spill\_bucket\_name | Name of the Athena federated connector spill bucket. |
| neptune\_cluster\_arn | Neptune data-access ARN built from the cluster resource ID (for IAM policies). |
| neptune\_cluster\_endpoint | Neptune cluster writer endpoint (host reachable from the VPC). |
| neptune\_cluster\_identifier | Neptune cluster identifier. |
| neptune\_port | Neptune Gremlin/SPARQL port. |
| ontology\_artifacts\_bucket\_arn | ARN of the ontology artifacts bucket. |
| ontology\_artifacts\_bucket\_name | Name of the ontology artifacts bucket. |
| opensearch\_collection\_arn | OpenSearch Serverless collection ARN (for IAM policies). |
| opensearch\_collection\_endpoint | OpenSearch Serverless collection endpoint. |
| opensearch\_collection\_name | OpenSearch Serverless collection name. |
<!-- END_TF_DOCS -->
