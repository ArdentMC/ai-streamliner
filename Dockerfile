# Multi-stage build for AI-Streamliner Control Tower
FROM ubuntu:22.04 AS base

# Every tool is pinned. An unpinned download makes two builds of the same
# source produce different images, which cannot be attested to a marketplace
# scan: the thing that was scanned is not the thing that ships.
ARG KUBECTL_VERSION=v1.37.3
ARG KUSTOMIZE_VERSION=v5.8.3
ARG HELM_VERSION=v3.22.1
ARG YQ_VERSION=v4.54.3

# buildx sets TARGETARCH per platform (amd64, arm64). The downloads below used
# to name amd64 outright, so the arm64 image in the multi-arch index was built
# carrying binaries that cannot execute on it.
ARG TARGETARCH

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
RUN curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" \
    && curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl.sha256" \
    && echo "$(cat kubectl.sha256)  kubectl" | sha256sum -c - \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl kubectl.sha256

# Install kustomize
RUN curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_${TARGETARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin kustomize \
    && chmod 0755 /usr/local/bin/kustomize

# Install helm from the project's own release tarball.
#
# The apt repository at baltocdn.com is no longer usable from any current
# Ubuntu base: it presents a Let's Encrypt chain rooted in "ISRG Root YR",
# which is absent from the ca-certificates shipped in both 22.04 and 24.04, so
# apt cannot verify the index and the build fails with "Unable to locate
# package helm". The release tarball is also pinnable, which the repo was not.
RUN cd /tmp \
    && HELM_TGZ="helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" \
    && curl -fsSLO "https://get.helm.sh/${HELM_TGZ}" \
    && curl -fsSLO "https://get.helm.sh/${HELM_TGZ}.sha256sum" \
    && sha256sum -c "${HELM_TGZ}.sha256sum" \
    && tar -xzf "${HELM_TGZ}" "linux-${TARGETARCH}/helm" \
    && install -o root -g root -m 0755 "linux-${TARGETARCH}/helm" /usr/local/bin/helm \
    && rm -rf "${HELM_TGZ}" "${HELM_TGZ}.sha256sum" "linux-${TARGETARCH}"

# kind is deliberately absent.
#
# It was pinned at v0.20.0, a build from June 2023 carrying the Go 1.20.4
# standard library -- six patch releases before the fix for CVE-2023-39325,
# which is Go's identifier for the HTTP/2 rapid-reset flaw CVE-2023-44487.
# That one binary accounted for 32 HIGH and CRITICAL findings.
#
# Nothing in the shipped image needs it. The deployment script calls kind only
# behind "command -v kind" guards, and it runs against the operator's own
# cluster; the Makefile targets that do create a kind cluster run on a
# developer's machine, not in here.

# Install yq for YAML processing
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${TARGETARCH}" -o /usr/local/bin/yq \
    && chmod 0755 /usr/local/bin/yq

# Build stage - prepare deployment artifacts
FROM base AS builder

# Copy the AI-Streamliner source code
COPY . /src/ai-streamliner
WORKDIR /src/ai-streamliner

# Clone Kubeflow manifests (matching your current approach)
RUN git clone --depth=1 https://github.com/kubeflow/manifests.git /src/kubeflow-manifests

# Clone the Central Dashboard source for the custom theme.
#
# This used to clone kubeflow/kubeflow, whose master branch no longer holds
# components/ at all -- the monorepo was split, and what remains there is
# documentation and a logo. The component moved to kubeflow/dashboard under
# the same internal path, so only the repository name changes here.
RUN git clone --depth=1 https://github.com/kubeflow/dashboard.git /src/kubeflow

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
COPY --from=builder /tmp/kubeflow-manifests.yaml /app/artifacts/

# Only the themed component, at the path the extract script reads. The whole
# Kubeflow monorepo used to land here to deliver this one directory, and every
# lockfile and vendored dependency in the rest of it was surface a scanner had
# to account for in an image that never ran any of it.
COPY --from=builder /src/kubeflow/components/centraldashboard /app/kubeflow/components/centraldashboard

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