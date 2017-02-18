#!/usr/bin/env bash
set -ex

NUM_MANAGER_NODES=${1:-1}
WORKER_NODES=${2:-3}

[ $(($NUM_MANAGER_NODES%2)) -eq 0 ] && exit 1
[ $WORKER_NODES -lt 1 ] && exit 1

LEADER_NODE=manager-0

docker-machine create --driver virtualbox --swarm-experimental $LEADER_NODE

LEADER_IP=`docker-machine ip $LEADER_NODE`

# initialize swarm
docker-machine ssh $LEADER_NODE docker swarm init --advertise-addr $LEADER_IP
docker-machine ssh $LEADER_NODE docker node update --availability drain $LEADER_NODE

# Now let's get the swarm join token for a worker node
MANAGER_JOIN_TOKEN=`docker-machine ssh $LEADER_NODE docker swarm join-token manager -q`
WORKER_JOIN_TOKEN=`docker-machine ssh $LEADER_NODE docker swarm join-token worker -q`

COUNTER=1

while [ $COUNTER -lt $NUM_MANAGER_NODES ]; 
do
  node=manager-$COUNTER
  docker-machine create --driver virtualbox --swarm-experimental $node
  docker-machine ssh $node docker swarm join --token $MANAGER_JOIN_TOKEN $LEADER_IP:2377
  docker-machine ssh $node docker node update --availability drain $node
  let COUNTER=COUNTER+1
done

for COUNTER in `seq 1 $WORKER_NODES`;
do
  node=worker-$COUNTER
  docker-machine create --driver virtualbox --swarm-experimental --virtualbox-memory "2048" $node
  docker-machine ssh $node docker swarm join --token $WORKER_JOIN_TOKEN $LEADER_IP:2377 
done 

# finally show all nodes
docker-machine ssh $LEADER_NODE docker node ls

