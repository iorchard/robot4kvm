#!/bin/bash

VIRTC="/usr/bin/virt-customize"

# Check if the script is run by root.
if [ ${UID} -eq 0 ]
then
    echo "Error) Do not run this script as root."
    exit 1
fi

# Check if virt-customize exists.
if [ ! -x ${VIRTC} ]
then
    echo "Error) There is no virt-customize commmand."
    exit 1
fi

# packages to install
IPKGS="less,sudo,vim,man-db,dnsutils,curl,gpg,tcpdump"
OPKGS="docker-ce,docker-ce-cli,containerd.io,etcd-discovery"
# Timezone
TIMEZONE="Asia/Seoul"

# docker gpg key url
GPGKEY_URL="-fsSL https://download.docker.com/linux/debian/gpg"
curl -fsSL ${GPGKEY_URL} |gpg --dearmor -o docker.gpg

# docker repo
echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/docker.gpg] https://download.docker.com/linux/debian bullseye stable" | \
    tee docker.list > /dev/null

# get the image
IMG_URL="https://cloud.debian.org/images/cloud/bullseye/latest/"
IMG_FILE="debian-11-genericcloud-amd64.qcow2"
[ ! -f ${IMG_FILE} ] && curl -LO ${IMG_URL}/${IMG_FILE}

$VIRTC -a ${IMG_FILE} \
    --update \
    --install ${IPKGS} \
    --upload docker.gpg:/etc/apt/trusted.gpg.d/docker.gpg \
    --upload docker.list:/etc/apt/sources.list.d/docker.list \
    --install ${OPKGS} \
    --timezone "${TIMEZONE}"

# rename image file
mv ${IMG_FILE} bkos_registry.qcow2
