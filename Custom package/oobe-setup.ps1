# M365 provisioning disabled
# $usb_drive_name = 'USB-256'

# Prepare provisioning folder
$provisioning = New-Item "$($env:ProgramData)\provisioning" -ItemType Directory -Force

# Execute oobe scripts
. .\oobe-chocolatey.ps1
. .\oobe-associations.ps1 -ProvisioningFolder $provisioning
. .\oobe-bloatware.ps1

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
[PSCustomObject]@{ # Skip privacy experiance
    Path  = "SOFTWARE\Policies\Microsoft\Windows\OOBE"
    Name  = "DisablePrivacyExperience"
    Value = 1
} | Group-Object Path

foreach ($setting in $settings) {
    $registry = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($setting.Name, $true)
    if ($null -eq $registry) {
        $registry = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($setting.Name, $true)
    }
    $setting.Group | ForEach-Object {
        $registry.SetValue($_.name, $_.value)
    }
    $registry.Dispose()
}
