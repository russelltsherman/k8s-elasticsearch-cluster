#FROM carlosedp/docker-elasticsearch:6.2.2
FROM carlosedp/docker-elasticsearch-debian:6.2.2-arm64

# Override config, otherwise plug-in install will fail
ADD config /elasticsearch/config

# Set environment
ENV DISCOVERY_SERVICE elasticsearch-discovery

# Kubernetes requires swap is turned off, so memory lock is redundant
ENV MEMORY_LOCK false
