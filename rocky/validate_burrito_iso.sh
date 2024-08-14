#!/bin/bash
set -euo pipefail

BOOT_OPT=${1:-}
if [ "x$BOOT_OPT" != "xlegacy" ] && [ "x$BOOT_OPT" != "xuefi" ]; then
  echo "Usage) $0 legacy|uefi"
  echo "Abort: Unknown boot option $BOOT_OPT. It should be 'legacy' or 'uefi'."
  exit 1
fi

VMNAME="burrito-validate-${BOOT_OPT}"
[ "x$BOOT_OPT" = "xuefi" ] && BOOT="--boot uefi" || BOOT=""
ISO_PATH="/data/jijisa/images/burrito-2.1.0_8.10.iso"
DISK_PATH="/data/jijisa/images/${VMNAME}.qcow2"
DISK_SIZE=50
DISK_FORMAT="qcow2"
NET_BRIDGE="br1"

# check instance already exists and if it does, destroy and undefine it.
if $(virsh list --all --name | grep -q "^${VMNAME}$"); then
  if $(virsh list --name | grep -q "^${VMNAME}$"); then
    virsh destroy $VMNAME
  fi
  if [ "x$BOOT_OPT" = "xuefi" ]; then
    virsh undefine --nvram $VMNAME
  else
    virsh undefine $VMNAME
  fi
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
