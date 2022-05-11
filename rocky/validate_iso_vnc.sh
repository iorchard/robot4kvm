#!/bin/bash
set -euo pipefail

BOOT_OPT=${1:-legacy}
if [ "x$BOOT_OPT" != "xlegacy" ] && [ "x$BOOT_OPT" != "xuefi" ]; then
  echo "Abort: Unknown $BOOT_OPT. It should be 'legacy' or 'uefi'."
  exit 1
fi
[ "x$BOOT_OPT" = "xuefi" ] && BOOT="--boot uefi" || true
ISO_PATH="/data/jijisa/images/pbos-8.5-2202.iso"
DISK_PATH="/data/jijisa/images/pbos-${BOOT_OPT}.qcow2"
DISK_SIZE=5
DISK_FORMAT="qcow2"
NET_BRIDGE="br1"

virt-install \
  --name pbos-validate $BOOT \
  --memory=1024 \
  --vcpus=1 \
  --os-type linux \
  --cdrom ${ISO_PATH} \
  --disk path=${DISK_PATH},size=${DISK_SIZE},format=${DISK_FORMAT}  \
  --network bridge=${NET_BRIDGE} \
  --os-variant=rhl8.0 \
  --graphics=vnc,listen=0.0.0.0