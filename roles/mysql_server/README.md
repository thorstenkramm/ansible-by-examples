## Install MySQL Server

### Role summary

1. Verify MySQL Version Compatibility: It first checks if the desired MySQL version is supported by Percona XtraBackup.
   If the specified version is not supported, the task fails with a message listing the supported versions.

2. Check MySQL Installation: It checks for the existence of the MySQL daemon (mysqld) at /usr/sbin/mysqld.
   If it exists, it assumes MySQL is already installed and ends the playbook execution early for that host.

3. Download MySQL Server DEB Packages: If MySQL is not already installed, it proceeds to download a series of MySQL
   server packages from a specified URL. The version and distribution are dynamically determined based on the 
   mysql_version variable and the host's distribution facts. It tries to download these packages three times in case
   of failures. The packages are saved to /var/cache/private.

4. Install MySQL DEB Packages: After downloading, it installs the MySQL packages using the dpkg command in a
   Debian-compatible environment. It sets the DEBIAN_FRONTEND environment variable to none-interactive to avoid prompts
   during installation. After installation, it cleans up by removing the downloaded .deb files.

5. Prevent MySQL Server Updates: It marks the MySQL server package (mysql-server) as "hold" using the dpkg_selections
   module, which prevents the package from being automatically updated.

6. Install libmysqlclient21: It ensures that the libmysqlclient21 package is installed using the apt module. 
   This is a library package that is often required for MySQL client applications.

7. Lastly install a version of Percona Xtrabackup that corresponds to the MySQL Server version.
   An example script `/root/run-xtrabackup.sh` is created so you can quickly verify Xtrabackup is able to perform
   backups flawlessly. 

### The problems

Installing a MySQL Server (not MariaDB) can be challenging if you have the following requirements:

1. All MySQL Servers shall be backed up with Percona Xtrabackup.
2. You want to be able to deploy different versions of MySQL.

The above requirement will lead to the below problems:
1. Using the MySQL Debian Repo gives access only to the latest version. MySQL has an archive of all versions, but you
   cannot install them via the repo. 
2. Percona does not provide a version of xtrabackup for all MySQL-Server versions.

The most obvious approach would be:
```yaml
---
- name: Add MySQL 8 Debian Repo
  ansible.builtin.apt:
    deb: https://repo.mysql.com/mysql-apt-config_0.8.29-1_all.deb
    state: present
    update_cache: false

- name: Install MySQL 8
  ansible.builtin.apt:
    name: mysql-server
    state: present
    update_cache: true

- name: Hold MySQL Server aka prevent updates
  ansible.builtin.dpkg_selections:
    name: mysql-server
    selection: hold
```

It does not solve either of the two problems mentioned. If you try install the package with a specific number, such as
`mysql-server=8.0.19` you will get `package not found`.

If you do not specify the number, you will get version `8.0.36` for which you won't get an xtrabackup version, at this
point in time, Feb 2024.

### Do not use the repo

The solution is installing the packages without adding the repository.

To check if a version is supported by Percona, you have to point your browser to https://www.percona.com/downloads, scroll
to the Percona Xtrabackup section and select your version.

You will find these versions:
```
Percona-XtraBackup-8.2.0-1
Percona-XtraBackup-8.1.0-1
Percona-XtraBackup-8.0.34-29
Percona-XtraBackup-8.0.33-28
Percona-XtraBackup-8.0.33-27
Percona-XtraBackup-8.0.32-26
Percona-XtraBackup-8.0.35-30
Percona-XtraBackup-8.0.32-25
Percona-XtraBackup-8.0.31-24
Percona-XtraBackup-8.0.30-23
Percona-XtraBackup-8.0.29-22
Percona-XtraBackup-8.0.28-21
Percona-XtraBackup-8.0.28-20
Percona-XtraBackup-8.0.27-19
Percona-XtraBackup-8.0.26-18
Percona-XtraBackup-8.0.25-17
Percona-XtraBackup-8.0.23-16
Percona-XtraBackup-8.0.22-15
Percona-XtraBackup-8.0.14
Percona-XtraBackup-8.0.13
Percona-XtraBackup-8.0.12
Percona-XtraBackup-8.0.11
Percona-XtraBackup-8.0.10
Percona-XtraBackup-8.0.9
Percona-XtraBackup-8.0.8
Percona-XtraBackup-8.0.7
Percona-XtraBackup-8.0.6
Percona-XtraBackup-8.0.5
Percona-XtraBackup-8.0.4
```

So you would do well, if your playbook verifies the desired MySQL version against the Percona list. 
The file `roles/mysql-server/vars/main.yaml` contains a mapping of MySQL-Server versions and their corresponding
xtrabackup version. 

