# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
"""Patch API Gateway Gateway-Response CORS + force a stage redeployment.

Stack 60-api-edge invokes this after CloudFront comes up so
`Access-Control-Allow-Origin` on 4XX/5XX gateway responses matches the
CF domain (browsers refuse `*` for credentialed CORS requests).

Two-step:
    1. UpdateGatewayResponse on `DEFAULT_4XX` + `DEFAULT_5XX`, setting
       Access-Control-Allow-Origin to `https://<cf-domain>`.
    2. CreateDeployment on the REST API for the target stage — API
       Gateway serves the OLD deployment snapshot until a new one
       exists AND the stage points at it. Passing `stageName` in
       CreateDeployment auto-updates the stage pointer.

Mirrors the CDK ancestor's `UpdateApiCors4XX` + `UpdateApiCors5XX` +
`RedeployApi` custom resources; the TF equivalent lives in
`infra-tf/modules/foundation/web/api_cors_patch.tf`.

Event schema:
    {
        "rest_api_id": "nc24h7w2nj",
        "stage_name":  "prod",
        "origin":      "https://d1uez2kb8lo309.cloudfront.net"
    }
"""

from __future__ import annotations

import logging
import os
import time
from typing import Any

import boto3
from botocore.exceptions import ClientError

log = logging.getLogger()
log.setLevel(logging.INFO)

REGION = os.environ.get("AWS_REGION", "us-east-1")

_GATEWAY_RESPONSE_TYPES = ("DEFAULT_4XX", "DEFAULT_5XX")
_HEADER_PATH = "/responseParameters/gatewayresponse.header.Access-Control-Allow-Origin"


def handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    api_id = event["rest_api_id"]
    stage_name = event["stage_name"]
    origin = event["origin"]

    quoted_origin = f"'{origin}'"  # API Gateway wants the value single-quoted
    client = boto3.client("apigateway", region_name=REGION)

    for rtype in _GATEWAY_RESPONSE_TYPES:
        try:
            client.update_gateway_response(
                restApiId=api_id,
                responseType=rtype,
                patchOperations=[{
                    "op": "replace",
                    "path": _HEADER_PATH,
                    "value": quoted_origin,
                }],
            )
            log.info("patched %s CORS origin to %s", rtype, origin)
        except ClientError as exc:
            log.error("update_gateway_response %s failed: %s", rtype, exc)
            raise

    # Force a new deployment so the patched gateway responses go live.
    # Setting stageName in CreateDeployment atomically updates the stage.
    description = f"CORS patch: origin={origin} @ {int(time.time())}"
    deploy = client.create_deployment(
        restApiId=api_id,
        stageName=stage_name,
        description=description,
    )
    log.info("created deployment %s for stage %s", deploy.get("id"), stage_name)

    return {
        "changed": True,
        "deployment_id": deploy.get("id"),
        "origin": origin,
        "gateway_responses_patched": list(_GATEWAY_RESPONSE_TYPES),
    }
