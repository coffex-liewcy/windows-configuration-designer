[CmdletBinding()]
param(
  [Parameter(Mandatory = $True)]
  [System.IO.DirectoryInfo]$ProvisioningFolder
)

$associations_xml = @"
<?xml version="1.0" encoding="UTF-8"?>
<DefaultAssociations>
  <Association Identifier=".htm" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier=".html" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier=".pdf" ProgId="Acrobat.Document.DC" ApplicationName="Adobe Acrobat"/>
  <Association Identifier="http" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier="https" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
</DefaultAssociations>
"@

$associations_xml | Out-File "$($ProvisioningFolder.FullName)\associations.xml" -Encoding utf8

dism /online /Import-DefaultAppAssociations:"$($ProvisioningFolder.FullName)\associations.xml"

