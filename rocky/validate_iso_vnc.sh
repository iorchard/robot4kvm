#!/bin/bash
set -euo pipefail

VMNAME="pbos-validate"

#BOOT_OPT=${1:-legacy}
BOOT_OPT=${1:-}
if [ "x$BOOT_OPT" != "xlegacy" ] && [ "x$BOOT_OPT" != "xuefi" ]; then
  echo "Usage) $0 legacy|uefi"
  echo "Abort: Unknown boot option $BOOT_OPT. It should be 'legacy' or 'uefi'."
  exit 1
fi
[ "x$BOOT_OPT" = "xuefi" ] && BOOT="--boot uefi" || BOOT=""
ISO_PATH="/data/jijisa/images/pbos-8.5-2202-2.iso"
DISK_PATH="/data/jijisa/images/${VMNAME}-${BOOT_OPT}.qcow2"
DISK_SIZE=5
DISK_FORMAT="qcow2"
NET_BRIDGE="br1"

# check instance already exists and if it does, destroy and undefine it.
if $(virsh list --all --name | grep -q "^${VMNAME}$"); then
  if $(virsh list --name | grep -q "^${VMNAME}$"); then
    virsh destroy $VMNAME
  fi
  virsh undefine $VMNAME
fi

virt-install \
  --name $VMNAME $BOOT \
  --memory=1024 \
  --vcpus=1 \
  --os-type linux \
  --cdrom ${ISO_PATH} \
  --disk path=${DISK_PATH},size=${DISK_SIZE},format=${DISK_FORMAT}  \
  --network bridge=${NET_BRIDGE} \
  --os-variant=rhl8.0 \
  --graphics=vnc,listen=0.0.0.0
