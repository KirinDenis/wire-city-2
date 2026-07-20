# packbbs.ps1 - build docs/bbs_vN.jsdos from EXAMPLES/BBS.COM.
# Entry names use forward slashes via .NET ZipArchive: PS 5.1
# Compress-Archive writes backslash entry names which break js-dos unzip.
param([int]$Version = 1)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Split-Path -Parent $PSScriptRoot
$conf = Join-Path $root "docs\bbs.conf"

$out = Join-Path $root "docs\bbs_v$Version.jsdos"
if (Test-Path $out) { Remove-Item $out }
$zip = [System.IO.Compression.ZipFile]::Open($out, "Create")
[void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $root "EXAMPLES\BBS.COM"), "BBS.COM")
[void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $conf, ".jsdos/dosbox.conf")
[void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $conf, "dosbox.conf")
$zip.Dispose()
Write-Host "packed: $out ($((Get-Item $out).Length) bytes)"
