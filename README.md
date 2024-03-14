## Get started with Ansible by learning from examples

This repository contains a collection of playbooks, plays, roles and inventories demonstrating how to manage a network,
users, and applications.

> 🛑 This **is not a beginners guide!** You must be very familiar with Linux system administration, particularly with 
> key-based SSH authentication. 

All recipes and approaches demonstrated her refer to Debian and Ubuntu only. If you are managing RPM-based distros this
is likely not the best source of inspiration.

## Create a development environment

To develop robust and reliable Ansible automations you must have a development environment that simulates as close as
possible your productive environment. While there are almost countless options to create a virtual development environment
here some consideration about what you should **NOT** use.

* Do not setup a common test environment that you will share with your colleagues. This will create hassle and conflicts.
  Each system administrator must be able to test the automation without bothering others.
* Do not use heavyweight virtualization such as VMWARE ESX, Proxmox. Spinning up and tearing down your environment will 
  take to much time. Creating encapsulated networks and resetting the environment can become a science for it self. 
* Avoid using Vagrant. While Vagrant still appears to be popular, its default setup is based on Virtualbox, a relatively
  outdated technology. Vargant images are big and therefore slow to deploy. Setting up a network for the intercommunication
  of VMs is clumsy. 
* Do not use Docker. Ansible is for managing operating systems. A Docker container does not simulate a full OS. Crucial 
  services such as Systemd are not working inside a container. Also you want your environment to be persistent until you 
  reset it. 

Linux Containers are the perfect solution for creating an Ansible development environment. Its lightweight, fast, 
persistent and built-in to all Linux distributions. Inside a container you have a fully featured operating system. 
By default, containers can communicate amongst each other.

While the ability to run a container is a kernel feature, you need userland tools to manage them. Originally the 
userland tools where named `lxc` which has been replaced by `lxd`. The end of `lxd` has been announced and the current
userland tools to manage linux containers are called `incus`.

**Where to install the linux containers and incus?**   
If you are running Linux on your PC or laptop, you can install it directly there. If your workplace
is based on Windows or Mac, run a virtual machine with Linux and install incus inside. This kind of nested virtualization 
is supported. As an alternative you can use some old unused hardware or a cloud VM. 

Caution with the CPU architecture! If you are using modern Apple hardware with ARM architecture think twice before you 
install a Linux virtual machine to run your Ansible development environment. Very likely the productive environment you
pretend to manage with Ansible will be based on X86_64 CPUs. As soon as you start using software that is not included in
the distribution, you must handle the two CPU architectures differently. This can become a rabbit hole. When possible, 
create you development environment based on a X86_64 CPU.

### Install Incus

