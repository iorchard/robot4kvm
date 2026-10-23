#!/bin/bash
VER=${1:-v2.2.19_r6.0.0}
OS_VER=${2:-10.2}
ISO_PATH="/data/jijisa/images/cloudx-${VER}.iso"
DISK_PATH="/data/jijisa/images/CloudX-GenericCloud-${VER}_${OS_VER}-$(date +%Y%m%d%H%M)-x86_64.qcow2"
DEST_PATH="/data/jijisa/images/CloudX-GenericCloud-${VER}_${OS_VER}-x86_64.qcow2"
DISK_SIZE=5
DISK_FORMAT="qcow2"
NET_BRIDGE="br1"
VMNAME="cloudx-cloud-image"

if $(virsh list --all --name | grep -q "^${VMNAME}$"); then
  if $(virsh list --name | grep -q "^${VMNAME}$"); then
    virsh destroy $VMNAME
  fi
  virsh undefine --nvram $VMNAME
fi

virt-install \
  --name $VMNAME \
  --boot uefi \
  --memory=4096 \
  --vcpus=1 \
  --location ${ISO_PATH} \
  --disk path=${DISK_PATH},size=${DISK_SIZE},format=${DISK_FORMAT},target.bus=scsi  \
  --disk path=${ISO_PATH},device=cdrom,target.bus=scsi \
  --controller type=scsi,model=virtio-scsi \
  --network bridge=${NET_BRIDGE},model=virtio \
  --graphics=none \
  --os-variant=rhl8.0 \
  --noautoconsole \
  --console pty,target_type=serial \
  --initrd-inject ks_cloudx.cfg \
  --extra-args "inst.ks=file:/ks_cloudx.cfg inst.sshd console=tty0 console=ttyS0,115200n8"

while true; do
  if virsh list|grep -qw "cloudx-cloud-image"; then
    echo "installing..."
  else
    echo "finished."
    break
  fi
  sleep 5
done

# sysprep
virt-sysprep -d cloudx-cloud-image

# sparsify
TMPDIR=/data/jijisa/tmp virt-sparsify "${DISK_PATH}" "${DEST_PATH}"

# clean temporal image
rm -f "${DISK_PATH}"

# show the cloud image
ls -lh "${DEST_PATH}"
