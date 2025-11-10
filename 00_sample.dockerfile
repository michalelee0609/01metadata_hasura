# ========================================
# Hasura GraphQL Engine + Python 3.9 + CLI Tools
# Base image: Hasura v2.48.0
# ========================================

FROM hasura/graphql-engine:v2.48.0

# Set non-interactive frontend and timezone
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Hong_Kong

# Install required system packages
RUN apt-get update && apt-get install -y software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update \
    && apt-get install -y \
        python3.9 \
        python3.9-dev \
        python3.9-venv \
        curl \
        python3-pip \
        gettext \
        yamllint \
        tree \
        dos2unix \
        util-linux \
    && rm -rf /var/lib/apt/lists/*

# Install yq (YAML processor) - mandatory
RUN curl -L https://github.com/mikefarah/yq/releases/download/v4.42.1/yq_linux_amd64 \
    -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# Install Python dependencies - mandatory
RUN pip3 install --no-cache-dir PyYAML

# Create project directory structure (customize as needed)
RUN mkdir -p \
    /hasura-project/user_metadata \
    /hasura-project/05-logs/hasura \
    /hasura-project/01-config/hasura/dos2unix \
    /hasura-project/01-config/hasura/metadata \
    /hasura-project/.internal_cache

# Set directory permissions
# - Config: read-only for app, writable by owner
# - Logs & cache: writable by group (for container user)
RUN chmod -R 755 /hasura-project/01-config && \
    chmod -R 775 /hasura-project/05-logs && \
    chmod -R 775 /hasura-project/.internal_cache

# Copy initialization script
COPY 00-docker/init-hasura.sh /hasura-project/init-hasura.sh
RUN chmod +x /hasura-project/init-hasura.sh

# Install Hasura CLI (version must match engine)
RUN curl -L https://github.com/hasura/graphql-engine/releases/download/v2.48.0/cli-hasura-linux-amd64 \
    -o /usr/local/bin/hasura-cli \
    && chmod +x /usr/local/bin/hasura-cli

# Hasura service configuration
ENV HASURA_GRAPHQL_SERVER_PORT=9096 \
    HASURA_GRAPHQL_SERVER_HOST=0.0.0.0 \
    HASURA_GRAPHQL_ENABLE_CONSOLE=true \
    HASURA_GRAPHQL_DATABASE_URL=${HASURA_GRAPHQL_DATABASE_URL}

# Expose ports
# 9096: Hasura GraphQL Engine
# XXX: Custom metrics/health endpoint (if enabled in init script like what i did )
EXPOSE 9096 10096

# Health check
# Uses Hasura's built-in /healthz endpoint (reliable)
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -f http://localhost:10096/healthz || exit 1

# Entry point
CMD ["/hasura-project/init-hasura.sh"]