
# Problems faced:
1. Have to make sure remote user can start using Windows after initial password change
2. The setup has to get it right the first time, no room for error
3. Prerequisites information about Penang branch:
	1. What is the Wi-Fi settings?
	2. What is the printer model and its driver?
	3. What should be the username (cannot be changed once set to avoid home directory conflict)?
		1. Set up the username right before shipping it
		2. Ask to change initial password
	4. Monitor G5 setup?
	5. OpenVPN
	6. 

# Methodology:
- Using built-in command (keep it simple)
- Other methods:
	- .ps1 script
	- winget
	- chocolatey

# CHECKLIST:
- [x] Create itsupport Admin account
- [x] Disable OOBE
- [x] Skip privacy screen
- [ ] Install bunch of software using chocolatey
	- [x] Chrome
	- [ ] Drive
	- [x] Adobe
	- [x] 7zip
	- [ ] Slack
	- [ ] Klite
	- [ ] Avira
	- [ ] Printer drivers
- [ ] Configure Wi-Fi
- [x] Personalize taskbar
	- [x] Move taskbar to left
	- [x] Pin Explorer, Control Panel and Chrome
	- [x] Remove copilot, task, widgets
- [x] Personalize start layout
	- [x] START2.bin works but it should target Default folder
- [x] Change power options
- [x] Default app association
- [ ] Fix shell integration for 7zip
- [ ] Disable Bitlocker encryption: Disable-BitLocker -MountPoint C:
- [x] Set up computer name
- [x] Uninstall bloatware (appx-package)
- [x] Configure Chrome extension
- [ ] Remove Edge shortcut from Public Desktop (gci public desktop | where filter | ri)
- [x] Add This PC desktop icon (in NewStartPanel)
- [ ] (For some users) Pin Classic Outlook
	- [ ] Using <taskbar:DesktopApp DesktopApplicationID="Microsoft.Office.OUTLOOK.EXE.15" />
- [ ] Change computer name with serial tag
- [ ] Join workgroup MYPJCOFFEX
- [ ] Replace netplwiz with powershell read-host to create local user (dont use desktop-application.ps1)
- [ ] Turn off Windows Copilot under:
	- [ ] Previously done with gpedit
	- [ ] key: HKEY_CURRENT_USER\Software\Policies\Microsoft\Windows\WindowsCopilot
	      name: TurnOffWindowsCopilot
	      value: DWORD 1
- [x] (Optional) GUI for add standard user
- [ ] (Advanced) Deploy G5 silently
- [ ] Registry
	- [x] Add HideFileExt = 0
	- [ ] Add FullPath = 1 in HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState
	- [ ] (Optional) Add DontPrettyPath = 1
	- [ ] Disable Windows Spotlight
	      key: HKEY_CURRENT_USER\Software\Policies\Microsoft\Windows\CloudContent
	      DisableSpotlightCollectionOnDesktop = DWORD 1
	- [ ] Disable Windows Spotlight + Unpin Outlook new
		- [ ] reg add HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent] /v DisableCloudOptimizedContent /t REG_DWORD /d 1 /f
	- [ ] Unpin Outlook (new) only
		- [ ] reg import "the good taskband"
		- [ ] Might break taskbar shortcut
	- [ ] Show all taskbar icons (No overflow)
		- [x] [IT WORKS! Always show all taskbar icons using Registry in Windows 11 : Windows11](https://old.reddit.com/r/Windows11/comments/1b5l13u/it_works_always_show_all_taskbar_icons_using/)IT DOESNT WORK
		- [ ] Run these instead
			$RegistryPath = 'HKCU:\Control Panel\NotifyIconSettings'  
			$Name = 'IsPromoted'  
			$Value = '1'  
			Get-ChildItem -path $RegistryPath -Recurse | ForEach-Object {New-ItemProperty -Path $_.PSPath -Name $Name -Value $Value -PropertyType DWORD -Force }


# TEST PROCEDURE:
1. Provision ppkg in OOBE screen
2. Restart under itsupport account
3. Create a temp user

# TIPS ON C:Users folders
- "All Users" and "Default User" are system protected folders
	- Default user is a residual folder used by OOBE
	- All users is a legacy junction point that points to C:\ProgramData
- "Default" is the template