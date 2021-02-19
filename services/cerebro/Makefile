
DOCKER_ORG=russellsherman
DOCKER_IMAGE=cerebro
DOCKER_VERSION=0.8.1

build:
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg VERSION=$(DOCKER_VERSION) \
		--tag $(DOCKER_ORG)/$(DOCKER_IMAGE):$(DOCKER_VERSION) \
		--push \
		.