# pack.ps1 -Game <OWLFLY|OWLFLY2|WIRECITY|TRAINER> - build a versioned js-dos bundle.
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
  OWLFLY2 = @{
    prefix = "owlfly2"
    page   = Join-Path $root "docs\owlfly2.html"
    detect = "owlfly2_v(\d+)\.jsdos"
    files  = @(
      @{ p = "GAMES\OWLFLY2\INSTALL\FLYOWL2.EXE"; n = "FLYOWL2.EXE" },
      @{ p = "GAMES\OWLFLY2\INSTALL\CITY.DAT";    n = "CITY.DAT" },
      # the 90-degree cockpit views. Its own file because CITY.DAT is read
      # in one go with CX=0FFF0h and the front panel is 64000 of those bytes.
      @{ p = "GAMES\OWLFLY2\INSTALL\CPSIDE.DAT";  n = "CPSIDE.DAT" },
      # the recorded sound bank (TOOLS\Snd2Dat). Optional to the GAME - no
      # file and SFXPLAY is a no-op - which is exactly why leaving it out of
      # here was silent: the browser build simply had no effects, while the
      # engine note carried on because it is generated.
      @{ p = "GAMES\OWLFLY2\INSTALL\SFX.DAT";     n = "SFX.DAT" }
    )
    # NO .jsdos/jsdos.json HERE, AND THAT IS DELIBERATE. js-dos draws a
    # stick and buttons of its own from such a file, and for one afternoon
    # it did. Two of its rules cannot be configured: a button caption is
    # symbol.substr(0,1) - one character, so the lock button read as a zero
    # - and its joystick splits the circle into eight equal sectors, so a
    # thumb 25 degrees off straight-down gets a roll. The controls moved
    # into owlfly2.html, where both are ours to set. Put a jsdos.json back
    # and the pilot gets BOTH sets of buttons on top of each other.
    # Left out ON PURPOSE, and named here so the "not in the bundle" warning
    # below stays quiet about it. A warning that always fires is a warning
    # nobody reads, which would put us straight back where SFX.DAT was.
    # ENGINE.RAW: OWL FLY II generates its turbine (GENBED) and has since
    # 2026-07-23. The file in INSTALL is a leftover of the version that
    # loaded one.
    ignore = @("ENGINE.RAW")
    strings = @(
      # the BBS lesson (2026-07-19): minimal conf, and [ipx] ipx=true is
      # what lets the page's networkConnect reach the game's INT 7Ah
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[ipx]`nipx=true`n[autoexec]`necho off`nmount c .`nc:`nFLYOWL2`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[ipx]`nipx=true`n[autoexec]`necho off`nmount c .`nc:`nFLYOWL2`n" }
    )
  }
  OWLFLY3 = @{
    # the retro-cards release, on a COLOUR machine: the front step offers
    # CGA / EGA x2 / MCGA / VGA x2 and marks Hercules away. The mono
    # edition is its own bundle (OWLFLY3H) because the MACHINE differs.
    prefix = "owlfly3"
    page   = Join-Path $root "docs\owlfly3.html"
    detect = "owlfly3_v(\d+)\.jsdos"
    files  = @(
      @{ p = "GAMES\OWLFLY3\INSTALL\OWLFLY3.EXE"; n = "OWLFLY3.EXE" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CITY.DAT";    n = "CITY.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPSIDE.DAT";  n = "CPSIDE.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SFX.DAT";     n = "SFX.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SHCAB.DAT";   n = "SHCAB.DAT" },
      # the retro cards' baked cockpits and side-console marker maps
      # (TOOLS\VidRig emit) - miss one and that card flies on the plain
      # lookup, silently, which is exactly the SFX.DAT shape of failure
      @{ p = "GAMES\OWLFLY3\INSTALL\CPCGA.DAT";   n = "CPCGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPEGA.DAT";   n = "CPEGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPHGC.DAT";   n = "CPHGC.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPSCGA.DAT";  n = "CPSCGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPSEGA.DAT";  n = "CPSEGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPSHGC.DAT";  n = "CPSHGC.DAT" }
    )
    ignore = @("ENGINE.RAW")
    # THE WIRE IS BACK (2026-08-25): v3 flies its OWN relay room - owlfly3,
    # not owlfly2 - so the byte-identical protocol can never walk into v2's
    # skies. The separation lives in the relay URL (the page's business);
    # ipx=true here only wakes the driver.
    strings = @(
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[ipx]`nipx=true`n[autoexec]`necho off`nmount c .`nc:`nOWLFLY3`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[ipx]`nipx=true`n[autoexec]`necho off`nmount c .`nc:`nOWLFLY3`n" }
    )
  }
  OWLFLY3H = @{
    # the Hercules edition: the same game, the same files, but DOSBox
    # comes up as a real mono machine - the only place 720x348 exists.
    # The front step's hardware quiz lands on 1) HERCULES by itself.
    prefix = "owlfly3h"
    page   = Join-Path $root "docs\owlfly3h.html"
    detect = "owlfly3h_v(\d+)\.jsdos"
    files  = @(
      @{ p = "GAMES\OWLFLY3\INSTALL\OWLFLY3.EXE"; n = "OWLFLY3.EXE" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CITY.DAT";    n = "CITY.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPSIDE.DAT";  n = "CPSIDE.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SFX.DAT";     n = "SFX.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SHCAB.DAT";   n = "SHCAB.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPCGA.DAT";   n = "CPCGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPEGA.DAT";   n = "CPEGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPHGC.DAT";   n = "CPHGC.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPSCGA.DAT";  n = "CPSCGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPSEGA.DAT";  n = "CPSEGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPSHGC.DAT";  n = "CPSHGC.DAT" }
    )
    ignore = @("ENGINE.RAW")
    strings = @(
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=hercules`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[ipx]`nipx=true`n[autoexec]`necho off`nmount c .`nc:`nOWLFLY3`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=hercules`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[ipx]`nipx=true`n[autoexec]`necho off`nmount c .`nc:`nOWLFLY3`n" }
    )
  }
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
  TRAINER = @{
    prefix = "field"
    page   = Join-Path $root "docs\play.html"
    detect = "field_v(\d+)\.jsdos"
    files  = @(
      @{ p = "GAMES\TRAINER\FIELD.COM";  n = "FIELD.COM" },
      @{ p = "GAMES\TRAINER\PLANE1.DAT"; n = "PLANE1.DAT" },
      @{ p = "GAMES\TRAINER\RBASE1.DAT"; n = "RBASE1.DAT" },
      @{ p = "GAMES\TRAINER\RDISH1.DAT"; n = "RDISH1.DAT" },
      @{ p = "GAMES\TRAINER\TWR1.DAT";   n = "TWR1.DAT" },
      @{ p = "GAMES\TRAINER\CKPT1.DAT";  n = "CKPT1.DAT" },
      @{ p = "GAMES\TRAINER\CNPY1.DAT";  n = "CNPY1.DAT" }
    )
    strings = @(
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`nfield`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`nfield`n" }
    )
  }
  # The odd one out: this bundle is not a game, it is a WORKSHOP. It carries
  # SOURCES and the assembler rather than a finished binary, and the visitor
  # builds the programs themselves by typing MAKE - which is the entire point
  # of the lesson, and the reason FASM.EXE and CWSDPMI.EXE are in the list.
  # Their licences are in the list for the same reason: shipping the binaries
  # is only allowed with the notices beside them (see THIRD-PARTY.md).
  # The .BAT files come from LESSONS\L02\WEB and not from the lesson folder,
  # because in here every file sits in one directory and the lesson's own
  # MAKE.BAT reaches the assembler through ..\..\TOOLS\FASM.
  L02 = @{
    prefix = "l02"
    page   = Join-Path $root "docs\l02.html"
    detect = "l02_v(\d+)\.jsdos"
    files  = @(
      @{ p = "LESSONS\L02\HELLO.ASM";     n = "HELLO.ASM" },
      @{ p = "LESSONS\L02\HELLO2.ASM";    n = "HELLO2.ASM" },
      @{ p = "LESSONS\L02\HEX.ASM";       n = "HEX.ASM" },
      @{ p = "LESSONS\L02\WEB\MAKE.BAT";  n = "MAKE.BAT" },
      @{ p = "LESSONS\L02\WEB\EDIT.BAT";  n = "EDIT.BAT" },
      @{ p = "LESSONS\L02\WEB\HELP.BAT";  n = "HELP.BAT" },
      @{ p = "TOOLS\FASM\FASM.EXE";       n = "FASM.EXE" },
      @{ p = "TOOLS\FASM\FASMD.EXE";      n = "FASMD.EXE" },
      @{ p = "TOOLS\FASM\LICENSE.TXT";    n = "LICENSE.TXT" },
      @{ p = "TOOLS\CWSDPMI\CWSDPMI.EXE"; n = "CWSDPMI.EXE" },
      @{ p = "TOOLS\CWSDPMI\cwsdpmi.doc"; n = "CWSDPMI.DOC" }
    )
    # No binaries: the visitor assembles them. Shipping HELLO.COM would let
    # somebody reach step 3 without ever having run the assembler, and then
    # the page is a toy rather than a lesson.
    strings = @(
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`ncls`nHELP.BAT`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`ncls`nHELP.BAT`n" }
    )
  }
  # Lesson 3, same workshop shape as L02: sources and the assembler, no
  # binary. EDIT.BAT and FASMD.EXE come along because this is the first
  # lesson where changing a number and rebuilding is worth doing - one
  # constant is the colour of the dot.
  L03 = @{
    prefix = "l03"
    page   = Join-Path $root "docs\l03.html"
    detect = "l03_v(\d+)\.jsdos"
    files  = @(
      @{ p = "LESSONS\L03\PIXEL.ASM";     n = "PIXEL.ASM" },
      @{ p = "LESSONS\L03\WEB\MAKE.BAT";  n = "MAKE.BAT" },
      @{ p = "LESSONS\L03\WEB\RUN.BAT";   n = "RUN.BAT" },
      @{ p = "LESSONS\L03\WEB\HELP.BAT";  n = "HELP.BAT" },
      @{ p = "LESSONS\L02\WEB\EDIT.BAT";  n = "EDIT.BAT" },
      @{ p = "TOOLS\FASM\FASM.EXE";       n = "FASM.EXE" },
      @{ p = "TOOLS\FASM\FASMD.EXE";      n = "FASMD.EXE" },
      @{ p = "TOOLS\FASM\LICENSE.TXT";    n = "LICENSE.TXT" },
      @{ p = "TOOLS\CWSDPMI\CWSDPMI.EXE"; n = "CWSDPMI.EXE" },
      @{ p = "TOOLS\CWSDPMI\cwsdpmi.doc"; n = "CWSDPMI.DOC" }
    )
    strings = @(
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`ncls`nHELP.BAT`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`ncls`nHELP.BAT`n" }
    )
  }
  # Lesson 5, the workshop shape again. MKSIN.C rides along as SOURCE ONLY:
  # it needs a C compiler and floating point, and neither is in here. That is
  # not a gap in the bundle, it is the lesson's own argument - the modern
  # tool prepares the data somewhere else and the 8086 never meets it. So
  # SINT.INC is shipped finished, and MKSIN.C is shipped to be read.
  L05 = @{
    prefix = "l05"
    page   = Join-Path $root "docs\l05.html"
    detect = "l05_v(\d+)\.jsdos"
    files  = @(
      @{ p = "LESSONS\L05\TURN.ASM";      n = "TURN.ASM" },
      @{ p = "LESSONS\L05\SINT.INC";      n = "SINT.INC" },
      @{ p = "LESSONS\L05\MKSIN.C";       n = "MKSIN.C" },
      @{ p = "LESSONS\L05\WEB\MAKE.BAT";  n = "MAKE.BAT" },
      @{ p = "LESSONS\L05\WEB\RUN.BAT";   n = "RUN.BAT" },
      @{ p = "LESSONS\L05\WEB\HELP.BAT";  n = "HELP.BAT" },
      @{ p = "LESSONS\L02\WEB\EDIT.BAT";  n = "EDIT.BAT" },
      @{ p = "TOOLS\FASM\FASM.EXE";       n = "FASM.EXE" },
      @{ p = "TOOLS\FASM\FASMD.EXE";      n = "FASMD.EXE" },
      @{ p = "TOOLS\FASM\LICENSE.TXT";    n = "LICENSE.TXT" },
      @{ p = "TOOLS\CWSDPMI\CWSDPMI.EXE"; n = "CWSDPMI.EXE" },
      @{ p = "TOOLS\CWSDPMI\cwsdpmi.doc"; n = "CWSDPMI.DOC" }
    )
    strings = @(
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`ncls`nHELP.BAT`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`ncls`nHELP.BAT`n" }
    )
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

# ...and now the other direction, which is the one that actually bites. The
# list above is hand-written, so a NEW data file is not left out loudly - it
# is left out SILENTLY: the local build has it, the browser build does not,
# and nothing fails anywhere. SFX.DAT shipped exactly that way, and the game
# was right to carry on without it (no bank, no effects, engine note
# unchanged), which is what made it invisible. This warns instead.
$listed = $g.files | ForEach-Object { Split-Path $_.p -Leaf }
$dirs   = $g.files | ForEach-Object { Split-Path (Join-Path $root $_.p) -Parent } |
          Sort-Object -Unique
foreach ($d in $dirs) {
  Get-ChildItem $d -File | Where-Object { $_.Extension -in '.DAT', '.RAW' } |
    ForEach-Object {
      if ($listed -notcontains $_.Name -and $g.ignore -notcontains $_.Name) {
        Write-Warning "$($_.Name) is in $d but NOT in the bundle - deliberate?"
      }
    }
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
# say WHAT went in, with the hour it was built: a bundle is only ever as
# fresh as the binary inside it, and a stale one looks exactly like a
# good one from the outside (the lesson of 2026-07-28)
foreach ($f in $g.files) {
  $fi = Get-Item (Join-Path $root $f.p)
  Write-Host ("  {0,-14} {1,8:N0} bytes  built {2:yyyy-MM-dd HH:mm}" -f $f.n, $fi.Length, $fi.LastWriteTime)
}
