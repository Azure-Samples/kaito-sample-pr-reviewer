#!/bin/bash
set -e

IMAGE_NAME="kaitosample.azurecr.io/go-operator-reviewer-data:0.0.1"

cat > Dockerfile << EOF
FROM scratch
COPY go-operator-reviewer-data.parquet /data/
EOF

az acr login --name kaitosample && \
docker build -t $IMAGE_NAME . && \
docker push $IMAGE_NAME

rm Dockerfile
