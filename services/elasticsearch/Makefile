
DOCKER_ORG=russellsherman
DOCKER_IMAGE=elasticsearch
DOCKER_VERSION=6.6.0

build:
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg VERSION=$(DOCKER_VERSION) \
		--tag $(DOCKER_ORG)/$(DOCKER_IMAGE):$(DOCKER_VERSION) \
		--push \
		.