#!/usr/bin/env bash
set -e
set -o pipefail

if [ -z "$SSH_PUB_KEY" ];then
  echo "Export your ssh public key to SSH_PUB_KEY first."
  false
fi

## Create LXD containers

lxc info una>/dev/null 2>&1 || lxc launch ubuntu:20.04 una
lxc info ultima>/dev/null 2>&1 || lxc launch ubuntu:22.04 ultima
lxc info daniela>/dev/null 2>&1 || lxc launch images:debian/12 daniela
lxc info delia>/dev/null 2>&1 || lxc launch images:debian/11 delia

lxc ls

CONTAINERS="una ultima daniela delia"
for CONTAINER in $CONTAINERS;do
  echo "======================================================================="
  echo " Preparing container $CONTAINER"
  echo "======================================================================="
lxc exec $CONTAINER bash <<EOF
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends openssh-client openssh-server vim sudo python3
test -e /root/.ssh ||mkdir /root/.ssh
chmod 0700 /root/.ssh
echo $SSH_PUB_KEY > /root/.ssh/authorized_keys
chmod 0600 /root/.ssh/authorized_keys
EOF
done
echo ""

which jq >/dev/null|| sudo apt-get -y install jq
for CONTAINER in $CONTAINERS;do
  echo "Getting IP of $CONTAINER"
  IP=$(lxc ls $CONTAINER --format=json|jq -r .[0].state.network.eth0.addresses[0].address)
  echo $IP
  if grep -q $IP /etc/hosts;then
    echo "$CONTAINER already in /etc/hosts"
    continue
  fi
  sudo sh -c "echo $IP $CONTAINER >> /etc/hosts"
done