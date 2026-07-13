# Builds the release zip: the addon folder only, no docs/tests/tooling
# (separation of steering vs artifact). Usage: scripts\package.ps1 [-Version 0.1.0]
param([string]$Version)

$root = Split-Path $PSScriptRoot -Parent
$toc = Get-Content "$root\HCBBDungeonFinder\HCBBDungeonFinder.toc"
if (-not $Version) {
    $Version = ($toc | Select-String '## Version: (.+)').Matches[0].Groups[1].Value.Trim()
}

$dist = "$root\dist"
New-Item -ItemType Directory -Force $dist | Out-Null
$zip = "$dist\HCBBDungeonFinder-v$Version.zip"
if (Test-Path $zip) { Remove-Item $zip }

# Ship both folders: the always-loaded loader + the LoadOnDemand main addon.
Compress-Archive -Path "$root\HCBBDungeonFinder", "$root\HCBBDungeonFinder_Loader" `
    -DestinationPath $zip
Write-Host "Built $zip"
