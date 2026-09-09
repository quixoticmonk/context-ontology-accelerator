# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Amazon Bedrock Guardrails for content safety filtering across all
# LLM-facing paths (LLD §2.2.4). Ports the CDK GuardrailStack.
#
# Two guardrails are provisioned:
#   - this (primary):  HIGH PROMPT_ATTACK sensitivity for user query
#       evaluation, plus PII anonymization applied at the LLM input/output
#       boundary (mask PII in responses).
#   - retrieval:       content-screening for ingested documents + retrieved
#       chunks (ingestion-time and query-time). Content-safety only — no PII
#       policy — so document screening never quarantines or masks named
#       entities, which are the primary payload of the knowledge graph /
#       ontology.
#
# The CDK created these via bedrock.CfnGuardrail with no explicit
# RemovalPolicy (CloudFormation default = delete on stack delete), so no
# lifecycle prevent_destroy is added here.

# ── Primary guardrail: HIGH sensitivity for user queries ─────────────
resource "aws_bedrock_guardrail" "this" {
  name                      = "${var.name_prefix}-guardrail"
  blocked_input_messaging   = "Request blocked by content filter."
  blocked_outputs_messaging = "Response blocked by content filter."

  content_policy_config {
    filters_config {
      type            = "SEXUAL"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "INSULTS"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }
  }

  # PII is anonymized (not blocked) at the LLM input/output boundary so
  # personal data is masked in model responses to agents. Intentionally
  # NOT applied to the retrieval guardrail (see below).
  sensitive_information_policy_config {
    pii_entities_config {
      type           = "EMAIL"
      action         = "ANONYMIZE"
      input_action   = "ANONYMIZE"
      output_action  = "ANONYMIZE"
      input_enabled  = true
      output_enabled = true
    }
    pii_entities_config {
      type           = "PHONE"
      action         = "ANONYMIZE"
      input_action   = "ANONYMIZE"
      output_action  = "ANONYMIZE"
      input_enabled  = true
      output_enabled = true
    }
    pii_entities_config {
      type           = "NAME"
      action         = "ANONYMIZE"
      input_action   = "ANONYMIZE"
      output_action  = "ANONYMIZE"
      input_enabled  = true
      output_enabled = true
    }
    pii_entities_config {
      type           = "US_SOCIAL_SECURITY_NUMBER"
      action         = "ANONYMIZE"
      input_action   = "ANONYMIZE"
      output_action  = "ANONYMIZE"
      input_enabled  = true
      output_enabled = true
    }
    pii_entities_config {
      type           = "CREDIT_DEBIT_CARD_NUMBER"
      action         = "ANONYMIZE"
      input_action   = "ANONYMIZE"
      output_action  = "ANONYMIZE"
      input_enabled  = true
      output_enabled = true
    }
  }

  tags = {
    Component = var.component
  }
}

resource "aws_bedrock_guardrail_version" "this" {
  guardrail_arn = aws_bedrock_guardrail.this.guardrail_arn
  description   = "Initial published version"
}

# ── Retrieval guardrail: tuned for business document screening ───────
# Used by both ingestion-time (ApplyGuardrail in KG Build) and query-time
# (ApplyGuardrail before synthesis) content screening. Per-filter tuning:
#   PROMPT_ATTACK: MEDIUM (core defense; HIGH false-positives on
#     instruction-like business language)
#   HATE/SEXUAL:   HIGH (no legitimate business reason for this content)
#   VIOLENCE/INSULTS: MEDIUM (legal/insurance docs reference harm/
#     adversarial language)
#   MISCONDUCT:    LOW (insurance docs discuss fraud/theft routinely;
#     only block HIGH-confidence)
# No sensitive_information_policy_config: anonymizing PII during content
# screening would drop every document containing a name and gut KG/ontology
# construction.
resource "aws_bedrock_guardrail" "retrieval" {
  name                      = "${var.name_prefix}-retrieval-guardrail"
  blocked_input_messaging   = "Retrieved content blocked by filter."
  blocked_outputs_messaging = "Retrieved content blocked by filter."

  content_policy_config {
    filters_config {
      type            = "SEXUAL"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
    }
    filters_config {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "INSULTS"
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
    }
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "LOW"
      output_strength = "LOW"
    }
    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "MEDIUM"
      output_strength = "NONE"
    }
  }

  tags = {
    Component = var.component
  }
}

resource "aws_bedrock_guardrail_version" "retrieval" {
  guardrail_arn = aws_bedrock_guardrail.retrieval.guardrail_arn
  description   = "Initial published version"
}

# ── SSM: guardrail IDs + versions for runtime consumers ──────────────
# Mirrors the CDK StringParameter writes so the shell scripts and runtime
# services that read these paths continue to work unchanged.
resource "aws_ssm_parameter" "guardrail_id" {
  name  = "${var.ssm_prefix}/bedrock/guardrail-id"
  type  = "String"
  value = aws_bedrock_guardrail.this.guardrail_id

  tags = { Component = var.component }
}

resource "aws_ssm_parameter" "guardrail_version" {
  name  = "${var.ssm_prefix}/bedrock/guardrail-version"
  type  = "String"
  value = aws_bedrock_guardrail.this.version

  tags = { Component = var.component }
}

resource "aws_ssm_parameter" "retrieval_guardrail_id" {
  name  = "${var.ssm_prefix}/bedrock/retrieval-guardrail-id"
  type  = "String"
  value = aws_bedrock_guardrail.retrieval.guardrail_id

  tags = { Component = var.component }
}

resource "aws_ssm_parameter" "retrieval_guardrail_version" {
  name  = "${var.ssm_prefix}/bedrock/retrieval-guardrail-version"
  type  = "String"
  value = aws_bedrock_guardrail.retrieval.version

  tags = { Component = var.component }
}
