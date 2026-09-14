# Custom Coffex package

A Windows Configuration Designer (WCD) provisioning package that takes a brand-new
Windows 11 PC from the OOBE screen to a ready-to-ship Coffex machine with no
interaction, apart from one short menu at the end.

The package runs in **two stages**: everything that can be done before a user exists
runs in OOBE as `SYSTEM`; everything that is per-user or needs a network is deferred
to the first logon via `RunOnce` and `Active Setup`.

**An internet connection is required before applying the package** (Chocolatey needs it).

---

## Build inputs

These files are **not in the repo** and must be added to *CommandFiles* in WCD
alongside the scripts:

| File | Where to get it |
|---|---|
| `chocolatey-2.7.0.0.msi` | <https://github.com/chocolatey/choco/releases> (the version is hardcoded in `oobe-chocolatey.ps1`) |
| `start2.bin` | Build a Start menu by hand, then copy from `%LOCALAPPDATA%\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\` |

In WCD, set the package to run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File oobe-setup.ps1
```

---

## Stage 1 - OOBE (runs as SYSTEM)

`oobe-setup.ps1` is the entry point. It creates `C:\ProgramData\provisioning`, then
dot-sources each helper script in this order:

| Script | What it does |
|---|---|
| `oobe-powersettings.ps1` | `powercfg` timeouts: monitor 10 min AC / 5 min DC, sleep 300 min AC / 120 min DC. Hibernate and lid-action lines are commented out. |
| `oobe-chocolatey.ps1` | Installs Chocolatey from the local MSI (offline), then installs `googlechrome`, `adobereader`, `googledrive`, `slack`, `k-litecodecpack-standard`, `7zip`. (`vlc` is commented out.) |
| `oobe-associations.ps1` | Writes `associations.xml` and imports it with `dism /Online /Import-DefaultAppAssociations`. Chrome gets `.htm`, `.html`, `http`, `https`; Adobe Acrobat gets `.pdf`. |
| `oobe-bloatware.ps1` | Removes ~34 provisioned Appx packages, stamps `start2.bin` into every profile under `C:\Users\` (including `Default`), and blocks OneDrive, Outlook (new) and Dev Home from auto-installing. |
| `oobe-chrome-extensions.ps1` | `ExtensionInstallForcelist` policy - force-installs uBlock Origin Lite. |

`oobe-setup.ps1` then does the rest itself:

* Copies every file in the package folder into `C:\ProgramData\provisioning`,
  **except** anything matching `oobe-*`, `chocolatey*`, or `start2.bin`.
* Creates the local account **`itsupport`** with **no password**, sets
  `PasswordNeverExpires`, and adds it to `Administrators`.
* Joins the workgroup **`MYPJCOFFEX`**.
* Deletes any `*Edge*.lnk` from the Public Desktop.
* Runs `Disable-BitLocker` on every volume that is not already `FullyDecrypted`.
* Writes the machine-wide registry settings listed below.

### Registry written in Stage 1 (all under `HKLM`)

| Key | Value | Purpose |
|---|---|---|
| `SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce` | `execute_provisioning` | Launches `desktop-update-provisioning.ps1 -First` at first logon |
| `SOFTWARE\Policies\Microsoft\Windows\OOBE` | `DisablePrivacyExperience = 1` | Skips the privacy screen |
| `SOFTWARE\Policies\Microsoft\Dsh` | `AllowNewsAndInterests = 0` | Kills the widgets / news feed |
| `SOFTWARE\Policies\Microsoft\EdgeUpdate` | `CreateDesktopShortcutDefault = 0` | Stops Edge re-creating its desktop shortcut on update |
| `SOFTWARE\Policies\Microsoft\Windows\Explorer` | `StartLayoutFile` (ExpandString) + `LockedStartLayout = 1` | Applies `desktop-taskbar.xml` - pins File Explorer, Control Panel, Chrome |
| `SOFTWARE\Microsoft\Active Setup\Installed Components\DesktopIcons` | `StubPath` | `reg import desktop-icons.reg` at each user's first logon - shows the *This PC* desktop icon |

> **Note on the registry idiom:** all the registry scripts build an array of
> `[PSCustomObject]@{ Path; Name; Value; Type }` and pipe it to `Group-Object Path`
> so each key is opened only once. After grouping, `$setting.Name` is the **key path**
> and `$_.Name` inside the inner loop is the **value name**. Easy to misread.

---

## Stage 2 - first logon as `itsupport`

`RunOnce` fires `desktop-update-provisioning.ps1 -First`, which:

1. Blocks until `8.8.8.8` responds to a ping.
2. On the `-First` run only, installs the NuGet package provider and the
   `PSWindowsUpdate` module.
3. **The Windows Update loop is currently commented out** - see *Disabled code* below.
4. Registers an `Active Setup` component (`ImportUserRegistry`) that queues a per-user
   `RunOnce` to `reg import desktop-user-registry.reg`. That file sets, per user:
   `TaskbarAl = 0` (taskbar left), `TaskbarMn = 0` (no chat), `TaskbarDa = 0` (no
   widgets), `ShowCopilotButton = 0`, `ShowTaskViewButton = 0`, `HideFileExt = 0`.
5. Dot-sources `desktop-software-provisioning.ps1`, which presents an interactive menu:

```
   1 - Set password for itsupport
   2 - Create local user
   3 - Change computer name
   4 - Restart computer
   0 - Close script
