#!/bin/bash

docker build --platform=arm64 . -f fish-portable-musl-alpine.Dockerfile -t xxh/fish-portable-musl-alpine  #--no-cache --force-rm
docker run --rm -v `pwd`/result:/result xxh/fish-portable-musl-alpine
