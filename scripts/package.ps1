# Builds the release zip: both addon folders only, no docs/tests/tooling
# (separation of steering vs artifact). Usage: scripts\package.ps1 [-Version 0.1.0]
param([string]$Version)

$root = Split-Path $PSScriptRoot -Parent
$toc = Get-Content "$root\HCBBDungeonFinder\HCBBDungeonFinder.toc"
if (-not $Version) {
    $Version = ($toc | Select-String '## Version: (.+)').Matches[0].Groups[1].Value.Trim()
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Build the zip entry by entry with forward-slash names. Both Compress-Archive
# and ZipFile.CreateFromDirectory on Windows PowerShell 5.1 (.NET Framework)
# write backslash separators, which 7-Zip/WinRAR and non-Windows tools
# mishandle; naming entries ourselves guarantees a standard, portable zip.
$folders = @("HCBBDungeonFinder", "HCBBDungeonFinder_Loader")
function Build-Zip($zipPath) {
    if (Test-Path $zipPath) { Remove-Item $zipPath }
    $fs = [System.IO.File]::Open($zipPath, [System.IO.FileMode]::CreateNew)
    $zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
    foreach ($folder in $folders) {
        Get-ChildItem (Join-Path $root $folder) -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($root.Length + 1) -replace '\\', '/'
            $entry = $zip.CreateEntry($rel, [System.IO.Compression.CompressionLevel]::Optimal)
            $out = $entry.Open()
            $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
            $out.Write($bytes, 0, $bytes.Length)
            $out.Dispose()
        }
    }
    $zip.Dispose()
    $fs.Dispose()
    Write-Host "Built $zipPath"
}

$dist = "$root\dist"
New-Item -ItemType Directory -Force $dist | Out-Null
Build-Zip "$dist\HCBBDungeonFinder-v$Version.zip"

# Refresh the in-repo download bundle that players without Git grab from the
# README (stable link, always the latest). Regenerate this before any push
# that changes the addon code, so the download stays current.
$downloadDir = "$root\download"
New-Item -ItemType Directory -Force $downloadDir | Out-Null
Build-Zip "$downloadDir\HCBBDungeonFinder-latest.zip"
