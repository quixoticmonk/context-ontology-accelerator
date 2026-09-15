# Build context: monorepo root ($CI_PROJECT_DIR)
#   docker build -f packages/ontology-engine/Dockerfile .
# Pin to digest to prevent supply-chain attacks via tag mutation. The pin is for
# supply-chain integrity only, NOT patch currency: the previous digest sat at
# openssl 3.5.6-1~deb13u2 and Inspector flagged 10 CVEs against it. Patch level
# now comes from the apt-get upgrade below, so a stale pin can no longer hold
# back an OS security fix.
# python:3.12-slim, digest resolved from the tag on 2026-09-01.
FROM --platform=linux/amd64 public.ecr.aws/docker/library/python:3.12-slim@sha256:e5c9fa26ffb76e11e0f054f30dc2523a2f9693f0c36c0cf1e39b27e152d899fc

WORKDIR /app

# Java runtime for owlready2 HermiT reasoner (tier-1 validation).
# `upgrade` runs after our own installs so it also patches what we just pulled
# in. Debian has no apt equivalent of `dnf update --security`, but on a stable
# release the configured suites are trixie + trixie-updates + trixie-security,
# so a plain `upgrade` is security/point-release only. Use `upgrade`, never
# `dist-upgrade` — the latter may remove packages to satisfy dependencies.
RUN apt-get update && \
    apt-get install -y --no-install-recommends default-jre-headless curl && \
    apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN useradd --no-create-home --shell /bin/false appuser

# Install shared common library
COPY libs/common/ /tmp/common/
RUN pip install --no-cache-dir /tmp/common/ && rm -rf /tmp/common/

# Install Smithy-generated control-plane server package
# (provides shared API enums/models — single source of truth for control-plane contracts)
COPY smithy-generated/control-plane-python-server/ /tmp/control-plane-server/
RUN pip install --no-cache-dir /tmp/control-plane-server/ && rm -rf /tmp/control-plane-server/

# Install ontology-engine dependencies
COPY packages/ontology-engine/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source
COPY --chown=appuser:appuser packages/ontology-engine/src/ ./src/
COPY --chown=appuser:appuser packages/ontology-engine/tests/fixtures/data-catalog/sample_data/ ./fixtures/sample_data/
RUN mkdir -p /app/output /app/data && chown appuser:appuser /app/output /app/data
ENV PYTHONPATH=/app/src

USER appuser
EXPOSE 8001

# Health check hits the FastAPI /health endpoint (see main.py line 189).
# ECS Fargate does not use container-level HEALTHCHECK — it uses the ALB/NLB
# target group health check — but keeping this here means the same image
# works when run standalone (docker run, docker-compose, local dev) and
# satisfies CKV_DOCKER_2 supply-chain hygiene.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -fsS "http://localhost:${PORT:-8001}/health" || exit 1

CMD ["sh", "-c", "uvicorn coa_ontology.main:app --host 0.0.0.0 --port ${PORT:-8001}"]
