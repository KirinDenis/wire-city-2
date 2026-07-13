# pack.ps1 -Game <OWLFLY|WIRECITY> - build a versioned js-dos bundle.
#
# js-dos caches extracted bundles in IndexedDB keyed by the bundle PATH,
# so every release gets a NEW FILENAME: <prefix>_vN.jsdos. This script
# reads the current N from the game's PLAYER PAGE, packs v(N+1), retires
# the older bundles of that game and patches the page.
# Built with .NET ZipArchive: PS 5.1 Compress-Archive writes backslash
# entry names which break js-dos unzip.
param([string]$Game = "OWLFLY")

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Split-Path -Parent $PSScriptRoot

# ---- the per-game map: add a game = add an entry --------------------------
$MAP = @{
  OWLFLY = @{
    prefix = "owlfly"
    page   = Join-Path $root "docs\owlfly.html"
    detect = "(?:city|owlfly)_v(\d+)\.jsdos"
    files  = @(
      @{ p = "GAMES\OWLFLY\INSTALL\FLYOWL.COM";   n = "FLYOWL.COM" },
      @{ p = "GAMES\OWLFLY\INSTALL\CITY.DAT";   n = "CITY.DAT" },
      @{ p = "GAMES\OWLFLY\INSTALL\ENGINE.RAW"; n = "ENGINE.RAW" },
      @{ p = "docs\dosbox.conf";      n = ".jsdos/dosbox.conf" },
      @{ p = "docs\dosbox-root.conf"; n = "dosbox.conf" }
    )
    strings = @()
  }
  WIRECITY = @{
    prefix = "wirecity"
    page   = Join-Path $root "docs\play.html"
    detect = "wirecity_v(\d+)\.jsdos"
    files  = @(
      @{ p = "GAMES\WIRECITY\CITY.COM"; n = "CITY.COM" }
    )
    strings = @(
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`ncity`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`ncity`n" }
    )
  }
}
if (-not $MAP.ContainsKey($Game)) { throw "Unknown game '$Game' - see the map in pack.ps1" }
$g = $MAP[$Game]

foreach ($f in $g.files) {
  $full = Join-Path $root $f.p
  if (-not (Test-Path $full)) { throw "$($f.p) not found - build it first (MAKE.BAT $Game)" }
}

# next version = the one referenced in the player page + 1
$s = Get-Content $g.page -Raw
$m = [regex]::Match($s, $g.detect)
if ($m.Success) { $n = [int]$m.Groups[1].Value + 1 } else { $n = 1 }
$name = "$($g.prefix)_v$n.jsdos"
$out  = Join-Path $root "docs\$name"

if (Test-Path $out) { Remove-Item -Force $out }
$fs  = [System.IO.File]::Open($out, [System.IO.FileMode]::CreateNew)
$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
foreach ($f in $g.files) {
  $entry  = $zip.CreateEntry($f.n, [System.IO.Compression.CompressionLevel]::Optimal)
  $stream = $entry.Open()
  $bytes  = [System.IO.File]::ReadAllBytes((Join-Path $root $f.p))
  $stream.Write($bytes, 0, $bytes.Length)
  $stream.Close()
}
foreach ($e in $g.strings) {
  $entry  = $zip.CreateEntry($e.n, [System.IO.Compression.CompressionLevel]::Optimal)
  $stream = $entry.Open()
  $bytes  = [System.Text.Encoding]::ASCII.GetBytes($e.c)
  $stream.Write($bytes, 0, $bytes.Length)
  $stream.Close()
}
$zip.Dispose()
$fs.Close()

# retire this game's older bundles (incl. the legacy city_v* for OWLFLY)
Get-ChildItem (Join-Path $root "docs") -Filter "$($g.prefix)_v*.jsdos" |
    Where-Object { $_.Name -ne $name } | Remove-Item -Force
if ($Game -eq "OWLFLY") {
  Get-ChildItem (Join-Path $root "docs") -Filter "city_v*.jsdos" | Remove-Item -Force
}

# point the player page at the new bundle
$s = [regex]::Replace($s, $g.detect, $name)
Set-Content -Encoding ascii $g.page $s
Write-Host "Created docs/$name and updated $(Split-Path $g.page -Leaf)"
