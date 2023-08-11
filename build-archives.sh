#!/bin/bash
docker build -t build-dotnet-archives -f Dockerfile.build-archives .
docker run -v ./functions/producer:/app/src -v ./build/producer:/app/build -v ./build:/app/archive --rm -e OUTPUT_NAME=producer build-dotnet
docker run -v ./functions/consumer:/app/src -v ./build/consumer:/app/build -v ./build:/app/archive --rm -e OUTPUT_NAME=consumer build-dotnet