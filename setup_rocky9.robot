*** Settings ***
Documentation    Build VM for a lab.
Suite Setup      Preflight
#Suite Teardown   Cleanup
Library         OperatingSystem
Library         Process
Variables       props.py

*** Variables ***
${VM_MAN}       ${CURDIR}/scripts/vm_man4rocky9.sh
${MACGEN}       ${CURDIR}/scripts/macgen.sh
@{LETTERS}      a   b   c   d   e   f   g   h

*** Tasks ***
Set Up Lab
    [Documentation]     Set up virtual machines.
    [Tags]    takeoff
    #Set Environment Variable    LIBGUESTFS_HV   ${CURDIR}/scripts/qemu-wrap.sh
    #Log     %{LIBGUESTFS_HV}    console=True
    Run     echo "127.0.0.1 localhost"|sudo tee data/hosts
    Log     \n      console=True
    FOR     ${vm}   IN  @{VMS}
        Log        ${vm}: Add VM IP in /etc/hosts.    console=True
        ${rc} =        Run And Return Rc
        ...    grep -q "${IPS['${vm}']['${REP_BR}']['ip']}.*${vm}" /etc/hosts
        Run Keyword If    ${rc} != 0        Run 
        ...        echo "${IPS['${vm}']['${REP_BR}']['ip']} ${vm} # ${OS}"|sudo tee -a /etc/hosts
        Run     echo "${IPS['${vm}']['${REP_BR}']['ip']} ${vm} # ${OS}"|sudo tee -a data/hosts
    END

    Log     Copy ${SRC_DIR}/${IMG} to ${DST_DIR}/base.qcow2     console=True
    Copy File   ${SRC_DIR}/${IMG}   ${DST_DIR}/base.qcow2

    FOR     ${vm}   IN  @{VMS}
        Log     Create ${DST_DIR}/${vm}.qcow2 based on ${DST_DIR}/base.qcow2
        ...     console=True
        ${rc} =     Run And Return Rc
        ...     qemu-img create -f qcow2 -F qcow2 -b ${DST_DIR}/base.qcow2 ${DST_DIR}/${vm}.qcow2
        Should Be Equal As Integers     ${rc}   0

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

        Log     Create XML for ${vm}    console=True
        Create XML  ${vm}   ${uuid}    default.tpl

        Log     Define VM     console=True
        ${rc} =     Wait Until Keyword Succeeds		3x	1s
		...		Run And Return Rc	virsh define ${TEMPDIR}/xml
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
    Log     \n      console=True
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
    ${rc} =        Run And Return Rc    ls -ld ${OSD_DIR}
    Run Keyword If        ${rc} != 0        Create Directory    ${OSD_DIR}

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
    [Documentation]        Create Interfaces
    [Arguments]        ${vm}    ${ifaces}
    ${i} =        Set Variable    0
    Remove File     ${TEMPDIR}/ifcfg*
    FOR     ${br}   IN         @{ifaces}
        ${rc}   ${nmuuid} =   Run And Return Rc And Output
        ...     cat /proc/sys/kernel/random/uuid

        Log        ${vm}:${br}:${ifaces['${br}']}        console=True
        ${netinfo} =    Set Variable    ${ifaces['${br}']}

        ${rc}   ${mac} =    Run And Return Rc And Output    ${MACGEN}
        Should Be Equal As Integers     ${rc}   0

        Run     virsh attach-interface --domain ${vm} --type bridge --source ${br} --model virtio --mac ${mac} --persistent

        Run Keyword If    "${netinfo['ip']}" == ""
        ...         Create File     ${TEMPDIR}/eth${i}.nmconnection
        ...         [connection]\nid=${netinfo['id']}\nuuid=${nmuuid}\ntype=ethernet\ninterface-name=eth${i}\n[ethernet]\n\n[ipv4]\nmethod=disabled\nnever-default=true\n[ipv6]\nmethod=disabled\n
        ...     ELSE IF     'gw' in ${netinfo}
        ...         Create File     ${TEMPDIR}/eth${i}.nmconnection
        ...         [connection]\nid=${netinfo['id']}\nuuid=${nmuuid}\ntype=ethernet\ninterface-name=eth${i}\n[ethernet]\n\n[ipv4]\naddress1=${netinfo['ip']}/${netinfo['nm']}\ngateway=${netinfo['gw']}\nmethod=manual\n[ipv6]\nmethod=disabled\n
        ...     ELSE
        ...         Create File     ${TEMPDIR}/eth${i}.nmconnection
        ...         [connection]\nid=${netinfo['id']}\nuuid=${nmuuid}\ntype=ethernet\ninterface-name=eth${i}\n[ethernet]\n\n[ipv4]\naddress1=${netinfo['ip']}/${netinfo['nm']}\nmethod=manual\nnever-default=true\n[ipv6]\nmethod=disabled\n
        ${i} =        Evaluate    ${i} + 1
    END
