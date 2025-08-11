# Multi-stage build for AI-Streamliner Control Tower
FROM ubuntu:22.04 AS base

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV KUBECONFIG=/root/.kube/config
ENV PATH="/usr/local/bin:${PATH}"

# Install base dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    jq \
    ca-certificates \
    apt-transport-https \
    gnupg \
    lsb-release \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI (for potential Docker-in-Docker scenarios)
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update && apt-get install -y docker-ce-cli && rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Install kustomize
RUN curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash \
    && mv kustomize /usr/local/bin/

# Install helm
RUN curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list \
    && apt-get update && apt-get install -y helm && rm -rf /var/lib/apt/lists/*

# Install kind (for local testing scenarios)
RUN curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 \
    && chmod +x ./kind \
    && mv ./kind /usr/local/bin/kind

# Install yq for YAML processing
RUN wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    && chmod +x /usr/local/bin/yq

# Build stage - prepare deployment artifacts
FROM base AS builder

# Copy the AI-Streamliner source code
COPY . /src/ai-streamliner
WORKDIR /src/ai-streamliner

# Clone Kubeflow manifests (matching your current approach)
RUN git clone --depth=1 https://github.com/kubeflow/manifests.git /src/kubeflow-manifests

# Clone Kubeflow source for custom centraldashboard
RUN git clone --depth=1 https://github.com/kubeflow/kubeflow.git /src/kubeflow

# Apply custom centraldashboard theme and branding
RUN cp kubeflow-theme/kubeflow-palette.css /src/kubeflow/components/centraldashboard/public/kubeflow-palette.css && \
    cp kubeflow-theme/logo.svg /src/kubeflow/components/centraldashboard/public/assets/logo.svg && \
    cp kubeflow-theme/favicon.ico /src/kubeflow/components/centraldashboard/public/assets/favicon.ico && \
    cd /src/kubeflow/components/centraldashboard && \
    find . \( -name '*.js' -o -name '*.ts' -o -name '*.css' -o -name '*.html' -o -name '*.json' \) -exec sed -i 's/007dfc/fc0000/g' {} + && \
    find . \( -name '*.js' -o -name '*.ts' -o -name '*.css' -o -name '*.html' -o -name '*.json' \) -exec sed -i 's/003c75/750000/g' {} + && \
    find . \( -name '*.js' -o -name '*.ts' -o -name '*.css' -o -name '*.html' -o -name '*.json' \) -exec sed -i 's/2196f3/f32121/g' {} + && \
    find . \( -name '*.js' -o -name '*.ts' -o -name '*.css' -o -name '*.html' -o -name '*.json' \) -exec sed -i 's/0a3b71/3b0a0a/g' {} + && \
    sed -i 's/<title>Kubeflow Central Dashboard<\/title>/<title>AI Streamliner<\/title>/' public/index.html

# Fix the BUILD_VERSION issue by replacing it with a fixed string
RUN cd /src/kubeflow/components/centraldashboard && \
    sed -i "s/BUILD_VERSION/'ai-streamliner-v1.0'/g" public/components/main-page.js

# Prepare centraldashboard overlays for kustomize
RUN mkdir -p /src/kubeflow-manifests/apps/centraldashboard/overlays/apps/patches && \
    cp /src/ai-streamliner/kubeflow-config/kustomization.yaml /src/kubeflow-manifests/apps/centraldashboard/overlays/apps/kustomization.yaml && \
    cp /src/ai-streamliner/kubeflow-config/apps/patches/configmap.yaml /src/kubeflow-manifests/apps/centraldashboard/overlays/apps/patches/configmap.yaml

# Pre-build kustomize artifacts to speed up deployment (keeping your working approach)
RUN cd /src/kubeflow-manifests && \
    kustomize build example > /tmp/kubeflow-manifests.yaml && \
    sed -i 's|image: ghcr.io/kubeflow/kubeflow/central-dashboard:.*|image: centraldashboard:dev|' /tmp/kubeflow-manifests.yaml

# Production stage
FROM base AS production

# Copy built artifacts
COPY --from=builder /src/ai-streamliner /app/ai-streamliner
COPY --from=builder /src/kubeflow-manifests /app/kubeflow-manifests
COPY --from=builder /src/kubeflow /app/kubeflow
COPY --from=builder /tmp/kubeflow-manifests.yaml /app/artifacts/

# Create required directories
RUN mkdir -p /app/scripts /app/artifacts /app/logs

# Copy scripts
COPY scripts/ /app/scripts/

# Make scripts executable
RUN chmod +x /app/scripts/*.sh

# Set working directory
WORKDIR /app

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD kubectl cluster-info >/dev/null 2>&1 || exit 1

# Labels for container metadata
LABEL maintainer="ArdentMC"
LABEL version="1.0.0"
LABEL description="AI-Streamliner Control Tower - Deploy Kubeflow, MLflow, Aim, and LakeFS"
LABEL vendor="ArdentMC"

# Expose common ports for development/testing
EXPOSE 8080 8081 8082 8083

# Set entrypoint
ENTRYPOINT ["/app/scripts/entrypoint.sh"]