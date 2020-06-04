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
@{LETTERS}      a   b   c   d   e   f   g   h

*** Tasks ***
Get And Verify Debian Image
    [Documentation]     Get debian openstack image.
    [Tags]  preflight
    Log     Get debian image from ${IMG_URL}/${IMG}   console=True
    ${rc} =   Run Keyword If  os.path.exists("${SRC_DIR}/${IMG}") == False
    ...     Run And Return Rc
    ...     curl -sLo ${SRC_DIR}/${IMG} ${IMG_URL}/${IMG}

    Log     Get SHA256 checksum of the image ${IMG}.   console=True
    ${rc} =     Run And Return Rc
    ...     curl -sLo ${SRC_DIR}/SHA256SUMS ${IMG_URL}/SHA256SUMS
    Should Be Equal As Integers     ${rc}   0
    ...     msg="Fail to get SHA256SUMS."

## Currently there is no sign file in buster url. So skip it.
#    ${rc} =     Run And Return Rc
#    ...     curl -sLo ${SRC_DIR}/SHA256SUMS.sign ${IMG_URL}/SHA256SUMS.sign
#    Should Be Equal As Integers     ${rc}   0
#    ...     msg="Fail to get SHA256SUMS.sign."
#
#    Log     gpg --verify ${SRC_DIR}/SHA256SUMS.sign ${SRC_DIR}/SHA256SUMS   console=True
#    ${rc} =     Run And Return Rc
#    ...     gpg --verify ${SRC_DIR}/SHA256SUMS.sign ${SRC_DIR}/SHA256SUMS
#    Should Be Equal As Integers     ${rc}   0
#    ...     msg="Fail to verify GPG SHA256SUMS."

    Log     Verify debian image with SHA checksum.   console=True
    ${result} =     Run Process
    ...     grep ${IMG}\$ SHA256SUMS|sha256sum --check --quiet -
    ...     shell=yes   cwd=${SRC_DIR}
    Should Be Equal As Integers     ${result.rc}   0
    ...     msg="Fail to verify SHA checksum for ${IMG}."

Set Up Lab
    [Documentation]     Set up virtual machines.
    [Tags]    takeoff
    FOR     ${vm}   IN  @{VMS}
        Log        ${vm}: Add VM IP in /etc/hosts.    console=True
        ${rc} =        Run And Return Rc
        ...    grep -q "${IPS['${vm}']['${REP_BR}']['ip']}.*${vm}" /etc/hosts
        Run Keyword If    ${rc} != 0        Run 
        ...		echo "${IPS['${vm}']['${REP_BR}']['ip']} ${vm} # ${OS}"|sudo tee -a /etc/hosts
    END

    FOR     ${vm}   IN  @{VMS}
        Log     Copy ${SRC_DIR}/${IMG} to ${DST_DIR}/${vm}.qcow2     
        ...     console=True
        Copy File   ${SRC_DIR}/${IMG}   ${DST_DIR}/${vm}.qcow2

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

        Log     Create XML for ${vm}    console=True
        Create XML  ${vm}   ${uuid}    default.tpl

        Log     Define VM     console=True
        ${rc} =     Run And Return Rc
        ...     virsh define ${TEMPDIR}/xml
        Should Be Equal As Integers     ${rc}   0

        Log     Create disk for ${vm}       console=True
        Create Disk     ${vm}

        Log     Create interfaces to ${vm}  console=True
        Create Interfaces       ${vm}   ${IPS}[${vm}]

        Log     Run ${VM_MAN}     console=True
        ${rc}   ${out} =     Run And Return Rc And Output
        ...     ${VM_MAN} -f ${DST_DIR}/${vm}.qcow2 -u ${USERID}
        Should Be Equal As Integers     ${rc}   0   
        ...     msg="vm_man failed: ${out}"
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

    Log     Check directories       console=True
	${rc} =		Run And Return Rc	ls -ld ${SRC_DIR}
	Run Keyword If		${rc} != 0		Create Directory	${SRC_DIR}
	${rc} =		Run And Return Rc	ls -ld ${DST_DIR}
	Run Keyword If		${rc} != 0		Create Directory	${DST_DIR}
	${rc} =		Run And Return Rc	ls -ld ${OSD_DIR}
	Run Keyword If		${rc} != 0		Create Directory	${OSD_DIR}

	Log		Create ${SSHKEY} if not exists		console=True
    ${rc} =        Run And Return Rc    ls ${SSHKEY}
    Run Keyword If    ${rc} != 0        
	...		Run		ssh-keygen -t rsa -N '' -f ${SSHKEY}

Cleanup
    Comment     Clean up the debris.
    Log     Remove temporary files.		console=True
    Remove File     ${SRC_DIR}/SHA256SUM*
    Remove Files     ${TEMPDIR}/xml

Create XML
    [Documentation]     Create XML.
    [Arguments]     ${vm}   ${uuid}     ${tpl}
    ${rc} =     Run And Return Rc
    ...     sed -e 's/NAME/${vm}/;s/UUID/${uuid}/;s/MEM/${MEM}[${vm}]/;s/CORES/${CORES}[${vm}]/' data/${tpl} > ${TEMPDIR}/xml
    Should Be Equal As Integers     ${rc}   0

Create Disk
    [Arguments]     ${vm}
    Run     virsh attach-disk ${vm} ${DST_DIR}/${vm}.qcow2 sda --driver qemu --subdriver qcow2 --targetbus scsi --persistent 

    Run Keyword If  'storage' in ${ROLES}[${vm}]
    ...        Create OSD Disks    ${vm}

Create OSD Disks
    [Documentation]     Create OSD disks.
    [Arguments]     ${vm}

    ${end} =    Evaluate    ${OSD_NUM} + 1
    FOR     ${drv}  IN RANGE    1    ${end}
        ${rc} =     Run And Return Rc
        ...     qemu-img create -f qcow2 ${OSD_DIR}/${vm}-${drv}.qcow2 ${OSD_SIZE}G
        Should Be Equal As Integers     ${rc}   0
        Run     virsh attach-disk ${vm} ${OSD_DIR}/${vm}-${drv}.qcow2 sd${LETTERS}[${drv}] --driver qemu --subdriver qcow2 --targetbus scsi --persistent
    END

Create Interfaces
    [Documentation]     Create Interfaces.
    [Arguments]     ${vm}   ${ifaces}
    ${i} =      Set Variable    0
    Remove File     ${TEMPDIR}/eth*
    FOR     ${br}   IN      @{ifaces}
        Log     ${vm}:${br}:${ifaces['${br}']}      console=True
		${netinfo} =	Set Variable	${ifaces['${br}']}

		${rc}   ${mac} =    Run And Return Rc And Output    ${MACGEN}
		Should Be Equal As Integers     ${rc}   0

		Run     virsh attach-interface --domain ${vm} --type bridge --source ${br} --model virtio --mac ${mac} --persistent

		Run Keyword If	"${netinfo['ip']}" == ""
		...		Create File		${TEMPDIR}/eth${i}
		...		auto eth${i}\niface eth${i} inet manual\n
		...		ELSE IF		'gw' in ${netinfo}
        ...     Create File     ${TEMPDIR}/eth${i}
        ...     auto eth${i}\niface eth${i} inet static\n\taddress ${netinfo['ip']}/${netinfo['nm']}\n\tgateway ${netinfo['gw']}\n
        ...     ELSE
        ...     Create File     ${TEMPDIR}/eth${i}
        ...     auto eth${i}\niface eth${i} inet static\n\taddress ${netinfo['ip']}/${netinfo['nm']}\n
        ${i} =      Evaluate    ${i} + 1
    END
