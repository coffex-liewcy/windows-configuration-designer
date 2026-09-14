$chrome_settings = 
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
    Value = "ddkjiahejlhfcafbddmgiahcphecmpfh" #uBlock Origin Lite
    Name  = ++$chrome_extension_count
}  | Group-Object Path

foreach($setting in $chrome_settings){
    $registry = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($setting.Name, $true)
    if ($null -eq $registry) {
        $registry = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($setting.Name, $true)
    }
    $setting.Group | ForEach-Object {
        $registry.SetValue($_.name, $_.value)
    }
    $registry.Dispose()
}