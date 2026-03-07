# =============================================================================
# Parrot MCP Server - Simplified
# =============================================================================
# Build:
#   docker build -t mcp-server .
#
# Run:
#   docker run --rm -p 8081:8081 --env-file env/.env.api mcp-server
# =============================================================================

FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DEBIAN_FRONTEND=noninteractive \
    ENV=production

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ make libffi-dev libssl-dev libpq-dev git curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# App setup
WORKDIR /app
COPY . .

# Create venv and install dependencies from PyPI
RUN make venv && uv sync

# navconfig expects env/<ENV>/.env — in K8s this is mounted as a Secret
# Only create base env/ directory; K8s will mount the correct env/<environment>/.env
RUN rm -rf env && mkdir -p env

# Create the configuration directory
RUN mkdir -p /app/mcp_servers

# Create environment configuration
RUN kardex create
RUN touch env/.env

COPY mcp_servers/server.yaml /app/mcp_servers/server.yaml

# Cleanup build deps to reduce image size
RUN apt-get purge -y gcc g++ make libffi-dev libssl-dev libpq-dev git \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /root/.cache

ENV VIRTUAL_ENV=/app/.venv \
    PATH="/app/.venv/bin:$PATH" \
    SITE_ROOT=/app \
    BASE_DIR=/app

EXPOSE 8081

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8081/ || exit 1

CMD ["parrot", "mcp", "--config", "mcp_servers/server.yaml"]