*** Settings ***
Documentation    Build VM for a lab.
Suite Setup      Preflight
Suite Teardown   Cleanup
Library         OperatingSystem
Library         Process
Variables       props.py

*** Variables ***
${VM_MAN}       ${CURDIR}/scripts/vm_man.sh
${MACGEN}       ${CURDIR}/scripts/macgen.sh

*** Tasks ***
Get And Verify Debian Image
    [Documentation]     Get debian openstack image.
    [Tags]  preflight
    Log     Get debian image from ${IMG_URL}/${IMG}   console=True
    ${rc} =   Run Keyword If  os.path.exists("${SRC_DIR}/${IMG}") == False
    ...     Run And Return Rc
    ...     curl -sLo ${SRC_DIR}/${IMG} ${IMG_URL}/${IMG}

    Log     curl -sLo ${SRC_DIR}/SHA256SUMS ${IMG_URL}/SHA256SUMS   console=True
    ${rc} =     Run And Return Rc
    ...     curl -sLo ${SRC_DIR}/SHA256SUMS ${IMG_URL}/SHA256SUMS
    Should Be Equal As Integers     ${rc}   0
    ...     msg="Fail to get SHA256SUMS."

    ${rc} =     Run And Return Rc
    ...     curl -sLo ${SRC_DIR}/SHA256SUMS.sign ${IMG_URL}/SHA256SUMS.sign
    Should Be Equal As Integers     ${rc}   0
    ...     msg="Fail to get SHA256SUMS.sign."

    Log     gpg --verify ${SRC_DIR}/SHA256SUMS.sign ${SRC_DIR}/SHA256SUMS   console=True
    ${rc} =     Run And Return Rc
    ...     gpg --verify ${SRC_DIR}/SHA256SUMS.sign ${SRC_DIR}/SHA256SUMS
    Should Be Equal As Integers     ${rc}   0
    ...     msg="Fail to verify GPG SHA256SUMS."

    Log     Verify debian image with SHA checksum.   console=True
    ${result} =     Run Process
    ...     grep ${IMG}\$ ${SRC_DIR}/SHA256SUMS|sha256sum --check --quiet -
    ...     shell=yes   cwd=${SRC_DIR}
    Run Keyword If  ${result.rc} != 0   Remove File     ${SRC_DIR}/${IMG}
    Should Be Equal As Integers     ${result.rc}   0
    ...     msg="Fail to verify SHA checksum for ${IMG}."

Set Up Lab
    [Documentation]     Set up virtual machines.
    [Tags]    takeoff
    FOR     ${vm}   IN  @{VMS}
        Log     Link ${SRC_DIR}/${IMG} to ${DST_DIR}/${vm}.qcow2     
        ...     console=True
        ${rc} =     Run And Return Rc
        ...     qemu-img create -f qcow2 -b ${SRC_DIR}/${IMG} ${DST_DIR}/${vm}.qcow2
        Should Be Equal As Integers     ${rc}   0   
        #Copy File   ${SRC_DIR}/${IMG}   ${DST_DIR}/${vm}.qcow2

		Log		Resize the image to ${DISK}[${vm}]G.	console=True
        ${rc} =     Run And Return Rc
        ...     qemu-img resize ${DST_DIR}/${vm}.qcow2 ${DISK}[${vm}]G
        Should Be Equal As Integers     ${rc}   0

		Log		Resize root partition to 100%.		console=True
        ${rc} =     Run And Return Rc
        ...     virt-resize --expand /dev/sda1 ${SRC_DIR}/${IMG} ${DST_DIR}/${vm}.qcow2
        Should Be Equal As Integers     ${rc}   0

        ${rc}   ${uuid} =   Run And Return Rc And Output
        ...     cat /proc/sys/kernel/random/uuid
        Should Be Equal As Integers     ${rc}   0   
        ${rc}   ${mac1} =    Run And Return Rc And Output	${MACGEN}
        Should Be Equal As Integers     ${rc}   0   
        ${rc}   ${mac2} =    Run And Return Rc And Output	${MACGEN}
        Should Be Equal As Integers     ${rc}   0   
        Create Interfaces File      ${IPS}[${vm}]

        Log        ${vm}: Add VM IP in /etc/hosts.    console=True
        ${rc} =        Run And Return Rc
        ...        grep -q "${IPS}[${vm}][0].*${vm}" /etc/hosts
        Run Keyword If    ${rc} != 0        Run 
        ...		echo "${IPS}[${vm}][0] ${vm} # ${OS}"|sudo tee -a /etc/hosts

        Log     Run ${VM_MAN}     console=True
        ${rc}   ${out} =     Run And Return Rc And Output
        ...     ${VM_MAN} -f ${DST_DIR}/${vm}.qcow2 -u ${USERID}
        Should Be Equal As Integers     ${rc}   0   
        ...     msg="vm_man failed: ${out}"

        Log     Create XML for ${vm}    console=True
        Run Keyword If  'storage' in ${ROLES}[${vm}]
        ...     Create XML  ${vm}   ${uuid}    ${mac1}   ${mac2}   osd.tpl
        ...     ELSE
        ...     Create XML  ${vm}   ${uuid}    ${mac1}   ${mac2}   default.tpl

        Log     Create OSD disks for ${vm}    console=True
        Run Keyword If  'storage' in ${ROLES}[${vm}]
		...		Create OSD Disks	${vm}

        Log     Define VM     console=True
        ${rc} =     Run And Return Rc
        ...     virsh define ${TEMPDIR}/xml
        Should Be Equal As Integers     ${rc}   0

    END

