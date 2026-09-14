<#
.SYNOPSIS
    Builds the Coffex provisioning package (.ppkg) from this folder.

.DESCRIPTION
    Generates customizations.xml from the payload file list below, then builds it
    with the Windows Configuration Designer command-line tool (ICD.exe).

    This replaces assembling the project by hand in the WCD GUI, so the package is
    reproducible from a clean clone.

.PARAMETER OutputFolder
    Where to write the .ppkg. Defaults to a "build" folder beside this script.

.EXAMPLE
    .\build-ppkg.ps1

.NOTES
    ICD.exe reports "successfully built" even when no payload files are embedded.
    This script fails loudly if the resulting package is suspiciously small.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [System.IO.DirectoryInfo]$OutputFolder = (Join-Path -Path $PSScriptRoot -ChildPath 'build')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Files copied onto the target machine. Deliberately excludes README.md and the
# build tooling, so internal documentation is not shipped to client PCs.
$PayloadFiles = @(
    'oobe-setup.ps1'
    'oobe-powersettings.ps1'
    'oobe-chocolatey.ps1'
    'oobe-associations.ps1'
    'oobe-bloatware.ps1'
    'oobe-chrome-extensions.ps1'
    'chocolatey-2.7.0.0.msi'
    'start2.bin'
    'desktop-update-provisioning.ps1'
    'desktop-software-provisioning.ps1'
    'desktop-configure-taskbar.ps1'
    'desktop-shortcuts.ps1'
    'desktop-taskbar.xml'
    'desktop-icons.reg'
    'desktop-user-registry.reg'
    'Configuration.xml'
)

$PackageId      = '{a0e157c2-81e9-403d-a984-b40dd1ca4945}'
$PackageName    = 'Custom Coffex package'
$PackageVersion = '1.0'
$EntryCommand   = 'powershell.exe -ExecutionPolicy Bypass -File oobe-setup.ps1'

# --- Locate the Windows Configuration Designer command-line tool -----------------

$WcdPackage = Get-AppxPackage -Name 'Microsoft.WindowsConfigurationDesigner' -ErrorAction SilentlyContinue

if ($null -eq $WcdPackage) {
    throw 'Windows Configuration Designer is not installed. Install it from the Microsoft Store.'
}

$IcdExecutable = Join-Path -Path $WcdPackage.InstallLocation -ChildPath 'icd\ICD.exe'
$DesktopStore  = Join-Path -Path $WcdPackage.InstallLocation -ChildPath 'icd\Microsoft-Desktop-Provisioning.dat'

foreach ($RequiredTool in @($IcdExecutable, $DesktopStore)) {
    if (-not (Test-Path -Path $RequiredTool)) {
        throw "Required file not found: $RequiredTool"
    }
}

# --- Verify every payload file is present before building -----------------------

$MissingFiles = $PayloadFiles | Where-Object {
    -not (Test-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath $_))
}

if ($MissingFiles) {
    throw ("Missing payload files: {0}" -f ($MissingFiles -join ', '))
}

if (-not $OutputFolder.Exists) {
    $OutputFolder.Create()
    $OutputFolder.Refresh()
}

# --- Generate customizations.xml ------------------------------------------------
# CommandFiles must be a collection of <CommandFile Name="..."> elements holding
# ABSOLUTE source paths. Relative paths are silently ignored and produce an empty
# package that ICD.exe still reports as a success.

$CommandFileElements = $PayloadFiles | ForEach-Object {
    $SourcePath = Join-Path -Path $PSScriptRoot -ChildPath $_
    '              <CommandFile Name="{0}">{1}</CommandFile>' -f $_, $SourcePath
}

$CustomizationsXml = @"
<?xml version="1.0" encoding="utf-8"?>
<WindowsCustomizations>
  <PackageConfig xmlns="urn:schemas-Microsoft-com:Windows-ICD-Package-Config.v1.0">
    <ID>$PackageId</ID>
    <Name>$PackageName</Name>
    <Description>Coffex Windows 11 provisioning package</Description>
    <Version>$PackageVersion</Version>
    <OwnerType>ITAdmin</OwnerType>
    <Rank>0</Rank>
  </PackageConfig>
  <Settings xmlns="urn:schemas-microsoft-com:windows-provisioning">
    <Customizations>
      <Common>
        <OOBE>
          <Desktop>
            <HideOobe>True</HideOobe>
          </Desktop>
        </OOBE>
        <ProvisioningCommands>
          <DeviceContext>
            <CommandFiles>
$($CommandFileElements -join [System.Environment]::NewLine)
            </CommandFiles>
            <CommandLine>$EntryCommand</CommandLine>
          </DeviceContext>
        </ProvisioningCommands>
      </Common>
    </Customizations>
  </Settings>
</WindowsCustomizations>
"@

$CustomizationsPath = Join-Path -Path $PSScriptRoot -ChildPath 'customizations.xml'
Set-Content -Path $CustomizationsPath -Value $CustomizationsXml -Encoding UTF8

# --- Build ----------------------------------------------------------------------
# ICD.exe mangles arguments containing spaces, and the store file lives under
# "C:\Program Files\WindowsApps\...". Copy it to a space-free working path first.

$WorkingFolder = Join-Path -Path $env:TEMP -ChildPath 'coffex-ppkg-build'
New-Item -Path $WorkingFolder -ItemType Directory -Force | Out-Null

$LocalStore = Join-Path -Path $WorkingFolder -ChildPath 'Desktop.dat'
Copy-Item -Path $DesktopStore -Destination $LocalStore -Force

# ICD.exe cannot parse arguments containing spaces, and this folder ("Custom Coffex
# package") has them. Build into the space-free working folder, then move the result.
$StagedPackage = Join-Path -Path $WorkingFolder -ChildPath 'CoffexProvisioning.ppkg'

Push-Location -Path $PSScriptRoot
try {
    & $IcdExecutable /Build-ProvisioningPackage `
        /CustomizationXML:customizations.xml `
        /PackagePath:"$StagedPackage" `
        /StoreFile:"$LocalStore" `
        +Overwrite

    if ($LASTEXITCODE -ne 0) {
        throw "ICD.exe failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

$PackagePath = Join-Path -Path $OutputFolder.FullName -ChildPath 'CoffexProvisioning.ppkg'

Get-ChildItem -Path $WorkingFolder -Filter 'CoffexProvisioning.*' |
    Where-Object { $_.Extension -in '.ppkg', '.cat' } |
    ForEach-Object {
        Move-Item -Path $_.FullName -Destination (Join-Path -Path $OutputFolder.FullName -ChildPath $_.Name) -Force
    }

# --- Verify the payload actually went in ----------------------------------------

$BuiltPackage = Get-Item -Path $PackagePath
$MinimumBytes = 1MB

if ($BuiltPackage.Length -lt $MinimumBytes) {
    throw ("Package is only {0:N0} bytes - the payload files were not embedded. " -f $BuiltPackage.Length +
           'Check that CommandFile paths are absolute.')
}

Write-Host ("Built {0} ({1:N2} MB)" -f $BuiltPackage.FullName, ($BuiltPackage.Length / 1MB)) -ForegroundColor Green
