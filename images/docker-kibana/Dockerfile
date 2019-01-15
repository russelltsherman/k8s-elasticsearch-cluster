FROM node:8.14.0-stretch-slim

ARG VERSION
ENV KIBANA_VERSION=$VERSION

ENV LOGTRAIL_VERSION 0.1.30

RUN apt-get update -q && \
    apt-get install -q -y --no-install-recommends ca-certificates curl && \
    echo "Downloading Kibana version$KIBANA_VERSION " && \
    curl -Lkj https://artifacts.elastic.co/downloads/kibana/kibana-${KIBANA_VERSION}-linux-x86_64.tar.gz | tar zx -C /opt && \
    mv /opt/kibana-${KIBANA_VERSION}-linux-x86_64 /opt/kibana && \
    rm -rf /opt/kibana/node && \
    mkdir -p /opt/kibana/node/bin && \
    ln -sf /usr/local/bin/node /opt/kibana/node/bin/node && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN /opt/kibana/bin/kibana-plugin install https://github.com/sivasamyk/logtrail/releases/download/v${LOGTRAIL_VERSION}/logtrail-${KIBANA_VERSION}-${LOGTRAIL_VERSION}.zip

ADD ./run.sh /run.sh

EXPOSE 5601

ENTRYPOINT /run.sh