```

> **Do not skip option 1.** `itsupport` ships as a passwordless local administrator
> until someone sets a password here.

---

## Disabled code

Several things are intentionally commented out. They are left in place rather than
deleted so they can be switched back on.

| Where | What is off | How to re-enable |
|---|---|---|
| `desktop-update-provisioning.ps1` | The `Get-WindowsUpdate` / `Install-WindowsUpdate` / reboot loop, and the `else {` that wraps everything after it | Uncomment the block marked `UNCOMMENT TO RESTORE` plus the two `#else` / `#}` lines |
| `desktop-software-provisioning.ps1` | Microsoft 365 install via the Office Deployment Tool, and the calls to `desktop-configure-taskbar.ps1` and `desktop-shortcuts.ps1` | Uncomment the M365 block; re-enable the USB copy in `oobe-setup.ps1` as well |
| `oobe-setup.ps1` | Copying `m365` from a labelled USB drive; the `RemoveDesktopShortcutDefault` Edge policy | Uncomment and set `$usb_drive_name` |

Because the Windows Update loop is off, the `-First` run still downloads NuGet and
`PSWindowsUpdate` for nothing. Worth trimming if updates stay disabled.

### Files that are no longer called

* **`desktop-configure-taskbar.ps1`** - superseded. Its `StartLayoutFile` /
  `LockedStartLayout` logic was moved inline into `oobe-setup.ps1`.
* **`desktop-shortcuts.ps1`** - not called, and it points at TeamViewer QS, Word,
  Excel and Acrobat paths for software this package no longer installs.
* **`Configuration.xml`** - Office Deployment Tool config for Home & Student 2021,
  used only by the disabled M365 block.

---

## Test procedure

1. Apply the `.ppkg` at the OOBE screen.
2. Let the machine restart and log in as `itsupport`.
3. Work through the Stage 2 menu - set the `itsupport` password, create the end
   user's account, set the computer name.
4. Create a throwaway standard user and log in as them to confirm the per-user
   Active Setup work actually landed: taskbar left, no Copilot / widgets / Task View,
   file extensions visible, *This PC* on the desktop, correct Start layout.

---

## Status

**Done**

- [x] `itsupport` admin account
- [x] Skip OOBE and the privacy screen
- [x] Join workgroup `MYPJCOFFEX`
- [x] Set computer name (via the Stage 2 menu)
- [x] Replace `netplwiz` with a `Read-Host` menu for creating local users
- [x] Chocolatey: Chrome, Adobe Reader, Google Drive, Slack, K-Lite, 7-Zip
- [x] Default app associations (Chrome, Acrobat)
- [x] Chrome extension policy (uBlock Origin Lite)
- [x] Uninstall bloatware (Appx provisioned packages)
- [x] Start layout via `start2.bin`, targeting `C:\Users\Default`
- [x] Taskbar: aligned left; Explorer, Control Panel and Chrome pinned; Copilot,
      Task View and widgets removed
- [x] Power options
- [x] Remove the Edge shortcut from the Public Desktop
- [x] Show the *This PC* desktop icon
- [x] `HideFileExt = 0`
- [x] Disable BitLocker

**Outstanding**

- [ ] Configure Wi-Fi
- [ ] Printer drivers (model and driver for the Penang branch still unknown)
- [ ] Avira
- [ ] Fix shell integration for 7-Zip
- [ ] Derive the computer name from the serial tag instead of typing it
- [ ] Pin classic Outlook for the users who need it:
      `<taskbar:DesktopApp DesktopApplicationID="Microsoft.Office.OUTLOOK.EXE.15" />`
- [ ] Turn off Windows Copilot by policy:
      `HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot` -> `TurnOffWindowsCopilot = 1`
      (previously done by hand in `gpedit`)
- [ ] Explorer: `FullPath = 1` under
      `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState`
      (and optionally `DontPrettyPath = 1`)
- [ ] Disable Windows Spotlight:
      `HKCU\Software\Policies\Microsoft\Windows\CloudContent` -> `DisableSpotlightCollectionOnDesktop = 1`,
      and `HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent` -> `DisableCloudOptimizedContent = 1`
      (the HKLM one also unpins Outlook (new))
- [ ] Unpin Outlook (new) on its own - importing a known-good `taskband` blob works
      but risks breaking the other taskbar pins
- [ ] Show all taskbar icons with no overflow. The widely-shared registry trick does
      **not** work; this does:

      Get-ChildItem -Path 'HKCU:\Control Panel\NotifyIconSettings' -Recurse | ForEach-Object {
          New-ItemProperty -Path $_.PSPath -Name 'IsPromoted' -Value 1 -PropertyType DWORD -Force
      }

- [ ] (Advanced) Deploy the G5 monitor software silently
- [ ] OpenVPN

---

## Open questions for the Penang branch

The remote user has to be able to start working straight after their first password
change, and there is no second attempt - so these need answers before shipping:

1. What are the Wi-Fi settings?
2. What is the printer model and its driver?
3. What username should the end user get? This cannot be changed later without a
   home-directory conflict, so set it immediately before shipping and require a
   password change at first logon.
4. Is the G5 monitor setup needed?
5. Is OpenVPN needed?

---

## Notes

**`C:\Users` layout.** `oobe-bloatware.ps1` walks `C:\Users` to copy `start2.bin` into
every profile, and skips `All Users` and `Default User` deliberately:

* `Default` is the real template profile - this is the one that matters for new users.
* `Default User` is a legacy junction left over from OOBE.
* `All Users` is a legacy junction pointing at `C:\ProgramData`.

**`.reg` file encoding.** `desktop-icons.reg` and `desktop-user-registry.reg` are
UTF-16LE. `reg import` requires this - do not "fix" them to UTF-8.

**Upstream.** This package started from the Windows Configuration Designer example
series; the sibling folders in this repo are the original demos, kept for reference
only.
