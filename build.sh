#!/usr/bin/env bash

interkosmos_target=${1:-bash}
docker build -t interkosmos-build . && \
docker run -it -v "$PWD/artifacts:/artifacts" interkosmos-build $interkosmos_target

