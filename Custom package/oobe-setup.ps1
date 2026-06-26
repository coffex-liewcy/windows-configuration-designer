# M365 provisioning disabled
# $usb_drive_name = 'USB-256'

# Prepare provisioning folder
$provisioning = New-Item "$($env:ProgramData)\provisioning" -ItemType Directory -Force

# Execute oobe scripts
. .\oobe-powersettings.ps1
. .\oobe-chocolatey.ps1
. .\oobe-associations.ps1 -ProvisioningFolder $provisioning
. .\oobe-bloatware.ps1
. .\oobe-chrome-extensions.ps1

# Move files from provisioning package to provisioning folder
Get-ChildItem -File | Where-Object { $_.Name -notlike "oobe-*" -and $_.Name -notlike "chocolatey*"  -and $_.Name -ne "start2.bin"} | ForEach-Object {
    Copy-Item $_.FullName "$($provisioning.FullName)\$($_.Name)" -Force
}

# Create local admin account
$local_user = @{
    Name       = 'itsupport'
    NoPassword = $true
}

$user = New-LocalUser @local_user 
$user | Set-LocalUser -PasswordNeverExpires $true 
$user | Add-LocalGroupMember -Group "Administrators"

<#
# Move Microsoft 365 files to C:\Windows\Temp
$driveLetter = Get-Volume | Where-Object { $_.FileSystemLabel -eq $usb_drive_name } | Select-Object -ExpandProperty DriveLetter
$copy_m365 = @{
    Path        = "$($driveLetter):\m365"
    Destination = "$($env:SystemRoot)\TEMP"
    Recurse     = $true
}
Copy-Item @copy_m365
#>

# Join Workgroup
Add-Computer -WorkgroupName "MYPJCOFFEX"

# Remove Microsoft Edge shortcut from desktop
# Remove-Item "$($env:PUBLIC)\Desktop\Microsoft Edge.lnk" -ErrorAction SilentlyContinue
Get-ChildItem -Path "$env:PUBLIC\Desktop" -Filter "*Edge*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force


# Disable BitLocker for each volume
Get-BitLockerVolume | Where-Object { $_.VolumeStatus -ne 'FullyDecrypted' } | ForEach-Object {
    Disable-BitLocker -MountPoint $_.MountPoint
}

# --- Machine-wide configuration (HKLM\SOFTWARE\Policies) goes here ---

$settings =
[PSCustomObject]@{ # Execute desktop-provisioning.ps1
    Path  = "SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    Name  = "execute_provisioning"
    Value = "cmd /c powershell.exe -ExecutionPolicy Bypass -File {0}\desktop-update-provisioning.ps1 -First" -f $provisioning.FullName
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Dsh"
    Value = 0
    Name  = "AllowNewsAndInterests"
},
[PSCustomObject]@{ # Prevent Edge from creating desktop shortcut on install/update
    Path  = "SOFTWARE\Policies\Microsoft\EdgeUpdate"
    Name  = "CreateDesktopShortcutDefault"
    Value = 0
},
<#
[PSCustomObject]@{ # Force delete system-level and user-level Desktop Shortcuts
    Path  = "SOFTWARE\Policies\Microsoft\EdgeUpdate"
    Name  = "RemoveDesktopShortcutDefault"
    Value = 2
}
#>
[PSCustomObject]@{ # Skip privacy experience
    Path  = "SOFTWARE\Policies\Microsoft\Windows\OOBE"
    Name  = "DisablePrivacyExperience"
    Value = 1
},
[PSCustomObject]@{ # Use "Active Setup" to import desktop-icons.reg
    Path  = "SOFTWARE\Microsoft\Active Setup\Installed Components\DesktopIcons"
    Name  = "StubPath"
    Value = 'reg import "{0}\desktop-icons.reg"' -f $provisioning.FullName
},
# --- NEW ENTRIES MOVED FROM desktop-configure-taskbar.ps1 ---
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Windows\Explorer"
    Name  = "StartLayoutFile"
    Value = "{0}\desktop-taskbar.xml" -f $provisioning.FullName
    Type  = [Microsoft.Win32.RegistryValueKind]::ExpandString
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Windows\Explorer"
    Name  = "LockedStartLayout"
    Value = 1
} | Group-Object Path

foreach ($setting in $settings) {
    $registry = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($setting.Name, $true)
    if ($null -eq $registry) {
        $registry = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($setting.Name, $true)
    }
    
    # Updated loop to handle Registry Value Types
    $setting.Group | ForEach-Object {
        if ($_.Type) {
            $registry.SetValue($_.Name, $_.Value, $_.Type)
        } else {
            $registry.SetValue($_.Name, $_.Value)
        }
    }

    $registry.Dispose()
}
