#!/bin/bash
ISO_PATH="/data/jijisa/images/pbos-8.5.iso"
DISK_PATH="/data/jijisa/images/pbos.qcow2"
DISK_SIZE=5
DISK_FORMAT="qcow2"
NET_BRIDGE="br1"

virt-install \
  --name pbos-validate \
  --memory=1024 \
  --vcpus=1 \
  --os-type linux \
  --cdrom ${ISO_PATH} \
  --disk path=${DISK_PATH},size=${DISK_SIZE},format=${DISK_FORMAT}  \
  --network bridge=${NET_BRIDGE} \
  --os-variant=rhl8.0 \
  --graphics=vnc,listen=0.0.0.0
