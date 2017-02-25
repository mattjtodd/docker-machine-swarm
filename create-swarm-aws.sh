#!/usr/bin/env bash
set -ex

NUM_MANAGER_NODES=${1:-1}
WORKER_NODES=${2:-3}

DRIVER=amazonec2
AWS_REGION=eu-west-1
AWS_VPC=vpc-5d467c39
AWS_SG=docker-machine
AWS_PARAMS="--amazonec2-region=$AWS_REGION --amazonec2-vpc-id=$AWS_VPC --amazonec2-subnet-id=subnet-7af6fb0c --amazonec2-zone=b --amazonec2-security-group=$AWS_SG"

[ $(($NUM_MANAGER_NODES%2)) -eq 0 ] && exit 1
[ $WORKER_NODES -lt 0 ] && exit 1

LEADER_NODE=manager-leader

docker-machine create --driver $DRIVER $AWS_PARAMS --swarm-experimental $LEADER_NODE

LEADER_IP=`docker-machine inspect $LEADER_NODE | jq .Driver.PrivateIPAddress`

# initialize swarm
docker-machine ssh $LEADER_NODE sudo docker swarm init --advertise-addr $LEADER_IP
docker-machine ssh $LEADER_NODE sudo docker node update --availability drain $LEADER_NODE

# Now let's get the swarm join token for a worker node
MANAGER_JOIN_TOKEN=`docker-machine ssh $LEADER_NODE sudo docker swarm join-token manager -q`
WORKER_JOIN_TOKEN=`docker-machine ssh $LEADER_NODE sudo docker swarm join-token worker -q`

COUNTER=1

while [ $COUNTER -lt $NUM_MANAGER_NODES ]; 
do
  node=manager-$COUNTER
  docker-machine create --driver $DRIVER $AWS_PARAMS --swarm-experimental $node
  docker-machine ssh $node sudo docker swarm join --token $MANAGER_JOIN_TOKEN $LEADER_IP:2377
  docker-machine ssh $node sudo docker node update --availability drain $node
  let COUNTER=COUNTER+1
done

let COUNTER=1

while [ $COUNTER -le $WORKER_NODES ];
do
  node=worker-$COUNTER
  docker-machine create --driver $DRIVER $AWS_PARAMS --swarm-experimental $node
  docker-machine ssh $node sudo docker swarm join --token $WORKER_JOIN_TOKEN $LEADER_IP:2377 
  let COUNTER=COUNTER+1
done 

# finally show all nodes
docker-machine ssh $LEADER_NODE sudo docker node ls