Start Lab
    [Documentation]     Start virtual machines. 
    [Tags]    flying
    FOR     ${vm}   IN  @{VMS}
        Log     Start ${vm}     console=True
        ${rc} =     Run And Return Rc     virsh start ${vm}
        Should Be Equal As Integers     ${rc}   0
    END

*** Keywords ***
Preflight
    Comment     Run before Tasks.
    Log     Set up GPG keyring      console=True
    ${rc} =     Run And Return Rc
    ...     gpg --list-keys ${DEB_KEYID} || gpg --keyserver ${DEB_KEYSERVER} --recv-keys ${DEB_KEYID}
    Should Be Equal As Integers     ${rc}   0

	${rc} =		Run And Return Rc	ls -ld ${SRC_DIR}
	Run Keyword If		${rc} != 0		Create Directory	${SRC_DIR}
	${rc} =		Run And Return Rc	ls -ld ${DST_DIR}
	Run Keyword If		${rc} != 0		Create Directory	${DST_DIR}

	Log		Create ${SSHKEY} if not exists		console=True
    ${rc} =        Run And Return Rc    ls ${SSHKEY}
    Run Keyword If    ${rc} != 0        
	...		Run		ssh-keygen -t rsa -N '' -f ${SSHKEY}

Cleanup
    Comment     Clean up the debris.
    Log     Remove temporary files.		console=True
    Remove File     ${SRC_DIR}/SHA256SUM*
    Remove Files     ${TEMPDIR}/xml     ${TEMPDIR}/interfaces

Create Interfaces File
    [Arguments]     ${ips}
    ${rc} =     Run And Return Rc
    ...     sed -e 's/IP1/${IPS}[0]/;s/IP2/${IPS}[1]/;s/GW/${GW}/' data/interfaces.tpl > ${TEMPDIR}/interfaces
    Should Be Equal As Integers     ${rc}   0

Create XML
    [Documentation]     Create XML.
    [Arguments]     ${vm}   ${uuid}     ${mac1}     ${mac2}     ${tpl}
    ${rc} =     Run And Return Rc
    ...     sed -e 's/NAME/${vm}/;s/UUID/${uuid}/;s/MEM/${MEM}[${vm}]/;s/CORES/${CORES}[${vm}]/;s#DST_DIR#${DST_DIR}#;s/MAC1/${mac1}/;s/MAC2/${mac2}/' data/${tpl} > ${TEMPDIR}/xml
    Should Be Equal As Integers     ${rc}   0

Create OSD Disks
    [Documentation]     Create OSD disks.
    [Arguments]     ${vm}

	${end} =	Evaluate	${OSD_NUM} + 1
    FOR     ${drv}  IN RANGE	1	${end}
        ${rc} =     Run And Return Rc
        ...     qemu-img create -f qcow2 ${DST_DIR}/${vm}-${drv}.qcow2 ${OSD_SIZE}G
        Should Be Equal As Integers     ${rc}   0
    END
