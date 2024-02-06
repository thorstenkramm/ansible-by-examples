#!/usr/bin/env bash
set -e
set -o pipefail

if sudo snap list|grep -q lxd;then
  echo "lxd installed"
else
  sudo snap install lxd
fi

sudo usermod -a -G lxd $(whoami)
groups
stat /var/snap/lxd/common/lxd/unix.socket
sudo chmod o+g '/var/snap/lxd/common/lxd/unix.socket'

if [ $(ip -o addr show lxdbr0 2>/dev/null|wc -l) -gt 0 ];then
  echo "lxd network configured"
else
  sudo lxd init --auto
fi

export SSH_PUB_KEY="$(cat files/ssh-pub-keys/john.doe.pub)"
. env-spinup.sh
pkill ssh-agent || true
eval $(ssh-agent)
chmod 0600 files/ssh-pub-keys/john.doe
ssh-add files/ssh-pub-keys/john.doe

echo "Checking SSH access to containers"
CONTAINERS="una ultima daniela delia"
for CONTAINER in $CONTAINERS;do
  ssh -o "StrictHostKeyChecking no" root@$CONTAINER date
done
ansible -i inventory/example.inventory.yaml all -m ping --extra-vars "ansible_user=root"
ansible-playbook -i inventory/example.inventory.yaml hosts-init.yml --extra-vars "ansible_user=root"
export ANSIBLE_REMOTE_USER=john.doe

cat << EOF > ansible.cfg
[defaults]
inventory = ./inventory/example.inventory.yaml
[privilege_escalation]
become = true
EOF
ansible-playbook hosts-init.yml
ansible-playbook dns-servers.yml

nslookup www.example.com una|grep 10.38
nslookup www.example.com daniela|grep 10.38