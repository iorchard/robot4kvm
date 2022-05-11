*** Settings ***
Documentation    Stop a lab.
Suite Setup      Preflight
Suite Teardown   Cleanup
Library         OperatingSystem
Library         Process
Variables       props.py

*** Tasks ***
Stop a Lab
    [Documentation]     Shutdown virtual machines for a lab.
    [Tags]    stop
    FOR     ${vm}   IN  @{VMS}
        Log     Stop ${vm} and wait for at most 180 seconds.
        ...     console=True
        Run     virsh shutdown ${vm}
        Wait Until Keyword Succeeds     180s     5s
        ...                             Check VM State  ${vm}
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

