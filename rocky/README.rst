Create Rocky Linux 8 Cloud Image
==================================

This is a guide to create Rocky Linux 8 cloud image.

Download Rocky Linux 8.4 minimal iso.::

   $ mkdir /data/jijisa/images
   $ cd /data/jijisa/images
   $ curl -sLO https://download.rockylinux.org/pub/rocky/8/isos/x86_64/Rocky-8.4-x86_64-minimal.iso

Create root and clex sha512 hash password using the following command::

   $ python3 -c 'import crypt,getpass;pw=getpass.getpass();print(crypt.crypt(pw) if (pw==getpass.getpass("Confirm: ")) else exit())'
   
   $ python3 -c 'import crypt,getpass;pw=getpass.getpass();print(crypt.crypt(pw) if (pw==getpass.getpass("Confirm: ")) else exit())'


Edit ks.cfg to put root and user password.::

   rootpw --iscrypted <sha512_root_password>
   user --name=clex --iscrypted --password <sha512_user_password>

Modify NET_BR in rocky_build.sh for your env.

Run rocky_build.sh.::

   $ bash rocky_build.sh

After installation is done, log in as a root::

   localhost login: root
   Password: <root-password-in-kickstart>

Set up network for your envionment.::

   # ip address add <ip>/<cidr> dev eth0
   # ip route add default via <router_ip>
   # echo "nameserver 8.8.8.8" > /etc/resolv.conf

upgrade packages and reboot.::

   # dnf -y update
   # reboot

Log in again and install what you want.::

   # ip address add <ip>/<cidr> dev eth0
   # ip route add default via <router_ip>
   # echo "nameserver 8.8.8.8" > /etc/resolv.conf
   # dnf -y install cloud-utils-growpart curl epel-release python3 bind-utils
   # dnf -y install openssh-server cloud-init sshpass

Configure cloud-init and set clex as default login user::

   # vi /etc/cloud/cloud.cfg
   ...
   ssh_pwauth: 1
   ...
   system_info:
     default_user:
       name: clex
       lock_passwd: false
       gecos: SKB CloudX User
       groups: [adm, systemd-journal]
       sudo: ["ALL=(ALL) NOPASSWD:ALL"]
       shell: /bin/bash

Enable sshd and cloud-init services.::

   # systemctl enable cloud-init sshd

Run cleanup.sh inside the VM.::

   # vi cleanup.sh  # copy text from cleanup.sh
   # chmod +x cleanup.sh
   # ./cleanup.sh

Exit the console.::

   # rm -f cleanup.sh
   # cat /dev/null > ~/.bash_history && history -c && shutdown -h now

Press CTRL+] to close VM console.

Run virt-sysprep for the VM domain.::

   $ virt-sysprep -d rocky-linux-8
   [   0.0] Examining the guest ...
   [   5.4] Performing "abrt-data" ...
   [   5.4] Performing "backup-files" ...
   [   6.1] Performing "bash-history" ...
   [   6.2] Performing "blkid-tab" ...
   [   6.2] Performing "crash-data" ...
   [   6.2] Performing "cron-spool" ...
   [   6.3] Performing "dhcp-client-state" ...
   [   6.3] Performing "dhcp-server-state" ...
   [   6.3] Performing "dovecot-data" ...
   [   6.3] Performing "logfiles" ...
   [   6.5] Performing "machine-id" ...
   [   6.5] Performing "mail-spool" ...
   [   6.5] Performing "net-hostname" ...
   [   6.6] Performing "net-hwaddr" ...
   [   6.8] Performing "pacct-log" ...
   [   6.8] Performing "package-manager-cache" ...
   [   6.8] Performing "pam-data" ...
   [   6.9] Performing "passwd-backups" ...
   [   6.9] Performing "puppet-data-log" ...
   [   6.9] Performing "rh-subscription-manager" ...
   [   6.9] Performing "rhn-systemid" ...
   [   7.0] Performing "rpm-db" ...
   [   7.0] Performing "samba-db-log" ...
   [   7.0] Performing "script" ...
   [   7.0] Performing "smolt-uuid" ...
   [   7.0] Performing "ssh-hostkeys" ...
   [   7.1] Performing "ssh-userdir" ...
   [   7.1] Performing "sssd-db-log" ...
   [   7.1] Performing "tmp-files" ...
   [   7.1] Performing "udev-persistent-net" ...
   [   7.2] Performing "utmp" ...
   [   7.2] Performing "yum-uuid" ...
   [   7.2] Performing "customize" ...
   [   7.2] Setting a random seed
   [   7.3] Setting the machine ID in /etc/machine-id
   [   7.3] Performing "lvm-uuids" ...

Trim the image.::

   $ cd /data/jijisa/images
   $ mv rocky-8.4-x86_64-genericcloud.qcow2 \
         rocky-8.4-x86_64-genericcloud.qcow2.new
   $ qemu-img convert -O qcow2 rocky-8.4-x86_64-genericcloud.qcow2.new \
                                 rocky-8.4-x86_64-genericcloud.qcow2


It shrank down from 5GiB to about 1.8GiB.

