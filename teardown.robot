*** Settings ***
Documentation    Tear down a lab.
Suite Setup      Preflight
Suite Teardown   Cleanup
Library         OperatingSystem
Library         Process
Variables       props.py

*** Tasks ***
Stop virtual machines
    [Documentation]     Stop virtual machines
    [Tags]    stop
    FOR     ${vm}   IN  @{VMS}
        Log     Stop ${vm} and wait for at most 60 seconds.     console=True
        Run     virsh destroy ${vm}
        Wait Until Keyword Succeeds     60s     5s  Check VM State  ${vm}
    END

Delete virtual machines
    [Documentation]     Delete virtual machines
    [Tags]    delete
    FOR     ${vm}   IN  @{VMS}
        Log     Undefine ${vm}     console=True
        Run     virsh undefine ${vm}

        Log     Remove ssh host keys of ${vm}     console=True
        Run     ssh-keygen -R ${vm}
        Run     ssh-keygen -R ${IPS['${vm}']['${REP_BR}']['ip']}
        
        Log     Remove ${vm}     console=True
        Remove File     ${DST_DIR}/${vm}.qcow2
        Run Keyword If	'storage' in ${ROLES}[${vm}]
        ...     Remove File   ${DST_DIR}/${vm}-*.qcow2
		Remove Directory	${DST_DIR}	recursive=True
		Directory Should Not Exist	${DST_DIR}
		Remove Directory	${OSD_DIR}	recursive=True
		Directory Should Not Exist	${OSD_DIR}
    END

*** Keywords ***
Preflight
    Comment     Run before Tasks.

Cleanup
    Comment     Clean up the debris.

Check VM State
    [Arguments]     ${v}
    ${rc}   ${o} =      Run And Return Rc And Output    
    ...     LANG=C virsh domstate ${v}
    Run Keyword If  ${rc} == 0      Should Contain      ${o}    shut

