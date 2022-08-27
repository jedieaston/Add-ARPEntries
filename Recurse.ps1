Param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The directory to recurse through.")] 
    [String] $DirectoryPath
)

Set-Location $DirectoryPath
$PackageName = Get-ChildItem -Path $path -Force -Recurse -File | Select-Object -First 1 | Select-Object -ExpandProperty Name
$PackageName = $PackageName -replace ".installer.yaml","" -replace '\.', ' '
$CommitTitle = “Add ARP Entries for $PackageName"
Get-ChildItem -Recurse -File -Filter *.installer.yaml | ForEach-Object {
    .$PSScriptRoot/Add-ARPEntries.ps1 $_.PSParentPath -NoDenormalizeInstallerTypes
    $BranchName = New-Guid
    git switch upstream/master --detach --quiet
    git add .
    git commit --message=$CommitTitle
    git switch --create $BranchName
    git push --set-upstream origin $BranchName
    gh pr create --title $CommitTitle --body "### Pull request has been automatically created using [Add-ARPEntries](https://github.com/jedieaston/Add-ARPEntries)"
}
Set-Location $PSScriptRoot
