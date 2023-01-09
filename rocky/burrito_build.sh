#!/bin/bash
VER=${1:-8.7}
ISO_PATH="/data/jijisa/images/burrito-${VER}.iso"
DISK_PATH="/data/jijisa/images/Burrito-GenericCloud-${VER}-$(date +%Y%m%d%H%M)-x86_64.qcow2"
DISK_SIZE=5
DISK_FORMAT="qcow2"
NET_BRIDGE="br1"

virt-install \
  --name burrito-8 \
  --memory=1024 \
  --vcpus=1 \
  --os-type linux \
  --location ${ISO_PATH} \
  --disk path=${DISK_PATH},size=${DISK_SIZE},format=${DISK_FORMAT}  \
  --network bridge=${NET_BRIDGE} \
  --graphics=none \
  --os-variant=rhl8.0 \
  --console pty,target_type=serial \
  --initrd-inject ks_burrito.cfg \
  --extra-args "inst.ks=file:/ks_burrito.cfg inst.sshd console=tty0 console=ttyS0,115200n8"
