$power_settings = @(
    "powercfg /x -monitor-timeout-ac 10",
    "powercfg /x -standby-timeout-ac 300",
    #"powercfg /x -hibernate-timeout-ac 0",
    "powercfg /x -monitor-timeout-dc 5",
    "powercfg /x -standby-timeout-dc 120"
    #"powercfg /x -hibernate-timeout-dc 0",
    #"powercfg /setACvalueIndex scheme_current sub_buttons lidAction 0",
    #"powercfg /setDCvalueIndex scheme_current sub_buttons lidAction 0",
    #"powercfg /setActive scheme_current",
) 

$power_settings | ForEach-Object {
    cmd /c $_
}