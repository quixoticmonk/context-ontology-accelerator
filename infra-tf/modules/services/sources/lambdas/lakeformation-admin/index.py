# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
"""Merge a role into the Lake Formation DataLakeAdmins list.

Invoked once per Terraform apply from stack 40-sources via the
`aws_lambda_invocation` resource. Idempotent: adding an already-present
admin is a no-op; removing an absent admin is a no-op.

Event schema:
    {
        "action":   "add" | "remove",
        "role_arn": "arn:aws:iam::...:role/..."
    }

Handles the classic IAM eventual-consistency window (LF returns
`InvalidInputException: Invalid principal` when a fresh role hasn't
propagated yet) with bounded exponential backoff.
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
RETRY_ATTEMPTS = 6
RETRY_BASE_SECONDS = 10


_TF_ACTION_MAP = {"create": "add", "update": "add", "delete": "remove"}


def handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    # aws_lambda_invocation with lifecycle_scope="CRUD" injects `tf.action`
    # of "create" / "update" / "delete". Map that to our merge/unmerge
    # semantics, falling back to an explicit `action` in the input.
    tf_action = (event.get("tf") or {}).get("action")
    if tf_action in _TF_ACTION_MAP:
        action = _TF_ACTION_MAP[tf_action]
    else:
        action = event.get("action", "add")

    role_arn = event["role_arn"]
    if action not in {"add", "remove"}:
        raise ValueError(f"unsupported action: {action}")

    client = boto3.client("lakeformation", region_name=REGION)
    settings = _get_settings(client)
    admins = settings.setdefault("DataLakeAdmins", []) or []
    present = any(a.get("DataLakePrincipalIdentifier") == role_arn for a in admins)

    if action == "add":
        if present:
            log.info("%s is already an admin; nothing to do", role_arn)
            return {"changed": False, "role_arn": role_arn}
        admins.append({"DataLakePrincipalIdentifier": role_arn})
    else:
        if not present:
            log.info("%s is not an admin; nothing to remove", role_arn)
            return {"changed": False, "role_arn": role_arn}
        settings["DataLakeAdmins"] = [
            a for a in admins if a.get("DataLakePrincipalIdentifier") != role_arn
        ]

    _put_settings_with_retry(client, settings)
    log.info("%s => %sd as Lake Formation admin", role_arn, action)
    return {"changed": True, "role_arn": role_arn}


def _get_settings(client: Any) -> dict[str, Any]:
    try:
        resp = client.get_data_lake_settings()
        return resp.get("DataLakeSettings") or {}
    except ClientError as exc:
        if exc.response["Error"]["Code"] in {"EntityNotFoundException"}:
            return {}
        raise


def _put_settings_with_retry(client: Any, settings: dict[str, Any]) -> None:
    for attempt in range(1, RETRY_ATTEMPTS + 1):
        try:
            client.put_data_lake_settings(DataLakeSettings=settings)
            return
        except ClientError as exc:
            msg = exc.response.get("Error", {}).get("Message", "")
            code = exc.response.get("Error", {}).get("Code", "")
            if code == "InvalidInputException" and "Invalid principal" in msg:
                delay = RETRY_BASE_SECONDS * attempt
                log.warning(
                    "attempt %d: LF says invalid principal (IAM propagation); sleeping %ds",
                    attempt,
                    delay,
                )
                time.sleep(delay)
                continue
            raise
    raise RuntimeError("put_data_lake_settings failed after retries")