The installation of Incus on Debian 12 and Ubuntu 20.04 & 22.04 is via the [repository of the maintainer](https://github.com/zabbly/incus).
Future versions of Debian and Ubuntu will have incus included. 

```bash
cat <<"EOF"|sudo bash
curl -fsSL https://pkgs.zabbly.com/key.asc | gpg --show-keys --fingerprint
mkdir -p /etc/apt/keyrings/
curl -fsSL https://pkgs.zabbly.com/key.asc -o /etc/apt/keyrings/zabbly.asc
echo "Enabled: yes
Types: deb
URIs: https://pkgs.zabbly.com/incus/stable
Suites: $(. /etc/os-release && echo ${VERSION_CODENAME})
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/zabbly.asc
"> /etc/apt/sources.list.d/zabbly-incus-stable.sources
EOF
```

Having repo added, you can install incus.
```bash
sudo apt-get update
sudo apt-get --no-install-recommends --no-install-suggests install incus
```
### Configure and use Incus
After having installed the incus command line tools, create a default configuration by executing

```bash
sudo incus admin init --minimal
```

Use `ip -o addr show incusbr0` to verify a network bridge has been created for the containers.

Verify you have access to the image repositories by executing:

```bash
incus image list images:debian arch=amd64 type=container
incus image list images:ubuntu arch=amd64 type=container
```

This should give you a list of Debian and Ubuntu versions. 

Make sure your `/etc/subuid` and `/etc/subgid` are correct.
Both files must have a single entry for the root user `root:1000000:1000000000`. Delete other entries for root, if
there are any.

```bash
cat <<EOF|sudo bash
cp /etc/subuid /etc/subuid.bak
cp /etc/subgid /etc/subgid.bak
sed -i '/^root/d' /etc/subuid
sed -i '/^root/d' /etc/subgid
echo root:1000000:1000000000 >> /etc/subuid
echo root:1000000:1000000000 >> /etc/subgid
service incus restart
EOF
```

Create your first container and log in to it.

```bash
incus launch images:debian/12 first-test
incus exec first-test bash
```

If you cannot manage incus instances from an unprivileged user account, add the account to the group `incus-admin`
by executing:

```bash
sudo usermod -a -G incus-admin $(whoami)
newgrp incus-admin
```

Now you are logged in to the container named `first-test`. Check the network by doing `ping -c 5 8.8.8.8`. 
Use Ctrl-D to log out. Back on the console of the host, check the status of your containers with

```bash
thorsten@ansible-dev:~$ incus ls

+------------+---------+---------------------+-----------------------------------------------+-----------+-----------+
|    NAME    |  STATE  |        IPV4         |                     IPV6                      |   TYPE    | SNAPSHOTS |
+------------+---------+---------------------+-----------------------------------------------+-----------+-----------+
| first-test | RUNNING | 10.38.118.29 (eth0) | fd42:178c:7758:2945:216:3eff:fedb:54ea (eth0) | CONTAINER | 0         |
+------------+---------+---------------------+-----------------------------------------------+-----------+-----------+

```

Delete the first test container with `incus delete first-test --force`.

### Clone the repo

Clone this repo on your desktop with `git clone https://github.com/thorstenkramm/ansible-by-examples.git`. Change into
the `ansible-by-example` folder and start your IDE there. VS Code or PycharmCE are excellent for editing the project
files. 

### Make it available on the incus host

#### via SSHFS mount
If Incus doesn't run directly on your desktop PC, make the project folder available on the Incus host. With SSHFS you can 
solve this with ease.
Log in to your ansible dev machine with the SSH agent active.

```bash
ssh -A ansible-dev
```

Install SSHFS and mount the project folder from your desktop PC.

```bash
sudo apt install sshfs
sudo sh -c "echo user_allow_other>> /etc/fuse.conf"
mkdir ~/ansible-by-example
sshfs <YOUR-BOX>:<PATH>/ansible-by-examples ~/ansible-by-examples -o uid=$(id -u),gid=$(id -u),allow_root
cd ~/ansible-by-example
ls
```

The `allow_root` option is crucial. If omitted snap-based commands will not work from inside a mounted folder. 

#### via SSH ProxyJump
If cannot or don't want to use SSHFS using an SSH proxy jump is another option. Because ansible by default uses the
ssh client from the operating system, all settings in your `~/.ssh/config` are applied.

Let's say your incus host has the primary IP address `192.168.178.91` and the incus bridge has the IP address
`10.62.193.1`. Add the following lines to your `~/.ssh/config` on your desktop pc.

```
## Ansible Dev Environment
host 10.62.193.* daniela delia ultima una
    ProxyJump 192.168.178.91
```

Test it with 
```
desktop$ ssh 10.62.193.174
```

Whenever you want to access a host in the  10.62.193.0 network, the host `192.168.178.91` will be used as a jump host.
Of course, this requires password-less log in to the jump host to be set up properly.

To access the incus containers by name, you must insert the IP addresses to your local `/etc/hosts` file.:q


### Create the development environment

The examples will cover the management of Debian and Ubuntu of different versions.
Incus container images are very basic. They don't activate SSHD. The spinup script will do this for you.
For password-less authentication your personal SSH pub key is required.

```bash
export SSH_PUB_KEY="ssh-ed25519 <YOUR-KEY> user@example.com"
cd ~/ansible-by-example
bash env-spinup.sh
```

The `env-spinup.sh` script has added the names and IP addresses of the containers to the /etc/hosts file.

Verify you can access all container via SSH:

```bash
CONTAINERS="una ultima daniela delia"
for CONTAINER in $CONTAINERS;do
  ssh -o "StrictHostKeyChecking no" root@$CONTAINER date
done
```

### It's time for the first Ansible test

Now let's verify we can access all containers with Ansible.

```bash
sudo apt-get install -y ansible
ansible-galaxy collection install ansible.posix
ansible --inventory=una,ultima,delia,daniela, all -m ping --extra-vars "ansible_user=root"
ansible -i inventory/example.inventory.yaml all -m ping --extra-vars "ansible_user=root"
```

Both commands should return success for all hosts. 

Note that we temporarily use the root user to connect. Later, once we have a user management implemented, we will only use
personalized accounts. 

If you get an access denied error, your SSH private key is very likely not loaded or not located in the default location.
Log in to your Ansible development environment with the ssh agent loaded on your PC and then use `ssh -A` to transfer your
exported private keys into the SSH session. 

### Apply some roles

Inside the roles folder you have some example roles. You can apply them in ad-hoc mode. For example:

```bash
ansible --inventory=una, all -m include_role --args name=baseline --extra-vars "ansible_user=root"
ansible -i inventory/example.inventory.yaml all -m include_role --args name=baseline --extra-vars "ansible_user=root"
```

Note: If the inventory is specified on the command line, the list of hosts must always end with a comma.
Both commands are doing the same. The first takes the inventory aka the list of hosts as command line parameters where
the second reads this list form a file.

### Create users and stop using root

Now it's time to fire the first playbook.

```bash
ansible-playbook -i inventory/example.inventory.yaml hosts-init.yml --extra-vars "ansible_user=root"
```
This playbook will apply two roles with the corresponding tasks:
1. `./roles/baseline/tasks.main` to do some basic stuff.
2. `./roles/multiuserbox/tasks.main` to manage the users and SSH keys.

Read through the files to find out what exactly they do.

Edit `./vars/users.yml` and add yourself as a new user. Enable `on_all_hosts` and `sudo`. 
Place your SSH public key in `./files/ssh-pub-keys`.

Run the playbook again. From now on Ansible can access the hosts with your personal user.
It's always recommended to use personal accounts rather than the root account. 

If the username for Ansible is not the username you are currently using, export an environment variable for it.
```bash
export ANSIBLE_REMOTE_USER=<username>
```

Put this export into your shell profile so it gets loaded always. 

Check your user has access by logging in to all containers.

```bash
CONTAINERS="una ultima daniela delia"
for CONTAINER in $CONTAINERS;do
  ssh -o "StrictHostKeyChecking no" $ANSIBLE_REMOTE_USER@$CONTAINER date
done
```

Now execute the `init-hosts` playbook again, but with the `-b` and without without the
`--extra-vars "ansible_user=root"` parameter.
`-b` instructs Ansible to create the connection with an unprivileged user and then become root using sudo. 

```bash
ansible-playbook -i inventory/example.inventory.yaml hosts-init.yml -b
```

You don't need to type in the location of the inventory and the become parameter each time you execute a playbook.
Let's define it as defaults for the current folder.

```bash
cat << EOF > ansible.cfg
[defaults]
inventory = ./inventory/example.inventory.yaml
[privilege_escalation]
become = true
EOF
```

From now on you can execute playbooks without further arguments like:

```bash
ansible-playbook hosts-init.yml
```

### Keep everything tidy and consistent

It's always recommend to run `ansible-lint` and make your files comply with the default rules.
This assures your files are tidy and consistent.

```bash
sudo apt install ansible-lint
ansible-lint
```

If you get warnings or errors, fix them before pushing your change to git.
You should also run ansible-lint after each push from your Git workflow. 

## Cheat sheet

Common tasks and their commands:

* Execute a playbook on a single host from the inventory only
  ```
  ansible-playbook mysql-servers.yml --limit una
  ```