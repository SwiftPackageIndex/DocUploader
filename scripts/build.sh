#!/bin/bash

set -eu

executable=$1

docker run \
  --rm \
  --volume "$(pwd):/src" \
  --workdir "/src" \
  swift:5.7.1-amazonlinux2 \
  swift build --product "$executable" -c release --static-swift-stdlib #-Xswiftc -cross-module-optimization 
