#!/usr/bin/env bash
set -e
set -o pipefail

if [ -z "$SSH_PUB_KEY" ];then
  echo "Export your ssh public key to SSH_PUB_KEY first."
  false
fi

## Create LXD containers

incus info una>/dev/null 2>&1 || incus launch images:ubuntu/20.04 una
incus info ultima>/dev/null 2>&1 || incus launch images:ubuntu/22.04 ultima
incus info daniela>/dev/null 2>&1 || incus launch images:debian/12 daniela
incus info delia>/dev/null 2>&1 || incus launch images:debian/11 delia
incus info daisy>/dev/null 2>&1 || incus launch images:debian/10 daisy

incus ls

CONTAINERS="una ultima daniela delia"
for CONTAINER in $CONTAINERS;do
  echo "======================================================================="
  echo " Preparing container $CONTAINER"
  echo "======================================================================="
incus exec $CONTAINER bash <<EOF
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
  IP=$(incus ls $CONTAINER --format=json|jq -r .[0].state.network.eth0.addresses[0].address)
  echo $IP
  if grep -q $IP /etc/hosts;then
    echo "$CONTAINER already in /etc/hosts"
    continue
  fi
  sudo sh -c "echo $IP $CONTAINER >> /etc/hosts"
done

incus ls