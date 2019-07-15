*** Settings ***
Documentation    Build VM for a lab.
Suite Setup      Preflight
#Suite Teardown   Cleanup
Library         OperatingSystem
Library         Process
Variables       props.py

*** Variables ***
${VM_MAN}       ${CURDIR}/scripts/vm_man4centos.sh
${MACGEN}       ${CURDIR}/scripts/macgen.sh
@{LETTERS}      a   b   c   d   e   f   g   h

*** Tasks ***
Test
    [Documentation]     Test
    [Tags]  test
    FOR     ${vm}   IN  @{VMS}
        Create Interfaces    ${vm}  ${IPS}[${vm}]
    END

Get The Image
    [Documentation]     Get centos openstack image.
    [Tags]  preflight
    Log     Get centos image from ${IMG_URL}/${IMG}   console=True
    ${rc} =   Run Keyword If  os.path.exists("${SRC_DIR}/${IMG}") == False
    ...     Run And Return Rc
    ...     curl -sLo ${SRC_DIR}/${IMG} ${IMG_URL}/${IMG}

    Log     Set image ReadOnly   console=True
    Run        chmod 0400 ${SRC_DIR}/${IMG}

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

        Log        Resize the image to ${DISK}[${vm}]G.    console=True
        ${rc} =     Run And Return Rc
        ...     qemu-img resize ${DST_DIR}/${vm}.qcow2 ${DISK}[${vm}]G
        Should Be Equal As Integers     ${rc}   0

        Log        Resize root partition to 100%.        console=True
        ${rc} =     Run And Return Rc
        ...     virt-resize --expand /dev/sda1 ${SRC_DIR}/${IMG} ${DST_DIR}/${vm}.qcow2
        Should Be Equal As Integers     ${rc}   0

        ${rc}   ${uuid} =   Run And Return Rc And Output
        ...     cat /proc/sys/kernel/random/uuid

        Log        ${vm}: Add VM IP in /etc/hosts.    console=True
        ${rc} =        Run And Return Rc
        ...        grep -q "${IPS}[${vm}][1].*${vm}" /etc/hosts
        Run Keyword If    ${rc} != 0        Run 
        ...        echo "${IPS}[${vm}][1] ${vm} # ${OS}"|sudo tee -a /etc/hosts

        Log     Create XML for ${vm}    console=True
        Create XML  ${vm}   ${uuid}    default.tpl

        Log     Define VM     console=True
        ${rc} =     Run And Return Rc
        ...     virsh define ${TEMPDIR}/xml
        Should Be Equal As Integers     ${rc}   0

        Log     Create disk for ${vm}    console=True
        Create Disk     ${vm}

        Log     Attach interfaces to ${vm}        console=True
        Create Interfaces        ${vm}  ${IPS}[${vm}]

        Log     Run ${VM_MAN}       console=True
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
    ${rc} =        Run And Return Rc    ls -ld ${SRC_DIR}
    Run Keyword If        ${rc} != 0        Create Directory    ${SRC_DIR}
    ${rc} =        Run And Return Rc    ls -ld ${DST_DIR}
    Run Keyword If        ${rc} != 0        Create Directory    ${DST_DIR}

    Log        Create ${SSHKEY} if not exists        console=True
    ${rc} =        Run And Return Rc    ls ${SSHKEY}
    Run Keyword If    ${rc} != 0        
    ...        Run        ssh-keygen -t rsa -N '' -f ${SSHKEY}

Cleanup
    Comment     Clean up the debris.
    Log     Remove temporary files.        console=True
    Remove File     ${SRC_DIR}/SHA256SUM*
    Remove Files     ${TEMPDIR}/xml     ${TEMPDIR}/interfaces

Create XML
    [Documentation]     Create XML.
    [Arguments]     ${vm}   ${uuid}     ${tpl}
    ${rc} =     Run And Return Rc
    ...     sed -e 's/NAME/${vm}/;s/UUID/${uuid}/;s/MEM/${MEM}[${vm}]/;s/CORES/${CORES}[${vm}]/' data/${tpl} > ${TEMPDIR}/xml
    Should Be Equal As Integers     ${rc}   0

Create Disk
    [Arguments]     ${vm}
    Run     virsh attach-disk ${vm} ${DST_DIR}/${vm}.qcow2 vda --driver qemu --subdriver qcow2 --targetbus virtio --persistent

    Run Keyword If  'storage' in ${ROLES}[${vm}]
    ...        Create OSD Disks    ${vm}

Create OSD Disks
    [Documentation]     Create OSD disks.
    [Arguments]     ${vm}

    ${end} =    Evaluate    ${OSD_NUM} + 1
    FOR     ${drv}  IN RANGE    1    ${end}
        ${rc} =     Run And Return Rc
        ...     qemu-img create -f qcow2 ${DST_DIR}/${vm}-${drv}.qcow2 ${OSD_SIZE}G
        Should Be Equal As Integers     ${rc}   0
        Run     virsh attach-disk ${vm} ${DST_DIR}/${vm}-${drv}.qcow2 vd${LETTERS}[${drv}] --driver qemu --subdriver qcow2 --targetbus virtio --persistent
    END

Create Interfaces
    [Documentation]        Create Interfaces
    [Arguments]        ${vm}    ${ip_list}
    ${index} =        Set Variable    0
    Remove File     ${TEMPDIR}/ifcfg*
    FOR     ${ip}   IN         @{ip_list}
        Log        ${index}:${ip}        console=True
        Attach Interface   ${vm}    ${index}   ${ip}
        ${index} =        Evaluate    ${index} + 1
    END

Attach Interface
    [Arguments]     ${vm}   ${index}    ${ip}
    ${rc}   ${mac} =    Run And Return Rc And Output    ${MACGEN}
    Should Be Equal As Integers     ${rc}   0

    Run     virsh attach-interface --domain ${vm} --type bridge --source virbr${index} --model virtio --mac ${mac} --persistent

    Run Keyword If  "${ip}" == "" 
    ...     Create File     ${TEMPDIR}/ifcfg-eth${index}
    ...     DEVICE=eth${index}\nHWADDR=${mac}\nONBOOT=yes
    ...     ELSE IF     "${index}" == "0"
    ...     Create File     ${TEMPDIR}/ifcfg-eth${index}
    ...     DEVICE=eth${index}\nHWADDR=${mac}\nGATEWAY=${GW}\nIPADDR=${ip}\nNETMASK=255.255.255.0\nONBOOT=yes
    ...     ELSE
    ...     Create File     ${TEMPDIR}/ifcfg-eth${index}
    ...     DEVICE=eth${index}\nHWADDR=${mac}\nIPADDR=${ip}\nNETMASK=255.255.255.0\nONBOOT=yes
    
