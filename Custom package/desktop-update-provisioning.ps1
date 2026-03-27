param(
    [switch]$first
)

$provisioning = [System.IO.DirectoryInfo]"$($env:ProgramData)\provisioning"

# wait for network
$ProgressPreference_bk = $ProgressPreference
$ProgressPreference = 'SilentlyContinue'
do {
    $ping = Test-NetConnection '8.8.8.8' -InformationLevel Quiet
    if (!$ping) {
        Clear-Host
        'Waiting for network connection' | Out-Host
        Start-Sleep -Seconds 5
    }
} while (!$ping)
$ProgressPreference = $ProgressPreference_bk

# From oobe-setup.ps1 (only once)
if ($first) {
    # setup windows update powershell module
    $nuget = Get-PackageProvider 'NuGet' -ListAvailable -ErrorAction SilentlyContinue

    if ($null -eq $nuget) {
        Install-PackageProvider -Name NuGet -Confirm:$false -Force
    }

    $module = Get-Module 'PSWindowsUpdate' -ListAvailable

    if ($null -eq $module) {
        Install-Module PSWindowsUpdate -Confirm:$false -Force
    }
}

# install windows updates
$updates = Get-WindowsUpdate

if ($null -ne $updates) {
    Install-WindowsUpdate -AcceptAll -Install -IgnoreReboot | Select-Object KB, Result, Title, Size
}

$status = Get-WURebootStatus -Silent

# If reboot is required for Windows Update, setup RunOnce to execute this script again without -First parameter
if ($status) {
    $setup_runonce = @{
        Path  = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
        Name  = "execute_update_provisioning"
        Value = "cmd /c powershell.exe -ExecutionPolicy Bypass -File {0}\desktop-update-provisioning.ps1" -f $provisioning.FullName
    }
    New-ItemProperty @setup_runonce | Out-Null
    Restart-Computer
}

# Else proceed with desktop provisioning
else {

    # Configure ActiveSetup to import user registry with RunOnce
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\ImportUserRegistry" -Force | New-ItemProperty -Name "StubPath" -Value 'REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v ImportUserRegistry /d "REG IMPORT C:\ProgramData\provisioning\desktop-user-registry.reg" /f'
    # Execute desktop-software-provisioning.ps1
    . "$($provisioning.FullName)\desktop-software-provisioning.ps1" -ProvisioningFolder $provisioning.FullName
}
