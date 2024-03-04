#!/usr/bin/env bash

CONTAINERS="una ultima daniela delia"
for CONTAINER in $CONTAINERS;do
  echo "Deleting container $CONTAINER"
  incus delete $CONTAINER --force
  # Remove entry from /etc/hosts
  sudo sed -i "/${CONTAINER}$/d" /etc/hosts
  # Remove from known hosts
  ssh-keygen -f ~/.ssh/known_hosts -R $CONTAINER
done