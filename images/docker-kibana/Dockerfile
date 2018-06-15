FROM alpine:3.6

ARG VERSION
ENV KIBANA_VERSION=$VERSION

ENV LOGTRAIL_VERSION 0.1.27

RUN apk --update add curl && \
    mkdir /opt && \
    curl -s https://artifacts.elastic.co/downloads/kibana/kibana-${KIBANA_VERSION}-linux-x86_64.tar.gz | tar zx -C /opt && \
    apk add nodejs && \
    mv /opt/kibana-${KIBANA_VERSION}-linux-x86_64 /opt/kibana && \
    rm -rf /opt/kibana/node && \
    mkdir -p /opt/kibana/node/bin && \
    ln -sf /usr/bin/node /opt/kibana/node/bin/node && \
    apk del curl && \
    rm -rf /var/cache/apk/*

# Logtrail not available for 6.3
#RUN /opt/kibana/bin/kibana-plugin install https://github.com/sivasamyk/logtrail/releases/download/v${LOGTRAIL_VERSION}/logtrail-${KIBANA_VERSION}-${LOGTRAIL_VERSION}.zip

ADD ./run.sh /run.sh

EXPOSE 5601

ENTRYPOINT /run.sh


