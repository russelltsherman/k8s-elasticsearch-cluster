
DOCKER_ORG=russellsherman
DOCKER_IMAGE=fluentd
DOCKER_VERSION=1.9.1

build:
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg VERSION=$(DOCKER_VERSION) \
		--tag $(DOCKER_ORG)/$(DOCKER_IMAGE):$(DOCKER_VERSION) \
		--push \
		.