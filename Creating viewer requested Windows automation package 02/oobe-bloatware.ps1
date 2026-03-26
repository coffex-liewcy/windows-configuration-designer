# Remove Windows store apps

$app_packages = 
"Microsoft.WindowsCamera",
"Microsoft.Edge.GameAssist",
"Microsoft.Windows.DevHome",
"MicrosoftCorporationII.MicrosoftFamily",
"MSTeams",
"Microsoft.XboxGamingOverlay",
"Microsoft.XboxIdentityProvider",
"Microsoft.XboxSpeechToTextOverlay",
"Microsoft.GetHelp",
"Clipchamp.Clipchamp",
"Microsoft.WindowsAlarms",
"Microsoft.549981C3F5F10", # Cortana
"Microsoft.WindowsFeedbackHub",
"microsoft.windowscommunicationsapps",
"Microsoft.WindowsMaps",
"Microsoft.ZuneMusic",
"Microsoft.BingNews",
"Microsoft.Todos",
"Microsoft.ZuneVideo",
"Microsoft.MicrosoftOfficeHub",
"Microsoft.OutlookForWindows",
"Microsoft.People",
"Microsoft.PowerAutomateDesktop",
"MicrosoftCorporationII.QuickAssist",
"Microsoft.MicrosoftSolitaireCollection",
"Microsoft.WindowsSoundRecorder",
"Microsoft.MicrosoftStickyNotes",
"Microsoft.BingWeather",
"Microsoft.Xbox.TCUI",
"Microsoft.GamingApp",
"Microsoft.Windows.Ai.Copilot.Provider"

Get-AppxProvisionedPackage -Online | 
    Where-Object { $_.DisplayName -in $app_packages } | 
    Remove-AppxProvisionedPackage -Online -AllUser

# Deploy start layout

# Required start2.bin to be added to CommandFiles in WCD
[System.IO.FileInfo]$start_layout = ".\start2.bin"

Get-ChildItem "C:\Users\" -Attributes Directory -Force | Where-Object { $_.FullName -notin $env:USERPROFILE, $env:PUBLIC -and $_.Name -notin "All Users", "Default User" } | ForEach-Object {

    [System.IO.DirectoryInfo]$destination = "$($_.FullName)\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"

    if (!$destination.Exists) {
        $destination.Create()
    }

    $start_layout.CopyTo("$($destination)\start2.bin", $true)
}

# Prevent OneDrive from installing

New-Item "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\DisableOneDrive" | New-ItemProperty -Name "StubPath" -Value 'REG DELETE "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v OneDriveSetup /f'

# Prevent Outlook (new) and Dev Home from installing

"HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate",
"HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\OutlookUpdate",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\DevHomeUpdate" | ForEach-Object {
    Remove-Item $_ -Force
}