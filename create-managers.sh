#!/usr/bin/env bash
set -ex

NUM_MANAGER_NODES=${1:-1}

[ $(($NUM_MANAGER_NODES%2)) -eq 0 ] && exit 1

LEADER_NODE=manager-0

docker-machine create --driver virtualbox --swarm-experimental $LEADER_NODE

LEADER_IP=`docker-machine ip $LEADER_NODE`

# initialize swarm
docker-machine ssh $LEADER_NODE docker swarm init --advertise-addr $LEADER_IP
docker-machine ssh $LEADER_NODE docker node update --availability drain $LEADER_NODE

# Now let's get the swarm join token for a worker node
MANAGER_JOIN_TOKEN=`docker-machine ssh $LEADER_NODE docker swarm join-token manager -q`
WORKER_JOIN_TOKEN=`docker-machine ssh $LEADER_NODE docker swarm join-token worker -q`

echo $MANAGER_JOIN_TOKEN
echo $WORKER_JOIN_TOKEN
echo $LEADER_IP

# finally show all nodes
docker-machine ssh $LEADER_NODE docker node ls

