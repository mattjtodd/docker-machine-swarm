#!/usr/bin/env bash

docker service create \
  --mode global \
  --mount type=bind,source=/,destination=/rootfs,ro=1 \
  --mount type=bind,source=/var/run,destination=/var/run \
  --mount type=bind,source=/sys,destination=/sys,ro=1 \
  --mount type=bind,source=/var/lib/docker/,destination=/var/lib/docker,ro=1 \
  --publish mode=host,target=8080,published=8080 \
  --name=cadvisor \
  google/cadvisor:latest