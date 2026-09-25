#!/usr/bin/env python3
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
"""
Merges the control-plane + data-layer OpenAPI specs into one and
substitutes the CorsOrigin placeholder. The Terraform api module reads
the merged output and injects Lambda proxy integrations per path in
HCL, so this script deliberately does NOT touch integrations or
authorizer parameters.

Inputs:
  --control-plane   Path to ControlPlaneService.openapi.json
  --data-layer      Path to DataLayerService.openapi.json
  --cors-origin     CORS Access-Control-Allow-Origin value to substitute
                    for `${CorsOrigin}` placeholders
  --output          Where to write merged.json

Merge semantics (matches CDK ApiStack):
  - path.method entries from both specs are combined; when a path
    exists in both specs, methods from both are unioned. A path+method
    defined by BOTH specs is a modelling error, not a conflict to
    resolve silently — API Gateway takes one integration per path, so
    a plain object spread would publish the losing operation's contract
    in front of the winning operation's handler. Fail loudly instead.
  - components.schemas are combined
  - info.description is replaced with a static description
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def read_spec(path: Path, replacements: dict[str, str]) -> dict:
    """Read a JSON OpenAPI file and substitute ${key} placeholders."""
    content = path.read_text()
    for key, value in replacements.items():
        content = content.replace("${" + key + "}", value)
    return json.loads(content)


def merge_specs(cp_spec: dict, dl_spec: dict) -> dict:
    """Merge data-layer spec into control-plane.

    Fails with exit code 1 if both specs define the same path+method,
    matching the CDK `mergeOpenApiPaths` guard: a shared path+method
    resolves to a single API Gateway integration, so the losing
    operation's contract would be published in front of the winning
    operation's handler — an API whose documentation contradicts its
    behaviour, with a green build. Give the duplicate its own path or
    remove it from its service.
    """
    merged = json.loads(json.dumps(cp_spec))  # deep copy

    merged.setdefault("paths", {})
    for path, methods in (dl_spec.get("paths") or {}).items():
        existing = merged["paths"].get(path)
        if existing is None:
            merged["paths"][path] = methods
            continue

        clashes = sorted(m for m in methods if m in existing)
        if clashes:
            print(
                f"OpenAPI merge conflict on \"{path}\": [{', '.join(clashes)}] "
                "defined by both specs. A path+method resolves to a single "
                "API Gateway integration, so give the duplicate operation "
                "its own path or remove it from its service.",
                file=sys.stderr,
            )
            sys.exit(1)

        merged["paths"][path] = {**existing, **methods}

    if "schemas" in (dl_spec.get("components") or {}):
        merged.setdefault("components", {}).setdefault("schemas", {}).update(
            dl_spec["components"]["schemas"]
        )

    merged.setdefault("info", {})[
        "description"
    ] = "Context Ontology Accelerator REST API — namespace, ingestion, and query management."

    return merged


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--control-plane", required=True, type=Path)
    parser.add_argument("--data-layer", required=True, type=Path)
    parser.add_argument("--cors-origin", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    replacements = {"CorsOrigin": args.cors_origin}
    cp = read_spec(args.control_plane, replacements)
    dl = read_spec(args.data_layer, replacements)

    merged = merge_specs(cp, dl)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(merged, indent=2))

    n_paths = len(merged.get("paths", {}))
    n_schemas = len(merged.get("components", {}).get("schemas", {}))
    print(f"==> wrote {args.output} ({n_paths} paths, {n_schemas} schemas)", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
