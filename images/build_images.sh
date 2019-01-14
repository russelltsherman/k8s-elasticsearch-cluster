#!/bin/bash
#
# To update image versions and the Kubernetes manifests edit:
# - ./build_images.sh - #Versions section
# - ./debian-oraclejava/Dockerfile - Versions and download path for new Java
# - ./docker-elasticsearch/Dockerfile - FROM in case of Java update
# - ./docker-kibana/Dockerfile - LOGTRAIL_VERSION line
# - ./fluentd-elasticsearch/Gemfile - Gem versions
# - ./elasticsearch-cerebro/Dockerfile - FROM in case of Java update
# Manifests:
# - es-client.yaml - "image" line
# - es-master.yaml - "image" line
# - es-data-statefulset.yaml - "image" line
# - es-full.yaml - "image" line
# - es-curator_v1beta1.yaml - "image" line
# - fluentd-es-ds.yaml - "image" line
# - kibana.yaml - "image" line
# - cerebro.yaml - "image" line
# - prometheus_exporter/elasticsearch-exporter-deployment.yaml - "image" line

# Versions
JAVA_VERSION=8-172
ES_VERSION=6.5.4
CURATOR_VERSION=5.6.0
FLUENTD_VERSION=1.3.3
CEREBRO_VERSION=0.8.1
EXPORTER_VERSION=1.0.4rc1

REGISTRY=carlosedp

# Architectures
ARCHITECTURES=(arm64)

# Images and respective versions
IMAGES=(debian-oraclejava docker-elasticsearch docker-elasticsearch-kubernetes docker-elasticsearch-curator fluentd-elasticsearch docker-kibana elasticsearch-cerebro elasticsearch-exporter)
VERSIONS=($JAVA_VERSION $ES_VERSION $ES_VERSION $CURATOR_VERSION $FLUENTD_VERSION $ES_VERSION $CEREBRO_VERSION $EXPORTER_VERSION)

num_img=$((${#IMAGES[*]}-1))

CURRENT_ARCH=`dpkg-architecture -q DEB_BUILD_ARCH`
if  [[ -x $(command manifest-tool) ]]; then
    curl -o ./manifest-tool https://github.com/estesp/manifest-tool/releases/download/v0.9.0/manifest-tool-linux-$(CURRENT_ARCH)
    chmod +x manifest-tool
fi

function build_image {
    I=$1
    ARCH_LIST=''
    for ARCH in $ARCHITECTURES; do
        ARCH_LIST="linux/$ARCH $ARCH_LIST"
        IMAGE=${IMAGES[$I]}
        VERSION=${VERSIONS[$I]}
        if [[ ! "$(docker images -q $REGISTRY/$IMAGE:$VERSION-$ARCH 2> /dev/null)" == "" ]]; then
          echo "Image $REGISTRY/$IMAGE:$VERSION-$ARCH already exists, skipping."
          return
        fi
        echo "Building image $REGISTRY/$IMAGE:$VERSION-$ARCH"
        docker build -t $REGISTRY/$IMAGE:$VERSION-$ARCH --build-arg VERSION=$VERSION ./$IMAGE
        echo "Pushing image $REGISTRY/$IMAGE:$VERSION-$ARCH"
        docker push $REGISTRY/$IMAGE:$VERSION-$ARCH
    done

    # Generate the manifests for the images
    echo "Generating manifests for image $IMAGE"
    #manifest-tool push from-args --platforms $ARCH_LIST --template "$REGISTRY/$IMAGE:$VERSION-ARCH" --target "$REGISTRY/$IMAGE:latest"
    manifest-tool push from-args --platforms $ARCH_LIST --template "$REGISTRY/$IMAGE:$VERSION-ARCH" --target "$REGISTRY/$IMAGE:$VERSION"

    echo ""
}

if [[ $# -eq 0 ]]; then
    echo "Choose a image to build or 'all' to build all images"
    echo "Image list: " ${IMAGES[*]}
    exit 0
fi

if [[ "$1" == "all" ]]; then
    for I in $(seq 0 $num_img); do
        build_image $I
    done
else
    INDEX=`echo ${IMAGES[@]/$1//} | cut -d/ -f1 | wc -w | tr -d ' '`
    build_image $INDEX
fi
