#!/usr/bin/env sh
#shellcheck shell=sh

set -xe

REPO=krisk84
IMAGE=rtlsdrairband
PLATFORMS="linux/amd64,linux/arm/v7,linux/arm64"

docker context use default
export DOCKER_CLI_EXPERIMENTAL="enabled"
#docker buildx use cluster

# Don't built non NFM variant
# Build & push latest
docker buildx build --no-cache -t "${REPO}/${IMAGE}:latest" --compress --push --platform "${PLATFORMS}" .

sed 's/NFM_MAKE=0/NFM_MAKE=1/g' < Dockerfile > Dockerfile.NFM

docker buildx build -f Dockerfile.NFM --no-cache -t "${REPO}/${IMAGE}:latest_nfm" --compress --push --platform "${PLATFORMS}" .
