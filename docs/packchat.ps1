# packchat.ps1 - build docs/chat_vN.jsdos from EXAMPLES/CHAT.COM.
# Entry names use forward slashes via .NET ZipArchive: PS 5.1
# Compress-Archive writes backslash entry names which break js-dos unzip.
param([int]$Version = 2)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Split-Path -Parent $PSScriptRoot
$conf = Join-Path $root "docs\chat.conf"

# The chat bundle conf: IPX on, autoexec straight into CHAT.COM.
if (-not (Test-Path $conf)) {
    $v1 = [System.IO.Compression.ZipFile]::OpenRead((Join-Path $root "docs\chat_v1.jsdos"))
    $entry = $v1.Entries | Where-Object { $_.FullName -eq ".jsdos/dosbox.conf" }
    $reader = New-Object System.IO.StreamReader($entry.Open())
    Set-Content -Path $conf -Value $reader.ReadToEnd() -Encoding ascii -NoNewline
    $reader.Close(); $v1.Dispose()
}

$out = Join-Path $root "docs\chat_v$Version.jsdos"
if (Test-Path $out) { Remove-Item $out }
$zip = [System.IO.Compression.ZipFile]::Open($out, "Create")
[void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $root "EXAMPLES\CHAT.COM"), "CHAT.COM")
[void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $conf, ".jsdos/dosbox.conf")
[void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $conf, "dosbox.conf")
$zip.Dispose()
Write-Host "packed: $out ($((Get-Item $out).Length) bytes)"
