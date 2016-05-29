#!/bin/bash

function cleanup() {
    grep helloworld <(docker ps) && docker stop helloworld
    docker stop postgresql || true
}
trap cleanup EXIT

set -o xtrace
set -o errexit
set -o pipefail

echo dump info about your system
echo dlite requires osx hypervisor support which is only in 10.10.3+
sw_vers -productVersion
sysctl -a kern.hv_support

echo is brew installed?
if ! which brew
then
    echo install brew first plz
    exit 1
fi

echo ensure dlite installed
dlite version || brew install dlite

echo ensure dlite vm installed
echo NOTE: this takes up 10GB storage immediately
if ! test -d ~/.dlite
then
    sudo dlite install \
        --cpus=1 \
        --memory=1 \
        --disk=10 \
        --hostname=local.docker
fi

echo ensure dlite vm is running and available
if ! dlite ip
then
    dlite stop || true
    dlite start
    dlite ip
fi

echo test that dlite vm running linux ok
ssh docker@local.docker 'uname -a'

docker --version
DLITE_DOCKER_VERSION=$(ssh docker@local.docker 'docker --version')

if [[ "$DLITE_DOCKER_VERSION" < "Docker version 1.11." ]]
then
    # update dlite to latest and greatest to fix docker version issue
    # ref: https://github.com/nlf/dlite/issues/175
    dlite stop && dlite update -v 2.3.0 && dlite start
    dlite ip
fi

docker ps

echo ok, now for the real test...
echo ensuring that docker-machine 'default' is not running...

if ! test -z "$DOCKER_HOST"
then
    echo this shell has docker-machine env variables in it, use a fresh shell w/o them
    env | sort | grep ^DOCKER
    exit 1
fi

echo ensure that docker-machine is stopped and that this is only running on docker+dlite
docker-machine stop default || true
docker-machine ls

echo run docker hello world
docker run --name helloworld --rm -it hello-world

echo run postgresql

echo ...ensure there are no other postgresql containers running
if grep postgresql <(docker ps -f name=postgresql)
then
    echo "there's already a docker image named postgresql running, stop it manually and re-run this to continue."
    exit 1
fi

echo ensure postgresql container running
docker run \
    --name postgresql \
    --rm \
    -i \
    --publish 5432:5432 \
    --volume /srv/docker/postgresql:/var/lib/postgresql \
    --env 'DB_USER=dbuser' --env 'DB_PASS=dbuserpass' \
    sameersbn/postgresql:9.4-21 &

echo HACK: wait for postgres container to boot up
sleep 3

echo 'select version();' | \
    docker exec -i postgresql sudo -u postgres psql -a

echo query GUEST postgres server using HOST psql, assuming installed...
echo 'select version();' | \
    PGPASSWORD=dbuserpass psql -h local.docker -U dbuser postgres -a

echo to reclaim the 10GB run:
echo "dlite stop && dlite uninstall"
ecoh sudo dlite 
# exit traps cleanup

