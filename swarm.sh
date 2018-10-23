#!/usr/bin/env bash

DRIVER="virtualbox"
NBR_MANAGER=3
NBR_WORKER=0

# Can be either drain or active
MANAGER_AVAILABILITY=active
# additional flags depending upon driver selection

ADDITIONAL_PARAMS=
PERMISSION=

# Manager and worker prefix
PREFIX="docker"

CPU=2
MEM=3072

function usage {
  echo "Usage: $0 [-m|--manager nbr_manager] [--mgr-availability mgr_avilability] [-w|--worker nbr_worker] [-p|--prefix machine_prefix]"
  exit 1
}

function error {
  echo "Error $1"
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
   --manager|-m)
      NBR_MANAGER="$2"
      shift 2
      ;;
   --mgr-availability)
      MANAGER_AVAILABILITY="$2"
      shift 2
      ;;
   --worker|-w)
      NBR_WORKER="$2"
      shift 2
      ;;
   --prefix|-p)
     PREFIX="$2"
     shift 2
     ;;
   --cpu)
     CPU="$2"
     shift 2
     ;;
   --mem)
     MEM="$2"
     shift 2
     ;;
   -h|--help)
     usage
     ;;
  esac
done

ADDITIONAL_PARAMS="$ADDITIONAL_PARAMS --virtualbox-cpu-count $CPU --virtualbox-memory $MEM"

MANAGER=${PREFIX}-manager
WORKER=${PREFIX}-worker

echo "-> about to create a swarm with $NBR_MANAGER manager(s) and $NBR_WORKER workers on $DRIVER machines"

echo -n "is that correct ? ([Y]/N)"
read build_demo

if [ "$build_demo" = "N" ]; then
  echo "aborted !"
  exit 0
fi

# Get Private vs Public IP
function getIP {
    echo $(docker-machine inspect -f '{{ .Driver.IPAddress }}' $1)
}

function check_status {
  if [ "$(docker-machine ls -f '{{ .Name }}' | grep ${MANAGER}1)" != "" ]; then
    error "${MANAGER}1 already exist. Please remove managerX and workerY machines"
  fi
}

function get_manager_token {
  echo $(docker-machine ssh ${MANAGER}1 $PERMISSION docker swarm join-token manager -q)
}

function get_worker_token {
  echo $(docker-machine ssh ${MANAGER}1 $PERMISSION docker swarm join-token worker -q)
}

# Create Docker host for managers
function create_manager {
  for i in $(seq 1 $NBR_MANAGER); do
    echo "-> creating Docker host for manager $i (please wait)"
    # Azure needs Stdout for authentication. Workaround: Show Stdout on first Manager.
    docker-machine create --driver $DRIVER $ADDITIONAL_PARAMS --engine-opt experimental --engine-opt "metrics-addr=0.0.0.0:4999" ${MANAGER}$i 1>/dev/null
  done
}

# Create Docker host for workers
function create_workers {
  for ((i=0;i<$NBR_WORKER;i+=1));do
    echo "-> creating Docker host for worker $i (please wait)"
    docker-machine create --driver $DRIVER $ADDITIONAL_PARAMS --engine-opt experimental --engine-opt "metrics-addr=0.0.0.0:4999" ${WORKER}$i 1>/dev/null
  done
}

# Init swarm from first manager
function init_swarm {
  echo "-> init swarm from ${MANAGER}1"
  docker-machine ssh ${MANAGER}1 $PERMISSION docker swarm init --listen-addr $(getIP ${MANAGER}1):2377 --advertise-addr $(getIP ${MANAGER}1):2377
  docker-machine ssh ${MANAGER}1 docker node update --availability $MANAGER_AVAILABILITY ${MANAGER}1
}

# Join other managers to the cluster
function join_other_managers {
  if [ "$((NBR_MANAGER-1))" -ge "1" ];then
    for i in $(seq 1 $NBR_MANAGER);do
      echo "-> ${MANAGER}$i requests membership to the swarm"
      docker-machine ssh ${MANAGER}$i $PERMISSION docker swarm join --token $(get_manager_token) --listen-addr $(getIP ${MANAGER}$i):2377 --advertise-addr $(getIP ${MANAGER}$i):2377 $(getIP ${MANAGER}1):2377 2>&1
      docker-machine ssh ${MANAGER}$i docker node update --availability $MANAGER_AVAILABILITY ${MANAGER}$i
    done
  fi
}

# Join worker to the cluster
function join_workers {
  for ((i=0;i<$NBR_WORKER;i+=1));do
    echo "-> join worker $i to the swarm"
    docker-machine ssh ${WORKER}$i $PERMISSION docker swarm join --token $(get_worker_token) --listen-addr $(getIP ${WORKER}$i):2377 --advertise-addr $(getIP ${WORKER}$i):2377 $(getIP ${MANAGER}1):2377
  done
}

function main {
  check_status
  create_manager
  create_workers
  init_swarm
  join_other_managers
  join_workers
}

main
#docker-machine ls --filter "name=$PREFIX." -q | xargs -I {} docker-machine ssh {} "sudo curl -# -L git.io/scope -o /usr/local/bin/scope && sudo chmod a+x /usr/local/bin/scope && scope launch $(docker-machine ls --filter "name=$PREFIX." -q | xargs -L1 docker-machine ip | tr '\n' ' ')"
