#!/bin/bash

set -o xtrace
set -o errexit
set -o pipefail

brew update
brew install docker-machine-driver-xhyve
sudo chown root:wheel $(brew --prefix)/opt/docker-machine-driver-xhyve/bin/docker-machine-driver-xhyve
sudo chmod u+s $(brew --prefix)/opt/docker-machine-driver-xhyve/bin/docker-machine-driver-xhyve

docker-machine create \
    --driver xhyve \
    --xhyve-cpu-count 1 \
    --xhyve-memory-size 1024 \
    --xhyve-disk-size 10000 \
    default

    #--xhyve-experimental-nfs-share \

docker-machine env default
eval $(docker-machine env default)

sudo cp /var/db/dhcpd_leases \
        /var/db/dhcpd_leases.backup && \
sudo cp /Library/Preferences/SystemConfiguration/com.apple.vmnet.plist \
        /Library/Preferences/SystemConfiguration/com.apple.vmnet.plist.backup
