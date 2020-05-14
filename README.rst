Robot4KVM
==========

This is robot automation process for VM setup using KVM hypervisor.

Here is the automated process.

#. Downloads the latest debian stable openstack image and SHA256 checksum
   and signature files.
#. Verify the checksum and image files.
#. Copy the downloaded source image to VM images.
#. Create virsh xml file and interfaces file.
#. Manipulate VM images with vm_man.sh script.
#. Define VM.
#. Start VM.

Pre-requisite
--------------

Install robot framework. I always create virtual env to 
have python environment.::

    $ sudo apt update && sudo apt install -y python3-venv dirmngr
    $ python3 -m venv ~/.envs/robot
    $ source ~/.envs/robot/bin/activate
    (robot) $ pip install wheel
    (robot) $ pip install robotframework

Before running robot codes, edit the following files in data/ directory
for your environment.

* default.tpl: virsh xml template for admin and client vm.
  You can change anything except upper-case placeholder variables 
  like NAME, MEM, CORES, UUID.
* grub: grub file to inject into VM

Copy props.py.sample to props.py 
and edit props.py until "# Do not edit below this line!!!"

Run
-----

To set up VMs::

    (robot) $ read -s -p 'user pw: ' USERPW
    user pw: 
    (robot) $ export USERPW
    (robot) $ robot -d output setup.robot
    (robot) $ unset USERPW

USERPW variable should be set up before running robot tasks.
It is to set up the password of USERID in VM. (USERID is defined in props.py)

You can run each task in setup.robot separately with -i <tag_name> option.

#. Get VM image template.::

    (robot) $ robot -d output -i preflight setup.robot
   
#. Prepare VM image.::

    (robot) $ robot -d output -i takeoff setup.robot

#. Run VM.::

    (robot) $ robot -d output -i flying setup.robot

Tear Down
----------

To tear down VMs.::

    (robot) $ robot -d output teardown.robot

It will stop VMs and delete VM images.
