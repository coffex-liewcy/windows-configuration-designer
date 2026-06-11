param(
    [System.IO.DirectoryInfo]$ProvisioningFolder
)

<# M365 provisioning disabled
$software_packages = 
[PSCustomObject]@{
    Executable  = "{0}\setup.exe" -f "$($env:SystemRoot)\TEMP\m365"
    Arguments   = "/configure {0}\{1}" -f "$($env:SystemRoot)\TEMP\m365", "Configuration.xml"
    NoNewWindow = $true
    PassThru    = $true
    Wait        = $true
}

foreach ($package in $software_packages) {

    Write-Host "Executing: $($package.Executable) ExitCode: " -NoNewline

    if ([System.IO.Path]::GetExtension($package.Executable) -eq '.msi') {
        $execute = @{
            FilePath     = "msiexec"
            ArgumentList = "/i {0} {1}" -f $package.Executable, $package.Arguments
            PassThru     = $true
            Wait         = $true
        }
    }
    elseif ([System.IO.Path]::GetExtension($package.Executable) -eq '.exe') {
        $execute = @{
            FilePath     = $package.Executable
            ArgumentList = $package.Arguments
            PassThru     = $true
            Wait         = $true
        }
    }
    $p = Start-Process @execute

    Write-Host $p.exitcode
}
#>

# Execute desktop-configure-taskbar.ps1, desktop-shortcuts.ps1, netplwiz
#. "$($ProvisioningFolder.FullName)\desktop-configure-taskbar.ps1" -ProvisioningFolder $ProvisioningFolder
# Not needed
#. "$($ProvisioningFolder.FullName)\desktop-shortcuts.ps1"
#netplwiz

# Command line menu
do {
    "Available actions:",
    "   1 - Set password for itsupport",
    "   2 - Create local user",
    "   3 - Change computer name",
    "   4 - Restart computer",
    "   0 - Close script" | Out-Host
    $selected = Read-Host "Enter selection"
    switch ($selected) {
        1 {
            $Password = Read-Host -Prompt "Enter password for itsupport account" -AsSecureString 
            $UserAccount = Get-LocalUser -Name "itsupport"
            $UserAccount | Set-LocalUser -Password $Password -PasswordNeverExpires $true
            break
        }
        2 {
            $NewUser = Get-Credential | Select-Object @{n = 'Name'; e = { $_.UserName } },
            @{n = 'Password'; e = { $_.Password } } | New-LocalUser -PasswordNeverExpires
            $NewUser | Add-LocalGroupMember -Group "Users"
            break
        }
        3 {
            $current_name = $env:COMPUTERNAME
            $new_name = Read-Host "Enter new computer name (current name: $current_name)"
            $new_name | Select-Object @{n = 'NewName'; e = { $_ } } | Rename-Computer
            break
        }
        4 {
            Restart-Computer
            break
        }
        0 {
            Write-Host "Closing script..." -ForegroundColor Green
        }
        default {
            Write-Host "Invalid selection. Please try again." -ForegroundColor Red
        }
    }
}while ($selected -ne 0)

# best place to add more actions

Write-Host "All Done!" -ForegroundColor Green
Read-Host