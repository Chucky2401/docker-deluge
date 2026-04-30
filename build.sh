#!/usr/bin/env bash

export CREATED=$(date +%Y-%m-%dT%H:%M:%SZ)
export DIGEST=$(docker buildx imagetools inspect alpine:latest --format "{{json .Manifest.Digest}}" | sed -e 's/"//g' | cut -d":" -f2)
export REVISION=$(git rev-parse HEAD | cut -c1-8)
export VERSION="2.0.0-beta.1"
IMAGE_NAME="forgejo.intranet.blackwizard.fr/docker/deluge"

# docker compose -f compose.build.yaml up -d --build
docker buildx build \
  --build-arg CREATED=$CREATED \
  --build-arg DIGEST=$DIGEST \
  --build-arg REVISION=$REVISION \
  --build-arg VERSION=$VERSION \
  --platform linux/amd64,linux/arm64 \
  --builder mybuilder \
  --tag $IMAGE_NAME:$VERSION \
  --push \
  .

docker image ls | grep "$IMAGE_NAME:$VERSION"

unset CREATED
unset DIGEST
unset REVISION
unset VERSION
