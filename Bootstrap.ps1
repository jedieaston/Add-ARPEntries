$ErrorActionPreference = "Stop"
function Get-ARPTable {
    $registry_paths = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
    return Get-ItemProperty $registry_paths -ErrorAction SilentlyContinue |
        Select-Object DisplayName, DisplayVersion, Publisher, SystemComponent, @{N='ProductCode'; E={$_.PSChildName}} |
        Where-Object {$null -ne $_.DisplayName -and $_.SystemComponent -ne 1} |
        Select-Object DisplayName, DisplayVersion, Publisher, ProductCode
}
Set-Service edgeupdate -Status stopped -StartupType disabled ; Set-Service edgeupdatem -Status stopped -StartupType disabled
Write-Host "Installing the manifest..."
$originalARP = Get-ARPTable
.\wingetdev.exe install -m .\manifest\
if ($LASTEXITCODE -ne 0)
{
    Write-Host $LASTEXITCODE
    Write-Host "Something went wrong."
    New-Item .\out\uhoh
}
Write-Host @'
--> Writing ARP changes to output.json.
'@
ConvertTo-Json @((Compare-Object (Get-ARPTable) $originalARP -Property DisplayName,DisplayVersion,Publisher,ProductCode)| Select-Object -Property * -ExcludeProperty SideIndicator) | Out-File .\out\output.json
