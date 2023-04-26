#Requires -Version 5

Param(
    [Parameter(Mandatory = $true, HelpMessage = "The directory to recurse through.")] 
    [String] $DirectoryPath
)

# Check if Docker is running
docker ps | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker isn't running. Start it up (and make sure it's in Windows mode) before continuing!" -ForegroundColor Red
    exit
}

# Check if git is installed
try {
    git | Out-Null
} catch [System.Management.Automation.CommandNotFoundException] {
    Write-Host "Git is not installed." -ForegroundColor Red
    exit
}

# Check if GitHub CLI is installed
try {
    gh | Out-Null
} catch [System.Management.Automation.CommandNotFoundException] {
    Write-Host "GitHub CLI is not installed." -ForegroundColor Red
    exit
}

# If the user has git installed, make sure it is a patched version
if (Get-Command 'git' -ErrorAction SilentlyContinue) {
  $GitMinimumVersion = [System.Version]::Parse('2.39.1')
  $gitVersionString = ((git version) | Select-String '([0-9]{1,}\.?){3,}').Matches.Value.Trim(' ', '.')
  $gitVersion = [System.Version]::Parse($gitVersionString)
  if ($gitVersion -lt $GitMinimumVersion) {
    # Prompt user to install git
    if (Get-Command 'winget' -ErrorAction SilentlyContinue) {
      $_menu = @{
        entries       = @('[Y] Upgrade Git'; '[N] Do not upgrade')
        Prompt        = 'The version of git installed on your machine does not satisfy the requirement of version >= 2.35.2; Would you like to upgrade?'
        HelpText      = "Upgrading will attempt to upgrade git using winget`n"
        DefaultString = ''
      }
      switch (Invoke-KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString'] -HelpText $_menu['HelpText']) {
        'Y' {
          Write-Host
          try {
            winget upgrade --id Git.Git --exact
          } catch {
            throw [UnmetDependencyException]::new('Git could not be upgraded sucessfully', $_)
          } finally {
            $gitVersionString = ((git version) | Select-String '([0-9]{1,}\.?){3,}').Matches.Value.Trim(' ', '.')
            $gitVersion = [System.Version]::Parse($gitVersionString)
            if ($gitVersion -lt $GitMinimumVersion) {
              throw [UnmetDependencyException]::new('Git could not be upgraded sucessfully')
            }
          }
        }
        default { Write-Host; throw [UnmetDependencyException]::new('The version of git installed on your machine does not satisfy the requirement of version >= 2.35.2') }
      }
    } else {
      throw [UnmetDependencyException]::new('The version of git installed on your machine does not satisfy the requirement of version >= 2.35.2')
    }
  }
  # Check whether the script is present inside a fork/clone of jedieaston/Add-ARPEntries repository
  try {
    $script:gitTopLevel = (Resolve-Path $(git rev-parse --show-toplevel)).Path
  } catch {
    # If there was an exception, the user isn't in a git repo. Throw a custom exception and pass the original exception as an InternalException
    throw [UnmetDependencyException]::new('This script must be run from inside a clone of the Add-ARPEntries repository', $_.Exception)
  }
}

Set-Location $DirectoryPath
Get-ChildItem -Recurse -File -Filter *.installer.yaml | ForEach-Object {
    $PackageIdentifier = Get-ChildItem -Path $_.PSParentPath -File | Select-Object -First 1 | Select-Object -ExpandProperty Name
    $PackageIdentifier = $PackageIdentifier -replace ".installer.yaml",""
    $PackageVersion = Split-Path $_.PSParentPath -Leaf
    $CommitTitle = "ARP Entries: $PackageIdentifier version $PackageVersion"
    $FileHash = Get-ChildItem -Path $_.PSParentPath -Force -Recurse -File | Select-Object -First 1 | Get-FileHash
    $BranchName = "$PackageIdentifier-$PackageVersion-$($FileHash.Hash[0..14] -Join '')"
    .$PSScriptRoot/Add-ARPEntries.ps1 $_.PSParentPath -NoDenormalizeInstallerTypes
    git switch upstream/master --detach --quiet
    git add .
    git commit --message=$CommitTitle
    git switch --create $BranchName
    git push --set-upstream origin $BranchName
    gh pr create --title $CommitTitle --body "### Pull request has been automatically created using [Add-ARPEntries](https://github.com/jedieaston/Add-ARPEntries)"
}
Set-Location $PSScriptRoot
