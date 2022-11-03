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
OPKGS="git,python3-openstackclient,python3-barbicanclient,python3-heatclient,python3-magnumclient,python3-octaviaclient,python3-designateclient"
# Timezone
TIMEZONE="Asia/Seoul"
# openstack gpg key url
GPGKEY_URL="http://osbpo.debian.net/osbpo/dists/pubkey.gpg"
curl -fsSL ${GPGKEY_URL} |gpg --dearmor --yes -o osbpo.gpg

# openstack repo
cat <<EOF > openstack.list
deb http://osbpo.debian.net/osbpo bullseye-yoga-backports main
deb http://osbpo.debian.net/osbpo bullseye-yoga-backports-nochange main
EOF

# get the image
IMG_URL="https://cloud.debian.org/images/cloud/bullseye/latest/"
IMG_FILE="debian-11-genericcloud-amd64.qcow2"
[ ! -f ${IMG_FILE} ] && curl -LO ${IMG_URL}/${IMG_FILE}

$VIRTC -a ${IMG_FILE} \
    --update \
    --install ${IPKGS} \
    --upload osbpo.gpg:/etc/apt/trusted.gpg.d/osbpo.gpg \
    --upload openstack.list:/etc/apt/sources.list.d/openstack.list \
    --install ${OPKGS} \
    --timezone "${TIMEZONE}"

# rename image file
mv ${IMG_FILE} bkos_bastion.qcow2
