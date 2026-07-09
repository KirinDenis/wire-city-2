# pack.ps1 - build the js-dos bundle as docs/city_vN.jsdos
#
# js-dos caches extracted bundles in the browser's IndexedDB keyed by the
# bundle PATH - a ?v= query does NOT bust it (Ctrl+Shift+R won't help).
# So every release gets a NEW FILENAME: this script reads the current
# city_vN.jsdos from index.html, packs v(N+1), deletes the older bundles
# and patches index.html. Run it via PUBLISH.BAT.
#
# Built with .NET ZipArchive (NOT Compress-Archive): Windows PowerShell
# 5.1's Compress-Archive writes BACKSLASH entry names, which violate the
# ZIP spec and break js-dos's unzip in the browser.

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root  = Split-Path -Parent $PSScriptRoot      # repo root (parent of docs)
$com   = Join-Path $root "INSTALL\CITY.COM"
$dat   = Join-Path $root "INSTALL\CITY.DAT"       # resources (font, cockpit)
$conf  = Join-Path $root "docs\dosbox.conf"        # full machine config + autoexec
$rconf = Join-Path $root "docs\dosbox-root.conf"   # root override (cycles)
$idx   = Join-Path $root "docs\index.html"

if (-not (Test-Path $com)) {
    throw "INSTALL\CITY.COM not found - build it first (see MAKE.BAT)."
}
if (-not (Test-Path $dat)) {
    throw "INSTALL\CITY.DAT not found - build it first (see MAKE.BAT)."
}

# next version = the one referenced in index.html + 1
$s = Get-Content $idx -Raw
$m = [regex]::Match($s, 'city_v(\d+)\.jsdos')
if ($m.Success) { $n = [int]$m.Groups[1].Value + 1 } else { $n = 27 }
$name = "city_v$n.jsdos"
$out  = Join-Path $root "docs\$name"

if (Test-Path $out) { Remove-Item -Force $out }
$fs  = [System.IO.File]::Open($out, [System.IO.FileMode]::CreateNew)
$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)

function Add-ZipEntry($zip, $path, $name) {
    $entry  = $zip.CreateEntry($name, [System.IO.Compression.CompressionLevel]::Optimal)
    $stream = $entry.Open()
    $bytes  = [System.IO.File]::ReadAllBytes($path)
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Close()
}

Add-ZipEntry $zip $com   "CITY.COM"
Add-ZipEntry $zip $dat   "CITY.DAT"                # must sit next to CITY.COM
$eng = Join-Path $root "INSTALL\ENGINE.RAW"
if (Test-Path $eng) { Add-ZipEntry $zip $eng "ENGINE.RAW" }  # the real engine
Add-ZipEntry $zip $conf  ".jsdos/dosbox.conf"      # full config (mounts c:, runs CITY.COM)
Add-ZipEntry $zip $rconf "dosbox.conf"             # root override, matches js-dos studio layout

$zip.Dispose()
$fs.Close()

# retire the older bundles (the query-string era one too)
Get-ChildItem (Join-Path $root "docs") -Filter "city_v*.jsdos" |
    Where-Object { $_.Name -ne $name } | Remove-Item -Force
$legacy = Join-Path $root "docs\city.jsdos"
if (Test-Path $legacy) { Remove-Item -Force $legacy }

# point index.html at the new bundle (handles the old ?v= form as well)
$s = $s -replace 'city(_v\d+)?\.jsdos(\?v=\d+)?', $name
Set-Content -Encoding ascii $idx $s

Write-Host "Created docs/$name and updated index.html"
