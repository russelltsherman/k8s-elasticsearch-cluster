#!/bin/bash
#
# To update image versions and the Kubernetes manifests edit:
# - ./build_images.sh - #Versions section
# - ./docker-elasticsearch/Dockerfile - FROM in case of Java update
# - ./docker-kibana/Dockerfile - LOGTRAIL_VERSION line
# - ./fluentd-elasticsearch/Gemfile - Gem versions
# - ./elasticsearch-cerebro/Dockerfile - FROM in case of Java update
# Manifests:
# - cerebro.yaml - "image" line
# - es-curator_cronjob.yaml - "image" line
# - es-data-statefulset.yaml - "image" line
# - es-full.yaml - "image" line
# - es-ingest.yaml - "image" line
# - es-master.yaml - "image" line
# - fluentd-es-ds.yaml - "image" line
# - kibana.yaml - "image" line
# - prometheus_exporter/elasticsearch-exporter-deployment.yaml - "image" line

# Versions
ES_VERSION=6.6.0
CURATOR_VERSION=5.6.0
FLUENTD_VERSION=1.3.3
CEREBRO_VERSION=0.8.1
EXPORTER_VERSION=1.0.4rc1

REGISTRY=carlosedp

# Architectures
ARCHITECTURES=(amd64 arm64)

# Images and respective versions
IMAGES=(docker-elasticsearch docker-elasticsearch-kubernetes docker-elasticsearch-curator fluentd-elasticsearch docker-kibana elasticsearch-cerebro elasticsearch-exporter)

VERSIONS=($ES_VERSION $ES_VERSION $CURATOR_VERSION $FLUENTD_VERSION $ES_VERSION $CEREBRO_VERSION $EXPORTER_VERSION)

num_img=$((${#IMAGES[*]}-1))

CURRENT_ARCH=$(dpkg --print-architecture)
CPU_ARCH=$(uname -m)

function build_image {
    I=$1
    ARCH=$CURRENT_ARCH
    IMAGE=${IMAGES[$I]}
    VERSION=${VERSIONS[$I]}
    echo "====================================================================="
    echo "Building image $REGISTRY/$IMAGE:$VERSION-$ARCH"
    echo "====================================================================="
    # if [[ ! "$(docker images -q $REGISTRY/$IMAGE:$VERSION-$ARCH 2> /dev/null)" == "" ]]; then
    #     echo "Image $REGISTRY/$IMAGE:$VERSION-$ARCH already exists, skipping."
    #     return
    # fi
    docker build -t $REGISTRY/$IMAGE:$VERSION-$ARCH --build-arg VERSION=$VERSION --build-arg ARCH=$ARCH --build-arg CPU_ARCH=$CPU_ARCH ./$IMAGE
    echo "Pushing image $REGISTRY/$IMAGE:$VERSION-$ARCH"
    docker push $REGISTRY/$IMAGE:$VERSION-$ARCH
    echo ""
}

function push_manifests {
    if ! [ -x $(command -v ./manifest-tool > /dev/null) ]; then
      echo "Downloading manifest-tool"
      curl -o ./manifest-tool -Lskj https://github.com/estesp/manifest-tool/releases/download/v0.9.0/manifest-tool-linux-$CURRENT_ARCH
      chmod +x manifest-tool
    fi
    IMAGE=${IMAGES[$I]}
    VERSION=${VERSIONS[$I]}
    num_archs=$((${#ARCHITECTURES[*]}))
    I=$1
    ARCH_LIST=''
    echo "====================================================================="
    echo "Pushing manifest for image $REGISTRY/$IMAGE:$VERSION-$ARCH"
    echo "====================================================================="
    for ARCH in "${ARCHITECTURES[@]}"; do
        ARCH_LIST="$ARCH_LIST linux/$ARCH"
        echo "Looking for image $REGISTRY/$IMAGE:$VERSION-$ARCH"
        if [[ "$(docker manifest inspect $REGISTRY/$IMAGE:$VERSION-$ARCH 2> /dev/null)" ]]; then
            echo "Image found."
            num_archs=$(expr $num_archs - 1)
        else
            echo "Image not found."
        fi
    done
    echo ""
    if [[ $num_archs == 0 ]]; then
        # Generate the manifests for the images
        echo "Generating manifests for image $IMAGE"
        #manifest-tool push from-args --platforms $ARCH_LIST --template "$REGISTRY/$IMAGE:$VERSION-ARCH" --target "$REGISTRY/$IMAGE:latest"
        ./manifest-tool push from-args --platforms `echo $ARCH_LIST|tr ' ' ','` --template "$REGISTRY/$IMAGE:$VERSION-ARCH" --target "$REGISTRY/$IMAGE:$VERSION"
        echo ""
    else
        echo "Could not find images pushed for all listed architectures."
    fi
}

if [[ $# -eq 0 ]]; then
    echo "Choose a image to build or 'all' to build all images"
    echo "Image list: " ${IMAGES[*]}
    exit 0
fi

if [[ "$1" == "all" ]]; then
    # Build all images
    for I in $(seq 0 $num_img); do
        build_image $I
        push_manifests $I
    done
else
    # Build specific image
    INDEX=`echo ${IMAGES[@]/$1//} | cut -d/ -f1 | wc -w | tr -d ' '`
    build_image $INDEX
    push_manifests $INDEX
fi
