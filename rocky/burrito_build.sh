#!/bin/bash
VER=${1:-2.1.5}
OS_VER=${2:-8.10}
ISO_PATH="/data/jijisa/images/burrito-${VER}_${OS_VER}.iso"
DISK_PATH="/data/jijisa/images/Burrito-GenericCloud-${VER}_${OS_VER}-$(date +%Y%m%d%H%M)-x86_64.qcow2"
DEST_PATH="/data/jijisa/images/Burrito-GenericCloud-${VER}_${OS_VER}-x86_64.qcow2"
DISK_SIZE=5
DISK_FORMAT="qcow2"
NET_BRIDGE="br1"
VMNAME="burrito-cloud-image"

if $(virsh list --all --name | grep -q "^${VMNAME}$"); then
  if $(virsh list --name | grep -q "^${VMNAME}$"); then
    virsh destroy $VMNAME
  fi
  virsh undefine $VMNAME
fi

virt-install \
  --name $VMNAME \
  --memory=1024 \
  --vcpus=1 \
  --location ${ISO_PATH} \
  --disk path=${DISK_PATH},size=${DISK_SIZE},format=${DISK_FORMAT}  \
  --network bridge=${NET_BRIDGE} \
  --graphics=none \
  --os-variant=rhl8.0 \
  --noautoconsole \
  --console pty,target_type=serial \
  --initrd-inject ks_burrito.cfg \
  --extra-args "inst.ks=file:/ks_burrito.cfg inst.sshd console=tty0 console=ttyS0,115200n8"

while true; do
  if virsh list|grep -qw "burrito-cloud-image"; then
    echo "installing..."
  else
    echo "finished."
    break
  fi
  sleep 5
done

# sysprep
virt-sysprep -d burrito-cloud-image

# sparsify
TMPDIR=/data/jijisa/tmp virt-sparsify "${DISK_PATH}" "${DEST_PATH}"

# clean temporal image
rm -f "${DISK_PATH}"

# show the cloud image
ls -lh "${DEST_PATH}"
