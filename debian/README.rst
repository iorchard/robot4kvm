Create BKOS images based on Debian 11 Cloud Image
==================================================

This is a guide to create bastion and registry image 
based on Debian 11 cloud image.

To build a bastion image::

   $ ./bkos_bastion_build.sh

To build a registry image::

   $ ./bkos_registry_build.sh

The image name will be bkos_{bastion,registry}.qcow2 respectively.
