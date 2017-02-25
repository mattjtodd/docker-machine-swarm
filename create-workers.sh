#!/usr/bin/env bash
set -ex

WORKER_NODES=${1:-3}

[ $WORKER_NODES -lt 1 ] && exit 1

LEADER_IP=${2:-`docker-machine ip $LEADER_NODE`}

# Now let's get the swarm join token for a worker node
WORKER_JOIN_TOKEN=${3:-`docker-machine ssh $LEADER_NODE docker swarm join-token worker -q`}

for (( i=0 ; i < $WORKER_NODES ; i++ )) ;
do
  node=worker-$i
  docker-machine create --driver virtualbox --swarm-experimental $node
  docker-machine ssh $node docker swarm join --token $WORKER_JOIN_TOKEN $LEADER_IP:2377 
done 
