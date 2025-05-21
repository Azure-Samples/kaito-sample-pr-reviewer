#!/bin/bash
set -e

IMAGE_NAME="kaitosample.azurecr.io/go-operator-reviewer-data:0.0.1"

az acr login --name kaitosample && \
docker build -t $IMAGE_NAME . && \
docker push $IMAGE_NAME
