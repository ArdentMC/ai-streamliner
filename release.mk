# DevOps/ECR Makefile for building and publishing multi-arch images
# Usage examples:
#   make -f Makefile.ecr image-login REGISTRY_ID=709825985650 REGION=us-east-1
#   make -f Makefile.ecr image-release VERSION=1.0.3 REGISTRY_ID=709825985650 REPO=ardent-mc/aistreamliner
#   make -f Makefile.ecr image-verify VERSION=1.0.3 REGISTRY_ID=709825985650 REPO=ardent-mc/aistreamliner
#   make -f Makefile.ecr image-digests VERSION=1.0.3 REGISTRY_ID=709825985650 REPO=ardent-mc/aistreamliner

# Media types are pinned to Docker's rather than left to the builder.
#
# With the containerd image store (driver-type io.containerd.snapshotter.v1,
# now the Docker Desktop default) buildx writes OCI media types for the config,
# the per-arch manifests and the index. Before that store existed the same
# commands here produced Docker media types, which is what every release up to
# 1.0.5 carries. oci-mediatypes=false keeps a release built on a current Docker
# identical in shape to those, rather than having the shape of the asset depend
# on which machine cut it.

# ----- Configuration (override via env or CLI) -----
REGION               ?= us-east-1
REGISTRY_ID          ?= 000000000000
REGISTRY              = $(REGISTRY_ID).dkr.ecr.$(REGION).amazonaws.com
REPO                 ?= aistreamliner
IMAGE                 = $(REGISTRY)/$(REPO)
VERSION              ?= latest
NO_CACHE             ?= true
PROVENANCE           ?= false
AMD                   = linux/amd64
ARM                   = linux/arm64
AWS                   = aws --no-cli-pager
DOCKER_BUILDX         = docker buildx build
DOCKER_MANIFEST       = docker manifest

.PHONY: image-login image-build-amd64 image-build-arm64 image-push-manifest image-release image-verify image-digests image-clean-manifest

# Log in to ECR once per session
image-login:
	$(AWS) ecr get-login-password --region $(REGION) | docker login --username AWS --password-stdin $(REGISTRY)

# Build & push single-arch images
image-build-amd64:
	$(DOCKER_BUILDX) \
		--platform $(AMD) \
		$(if $(filter true,$(NO_CACHE)),--no-cache,) \
		$(if $(filter false,$(PROVENANCE)),--provenance=false,) \
		--output type=image,name=$(IMAGE):$(VERSION)-amd64,push=true,oci-mediatypes=false \
		.

image-build-arm64:
	$(DOCKER_BUILDX) \
		--platform $(ARM) \
		$(if $(filter true,$(NO_CACHE)),--no-cache,) \
		$(if $(filter false,$(PROVENANCE)),--provenance=false,) \
		--output type=image,name=$(IMAGE):$(VERSION)-arm64,push=true,oci-mediatypes=false \
		.

# Create & push multi-arch index that references only amd64 and arm64 images
image-push-manifest:
	$(DOCKER_MANIFEST) create $(IMAGE):$(VERSION) \
		$(IMAGE):$(VERSION)-amd64 \
		$(IMAGE):$(VERSION)-arm64
	$(DOCKER_MANIFEST) annotate $(IMAGE):$(VERSION) $(IMAGE):$(VERSION)-amd64 --os linux --arch amd64
	$(DOCKER_MANIFEST) annotate $(IMAGE):$(VERSION) $(IMAGE):$(VERSION)-arm64 --os linux --arch arm64
	$(DOCKER_MANIFEST) push $(IMAGE):$(VERSION)

# End-to-end release: login, build both arch images, create & push index
image-release: image-login image-build-amd64 image-build-arm64 image-push-manifest
	@echo "Published $(IMAGE):$(VERSION) (multi-arch), and per-arch tags: $(IMAGE):$(VERSION)-amd64, $(IMAGE):$(VERSION)-arm64"

# Verify index contents (should show exactly linux/amd64 and linux/arm64)
image-verify:
	$(AWS) ecr batch-get-image \
		--region $(REGION) \
		--registry-id $(REGISTRY_ID) \
		--repository-name $(REPO) \
		--image-id imageTag=$(VERSION) \
		--accepted-media-types application/vnd.oci.image.index.v1+json application/vnd.docker.distribution.manifest.list.v2+json \
		--query 'images[0].imageManifest' --output text | jq -r '.manifests[] | "\(.platform.os)/\(.platform.architecture) \(.digest)"'

# Output per-arch image digests (give these to scanners/Marketplace)
image-digests:
	@echo "amd64 digest:" && $(AWS) ecr describe-images --region $(REGION) --registry-id $(REGISTRY_ID) --repository-name $(REPO) --image-ids imageTag=$(VERSION)-amd64 --query 'imageDetails[0].imageDigest' --output text
	@echo "arm64 digest:" && $(AWS) ecr describe-images --region $(REGION) --registry-id $(REGISTRY_ID) --repository-name $(REPO) --image-ids imageTag=$(VERSION)-arm64 --query 'imageDetails[0].imageDigest' --output text

# Remove local multi-arch manifest reference (remote image remains)
image-clean-manifest:
	-$(DOCKER_MANIFEST) rm $(IMAGE):$(VERSION) 2>/dev/null || true

