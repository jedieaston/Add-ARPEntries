$ErrorActionPreference = "Stop"
function Update-EnvironmentVariables {
      foreach($level in "Machine","User") {
        [Environment]::GetEnvironmentVariables($level).GetEnumerator() | % {
            # For Path variables, append the new values, if they're not already in there
            if($_.Name -match 'Path$') {
              $_.Value = ($((Get-Content "Env:$($_.Name)") + ";$($_.Value)") -split ';' | Select -unique) -join ';'
            }
            $_
        } | Set-Content -Path { "Env:$($_.Name)" }
      }
    }

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
Write-Host $args
&.\wingetdev.exe install ${args} -m .\manifest\
if ($LASTEXITCODE -ne 0)
{
    Write-Host $LASTEXITCODE
    Write-Host "Something went wrong."
    New-Item .\out\uhoh
}
Write-Host @'
--> Refreshing environment variables.
'@
Update-EnvironmentVariables
Write-Host @'
--> Writing ARP changes to output.json.
'@
ConvertTo-Json @((Compare-Object (Get-ARPTable) $originalARP -Property DisplayName,DisplayVersion,Publisher,ProductCode)| Select-Object -Property * -ExcludeProperty SideIndicator) | Out-File .\out\output.json