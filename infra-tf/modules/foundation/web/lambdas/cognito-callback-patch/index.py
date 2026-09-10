# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
"""Merge CloudFront callback + logout URLs into a Cognito user pool client.

Stack 60-api-edge invokes this via `action "aws_lambda_invoke"` after the
CloudFront distribution comes up. The web-app's sign-in flow builds a
`redirect_uri=https://<cf-domain>/authenticate/` which Cognito accepts
only when that URL is on the client's `CallbackURLs` allowlist. Since
stack 10-foundation creates the client BEFORE CloudFront exists, this
Lambda patches the allowlist after-the-fact.

Idempotent: appending an already-present URL is a no-op.

Event schema:
    {
        "user_pool_id":  "us-east-1_ABCDEF",
        "client_id":     "1a2b3c4d",
        "callback_url":  "https://d1uez2kb8lo309.cloudfront.net/authenticate/",
        "logout_url":    "https://d1uez2kb8lo309.cloudfront.net/"
    }
"""

from __future__ import annotations

import logging
import os
from typing import Any

import boto3
from botocore.exceptions import ClientError

log = logging.getLogger()
log.setLevel(logging.INFO)

REGION = os.environ.get("AWS_REGION", "us-east-1")

# Fields DescribeUserPoolClient returns that UpdateUserPoolClient rejects
# (read-only or Cognito-managed). Strip before echoing back.
_READ_ONLY_FIELDS = {"LastModifiedDate", "CreationDate"}


def handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    user_pool_id = event["user_pool_id"]
    client_id = event["client_id"]
    callback_url = event["callback_url"]
    logout_url = event.get("logout_url", callback_url.rsplit("/authenticate", 1)[0] + "/")

    client = boto3.client("cognito-idp", region_name=REGION)
    desc = client.describe_user_pool_client(
        UserPoolId=user_pool_id, ClientId=client_id,
    )
    upc = desc["UserPoolClient"]

    current_cb = set(upc.get("CallbackURLs") or [])
    current_lo = set(upc.get("LogoutURLs") or [])
    if callback_url in current_cb and logout_url in current_lo:
        log.info("callback + logout already registered; no update needed")
        return {"changed": False, "callback_url": callback_url}

    new_cb = sorted(current_cb | {callback_url})
    new_lo = sorted(current_lo | {logout_url})

    payload = {k: v for k, v in upc.items() if k not in _READ_ONLY_FIELDS}
    payload["CallbackURLs"] = new_cb
    payload["LogoutURLs"] = new_lo

    try:
        client.update_user_pool_client(**payload)
    except ClientError as exc:
        log.error("update_user_pool_client failed: %s", exc)
        raise

    log.info("Registered callback=%s logout=%s", callback_url, logout_url)
    return {
        "changed": True,
        "callback_url": callback_url,
        "logout_url": logout_url,
        "callback_urls": new_cb,
        "logout_urls": new_lo,
    }
