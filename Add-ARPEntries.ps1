
# Add-ARPEntries.ps1. Add AppsAndFeaturesEntries to installer entries in winget manifests via Windows Sandbox.
# Notes:
# - Please look at the outputted file and make sure it looks sane before committing. There's probably some edge cases this (hastily written) script misses. Nothing is impossible to fix if you let me know!
# - Thanks (as always) to @felipecrs and @Trenly for their work on the SandboxTest.ps1 script. This script uses inspiration from that script for some of the stuff used to bootstrap the container.

#Requires -Modules powershell-yaml
Param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The Manifest to add ARP entries to.")] 
    [String] $ManifestPath
)
$ErrorActionPreference = "Stop"
function Get-WinGetManifestType {
    # Helper function. Given a folder, we see if it contains a multi-file or singleton manifest.
    param (
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Manifest to check on.")]
        [string]$manifestFolder
    )
    $ErrorActionPreference = "Stop"
    if (Test-Path -Path $manifestFolder -PathType Leaf) {
        throw "This isn't a folder, this is a file!"
    }
    foreach ($i in (Get-ChildItem -Path $manifestFolder -File)) {
        
        $manifest = Get-Content ($i.FullName) | ConvertFrom-Yaml -Ordered
        if (($manifest.ManifestType.ToLower() -eq "version") -or $manifest.ManifestType.ToLower() -eq "singleton") {
            break
        }
    }
    if ($manifest.ManifestType.ToLower() -eq "version") {
        return "multifile"
    }
    elseif ($manifest.ManifestType.ToLower() -eq "singleton") {
        return "singleton"
    }
    else {
        throw "Unknown manifest type: " + $manifest.ManifestType
    }
}
  
function Get-InstallerEntries {
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The path to the manifest")]
        [string] $Manifest
    )
    
    $manifestType = Get-WinGetManifestType $Manifest

    if ($manifestType -eq "singleton") {
        $manifest2 = Get-Content (Get-ChildItem -Path $Manifest -File)[0].FullName | ConvertFrom-Yaml -Ordered
        return $manifest2.Installers
    }
    else {
        $manifest2 = Get-Content (Get-ChildItem -Path $Manifest -File -Filter *.installer.yaml)[0].FullName | ConvertFrom-Yaml -Ordered
        return $manifest2.Installers 
    }

}

function New-WinGetManifestForInstaller {
    Param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The path to the manifest")]
        [string] $ManifestPath,
        [Parameter(Mandatory = $true, Position = 2, HelpMessage = "The installer entry we want a command for.")]
        [int] $InstallerEntry
    )

    <#
    .SYNOPSIS
    New-WinGetManifestForInstaller generates a winget manifest that has a single installer entry, forcing winget to use it if it is compatible with the system.
    .PARAMETER ManifestPath
    The path to the manifest.
    .PARAMETER InstallerEntry
    An integer, corresponding to the spot in the array that installer entry is at.

    .OUTPUTS
    Nothing. A manifest folder is created with the temporary manifest to be used in the container.
    
    .DESCRIPTION

    #>

    Remove-Item .\tempManifest\ -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item -Recurse $ManifestPath .\tempManifest\
    $ManifestPath = ".\tempManifest\"
    $manifestType = Get-WinGetManifestType $ManifestPath

    if ($manifestType -eq "singleton") {
        $fileName = (Get-ChildItem -Path $ManifestPath -File)[0].FullName
        $installerManifest = Get-Content (Get-ChildItem -Path $ManifestPath -File)[0].FullName | ConvertFrom-Yaml -Ordered
    }
    else {
        $fileName = (Get-ChildItem -Path $ManifestPath -File -Filter *.installer.yaml)[0].FullName
        $installerManifest = Get-Content (Get-ChildItem -Path $ManifestPath -File -Filter *.installer.yaml)[0].FullName | ConvertFrom-Yaml -Ordered
    }
    $installerManifest.Installers = @($installerManifest.Installers[$InstallerEntry])
    $manifestString = '# yaml-language-server: $schema=https://aka.ms/winget-manifest.' + $installerManifest.ManifestType + '.' + $installerManifest.ManifestVersion.ToLower() + '.schema.json' + "`r`n"
    Write-Host $manifestString
    $manifestString += $installerManifest | ConvertTo-Yaml
    [System.IO.File]::WriteAllLines($fileName, $manifestString)
    
}


