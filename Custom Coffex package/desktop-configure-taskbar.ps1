#This script configures the taskbar layout for the desktop by setting registry values to point to a specified XML file that defines the layout. It also locks the Start layout to prevent users from making changes.

param(
    [System.IO.DirectoryInfo]$ProvisioningFolder
)

# Points to C:\ProgramData\provisioning\desktop-taskbar.xml
$settings = [PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Windows\Explorer"
    Value = "{0}\{1}" -f $ProvisioningFolder.FullName, "desktop-taskbar.xml"
    Name  = "StartLayoutFile"
    Type  = [Microsoft.Win32.RegistryValueKind]::ExpandString
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Windows\Explorer"
    Value = 1
    Name  = "LockedStartLayout"
} | Group-Object Path

foreach ($setting in $settings) {
    
    #$true refers to opening the registry key with write access. If the key doesn't exist, it will be created.
    #$setting.Name refers to the registry path where the value will be set. For example, "SOFTWARE\Policies\Microsoft\Windows\Explorer".
    #It is derived from Group-Object Path cmdlet
    $registry = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($setting.Name, $true)
    if ($null -eq $registry) {
        $registry = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($setting.Name, $true)
    }

    $setting.Group | ForEach-Object {
        if (!$_.Type) {
            #$_.name here refers to the actual registry name e.g. "StartLayoutFile"
            $registry.SetValue($_.name, $_.value) 
        }
        else {
            $registry.SetValue($_.name, $_.value, $_.type)
        }
    }
    $registry.Dispose()
}