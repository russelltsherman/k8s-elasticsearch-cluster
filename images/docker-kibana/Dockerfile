FROM alpine:3.6

ENV KIBANA_VERSION 6.2.3-linux-x86_64

RUN apk --update add curl && \
    mkdir /opt && \
    curl -s https://artifacts.elastic.co/downloads/kibana/kibana-${KIBANA_VERSION}.tar.gz | tar zx -C /opt && \
    apk add nodejs && \
    mv /opt/kibana-${KIBANA_VERSION} /opt/kibana \
    rm -rf /opt/kibana/node && \
    mkdir -p /opt/kibana/node/bin && \
    ln -sf /usr/bin/node /opt/kibana/node/bin/node && \
    apk del curl && \
    rm -rf /var/cache/apk/*

ADD ./run.sh /run.sh

EXPOSE 5601

ENTRYPOINT /run.sh