function Run-InstallerEntryInContainer 
{
    Param(
        [Parameter(Position = 0, HelpMessage = "The path to the manifest.", Mandatory = $true)]
        [String] $Manifest,
        [Parameter(Position = 1, HelpMessage = "The array of installer entries", Mandatory = $true)]
        [array] $InstallerEntries,
        [Parameter(Position = 2, HelpMessage = "The installer entry to run.", Mandatory = $false)]
        [int] $InstallerEntry
    )
    # Create a temporary manifest that has only the installer entry we are working with, so winget has no choice but to use it.
    New-WinGetManifestForInstaller $Manifest $InstallerEntry

    $Manifest = (Convert-Path ".\tempManifest\").ToString()
    # Run the container.
    Invoke-Command -Command { docker run --rm -v ${Manifest}:C:\wingetdev\manifest\ -v C:\Users\easton\projects\generatearp\out\:C:\wingetdev\out\ wingettest  | Out-Default }
    return $true
}

function Convert-WinGetManifestToLatestSchema {
    param (
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Manifest to check on.")]
        [string]$manifestFolder
    )
    $converted = $false
    foreach ($i in (Get-ChildItem $manifestFolder -File)) {
        # Write-Host "Hmmm...."
        $path = $i.FullName
        $manifestFile = Get-Content $path -Encoding UTF8 | ConvertFrom-Yaml -Ordered
        if ($manifestFile.ManifestVersion -eq "1.1.0") {
            continue
        }
        $converted = $true
        $manifestFile.ManifestVersion = "1.1.0"
        $manifestString = '# yaml-language-server: $schema=https://aka.ms/winget-manifest.' + $manifestFile.ManifestType + '.' + $manifestFile.ManifestVersion.ToLower() + '.schema.json' + "`r`n"
        $manifestString += $manifestFile | ConvertTo-Yaml
        [System.IO.File]::WriteAllLines($path, $manifestString)
    }
    if ($converted) {
        winget validate $manifestFolder
        if ($LASTEXITCODE -ne 0) {
            throw "Conversion failed. Check the written manifest for errors."
        }
        Write-Host -ForegroundColor Green "Converted manifest to 1.1.0!"
    }
}

function Set-ArpDataForInstallerEntries {
    param (
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Manifest to check on.")]
        [string]$manifestFolder
    )
    $manifestType = Get-WinGetManifestType $manifestFolder
    Convert-WinGetManifestToLatestSchema $manifestFolder 
    $installersManifest = $null
    # Get the manifest where the installer entries are.
    if ($manifestType -eq "singleton") {
        $filePath = (Get-ChildItem -Path $manifestFolder -File)[0].FullName
        $installersManifest = Get-Content -Encoding UTF8 $filePath | ConvertFrom-Yaml -Ordered 
    }
    else {
        $filePath = (Get-ChildItem -Path $manifestFolder -File -Filter *.installer.yaml)[0].FullName
        $installersManifest = Get-Content -Encoding UTF8 $filePath | ConvertFrom-Yaml -Ordered
    }
    $errors = 0
    for ($i = 0; $i -lt $installersManifest.Installers.Count ; $i++) {
        if ($installersManifest.Contains("InstallerType"))
        {
            $installersManifest.Installers[$i].InstallerType = $installersManifest.InstallerType
        }
        if (($installersManifest.Installers[$i].InstallerType.ToLower() -eq "msix") -or ($installersManifest.Installers[$i].InstallerType.ToLower() -eq "appx")) {
            Write-Host -ForegroundColor Yellow "This script can't find entries for appx/msix right now. It's not that hard to add, I just haven't done it yet. Skipping..."
            $errors += 1
            continue;
        }
        Remove-Item .\out\uhoh -ErrorAction SilentlyContinue

        Run-InstallerEntryInContainer $manifestFolder $installersManifest.Installers $i

        if (Test-Path .\out\uhoh) {
            Write-Host -ForegroundColor Red "Installer entry" $i "failed to install. There may be an architecture mismatch or something, try running it by itself."
            Get-Content .\out\output.json | Out-Host
            $errors += 1
            continue
        }
        else {
            Write-Host "ARP entries for installer " $i "are..."
            Get-Content .\out\output.json | Out-Host
            $arpEntries = (Get-Content .\out\output.json | ConvertFrom-Json)
            if ($arpEntries.Count -gt 0) {
                $installersManifest.Installers[$i].AppsAndFeaturesEntries = $arpEntries
            }
            rm .\out\output.json
            $sandbox = Get-Process 'WindowsSandboxClient' -ErrorAction SilentlyContinue
            if ($sandbox) {
                Write-Host '--> Closing Windows Sandbox'

                $sandbox | Stop-Process
            }
        }
    }

    
    $installersManifest.ManifestVersion = "1.1.0"
    $manifestString = '# yaml-language-server: $schema=https://aka.ms/winget-manifest.' + $installersManifest.ManifestType + '.' + $installersManifest.ManifestVersion.ToLower() + '.schema.json' + "`r`n"
    $manifestString += $installersManifest | ConvertTo-Yaml
    [System.IO.File]::WriteAllLines($filePath, $manifestString)
    Write-Host -ForegroundColor Green "ARP Entries were found for " ($installersManifest.Installers.Count - $errors) "entries!!1!"
    Write-Host "Installer entries written! Please look at them before committing." -ForegroundColor Green
    Remove-Item .\done -ErrorAction SilentlyContinue
    Remove-Item .\out\ -ErrorAction SilentlyContinue
    Remove-Item .\tempManifest\ -ErrorAction SilentlyContinue
}

Set-ArpDataForInstallerEntries $ManifestPath
