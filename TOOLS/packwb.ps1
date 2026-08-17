# packwb.ps1 - stage the WORKBENCH disk from manifests; -Pack zips it.
#
#   powershell -ExecutionPolicy Bypass -File TOOLS\packwb.ps1          stage DISK\
#   powershell -ExecutionPolicy Bypass -File TOOLS\packwb.ps1 -Pack   stage + bundle
#
# THE LIST OF FILES IS NOT WRITTEN HERE, AND THAT IS THE POINT. pack.ps1
# builds bundles from a hand-written list, and its own comments record what
# that costs: SFX.DAT was added to the game, left out of the list, and
# shipped silently missing for weeks. A hundred-file disk hand-listed would
# walk straight back into that. This script walks the .INF manifests instead:
# one small file per entry (LESSONS\L05\L05.INF, EXAMPLES\RING.INF,
# GAMES\WIRECITY\WIRECITY.INF) names what ships, and the same file feeds
# MENU.COM on the disk and the course page on the web. One description,
# many readers - none of them hand-kept in step.
#
# The disk is staged as a real directory, DISK\, so it can be BOOTED under
# DOSBox (TOOLS\RUNWB.BAT) before it is ever packed. A bundle that has never
# been booted looks exactly like one that has.

param([switch]$Pack)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Split-Path -Parent $PSScriptRoot
$disk = Join-Path $root "DISK"
$marker = Join-Path $disk ".STAGED"

$problems = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

# ---- manifest format -------------------------------------------------------
# Lines of ".field value". ASCII, CRLF (MENU.COM parses these in assembly).
# List fields hold space-separated names. .needs may name a DIRECTORY
# (trailing backslash not required); it ships whole and its inside is exempt
# from the unmentioned-file scan. .engine paths are repo-root-relative.
# An entry with no .build and no .run is read-only: the menu offers open.
$LISTFIELDS = @("needs", "reads", "uses", "ignore", "engine")

function Read-Inf([string]$path) {
  $inf = @{ dir = (Split-Path $path -Parent); file = $path
            name = [System.IO.Path]::GetFileNameWithoutExtension($path)
            build = @() }
  foreach ($line in Get-Content $path) {
    if ($line -match '^\.([a-z]+)\s+(.+?)\s*$') {
      $k = $Matches[1]; $v = $Matches[2]
      if ($k -eq "build") { $inf.build += $v }   # repeats accumulate, in order:
                                                 # a game builds in several steps
      elseif ($LISTFIELDS -contains $k) {
        if ($inf.ContainsKey($k)) { $inf[$k] = @($inf[$k]) + @($v -split '\s+') }
        else { $inf[$k] = @($v -split '\s+') }
      }
      else { $inf[$k] = $v }
    }
  }
  return $inf
}

# ---- fresh staging area ----------------------------------------------------
# Refuse to delete a DISK\ we did not stage: the marker file is written by
# this script and nothing else. A hand-made directory in its place is
# somebody's work, not our debris.
if (Test-Path $disk) {
  if (-not (Test-Path $marker)) { throw "DISK\ exists but has no .STAGED marker - not deleting somebody's directory. Move it aside." }
  Remove-Item -Recurse -Force $disk
}
foreach ($d in "", "TOOLS", "LESSONS", "EXAMPLES", "GAMES", "ENGINE", "HELP", "WORK") {
  New-Item -ItemType Directory -Force (Join-Path $disk $d) | Out-Null
}
Set-Content -Encoding ascii $marker "staged by TOOLS\packwb.ps1 - safe to delete`r`n"

function Stage([string]$src, [string]$destRel) {
  $from = Join-Path $root $src
  $to   = Join-Path $disk $destRel
  if (-not (Test-Path $from)) { $problems.Add("$src is missing (wanted at $destRel)"); return }
  $toDir = Split-Path $to -Parent
  if (-not (Test-Path $toDir)) { New-Item -ItemType Directory -Force $toDir | Out-Null }
  if (Test-Path $from -PathType Container) {
    # a directory ships filtered: build products and repo-only files do not
    # ride along just because a manifest said "the whole of SRC"
    foreach ($f in Get-ChildItem $from -Recurse -File) {
      if ($DERIVED -contains $f.Extension.ToUpper()) { continue }
      if ($REPOONLY -contains $f.Name) { continue }
      $sub = $f.FullName.Substring($from.Length + 1)
      $dst = Join-Path $to $sub
      $dstDir = Split-Path $dst -Parent
      if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Force $dstDir | Out-Null }
      Copy-Item -Force $f.FullName $dst
    }
  }
  else { Copy-Item -Force $from $to }
}

function Put([string]$destRel, [string]$text) {
  # every generated file is CRLF by construction
  $to = Join-Path $disk $destRel
  $toDir = Split-Path $to -Parent
  if (-not (Test-Path $toDir)) { New-Item -ItemType Directory -Force $toDir | Out-Null }
  [System.IO.File]::WriteAllText($to, ($text -replace "`r?`n", "`r`n"), [System.Text.Encoding]::ASCII)
}

# ---- the tools -------------------------------------------------------------
# Licences travel beside binaries: shipping FASM and CWSDPMI is only
# permitted with the notices next to them. See THIRD-PARTY.md before adding
# anything here.
Stage "TOOLS\FASM\FASM.EXE"        "TOOLS\FASM.EXE"
Stage "TOOLS\FASM\FASMD.EXE"       "TOOLS\FASMD.EXE"
Stage "TOOLS\FASM\LICENSE.TXT"     "TOOLS\LICENSE.TXT"
Stage "TOOLS\CWSDPMI\CWSDPMI.EXE"  "TOOLS\CWSDPMI.EXE"
Stage "TOOLS\CWSDPMI\cwsdpmi.doc"  "TOOLS\CWSDPMI.DOC"
Stage "TOOLS\LISTING\LISTING.EXE"  "TOOLS\LISTING.EXE"
Stage "TOOLS\OBJ2DAT.COM"          "TOOLS\OBJ2DAT.COM"   # TRAINER's model packer - DOS-native, ours
Stage "LICENSE"                    "LICENSE"

# HEX.COM is lesson 2's own output - the course's tools are its lessons'
# products, which is the argument for shipping it at all. It is gitignored
# (the reader builds it), so a fresh checkout must run the lesson's MAKE once.
if (Test-Path (Join-Path $root "LESSONS\L02\HEX.COM")) {
  Stage "LESSONS\L02\HEX.COM" "TOOLS\HEX.COM"
} else {
  $problems.Add("LESSONS\L02\HEX.COM is missing - run LESSONS\L02\MAKE (it is the lesson's own build output)")
}

# The menu, its template for N)ew, and the editor INI (optimal fill OFF -
# it retabs saved files and breaks byte-identity with the repository).
Stage "TOOLS\MENU\MENU.COM"   "MENU.COM"
Stage "TOOLS\MENU\NEW.ASM"    "TOOLS\NEW.ASM"
Stage "TOOLS\MENU\FASMD.INI"  "TOOLS\FASMD.INI"

# ---- the manifests ---------------------------------------------------------
$infPaths = @()
$infPaths += Get-ChildItem (Join-Path $root "LESSONS")  -Directory | ForEach-Object { Get-ChildItem $_.FullName -Filter *.INF -File }
$infPaths += Get-ChildItem (Join-Path $root "EXAMPLES") -Filter *.INF -File
$infPaths += Get-ChildItem (Join-Path $root "GAMES")    -Directory | ForEach-Object { Get-ChildItem $_.FullName -Filter *.INF -File }

if ($infPaths.Count -eq 0) { $warnings.Add("no .INF manifests found - the disk has tools and nothing to teach") }

# Files the repository needs and the disk never will. Extend deliberately;
# a growing list here is cheaper than a warning nobody reads.
$REPOONLY = @("README.md", "README.MD", "MAKE.BAT", "RUN.BAT", "MAKEWIN.BAT", "RUNWIN.BAT",
              "RECON.BAT", "CONVERT.BAT", "PUBLISH.BAT", "PLAY.BAT", "EDIT.BAT", "HELP.BAT",
              "NETHOST.BAT", "NETJOIN.BAT", "NET.CONF", "ARCHITECTURE.md", "LICENSE", "LESSONS.md",
              "mkpanel.py", "mkengine.py")
$REPOONLYDIRS = @("WEB", "SHOTS")
# NB "res" is NOT repo-only across the board: TRAINER's MAKE consumes
# res\*.OBJ through OBJ2DAT and they must ship. Games whose res\ is
# Windows-side artwork put it in their own .ignore instead.
# Build products are what the student is there to make; they never ship.
$DERIVED = @(".COM", ".EXE", ".OBJ", ".FAS", ".LST", ".MAP", ".BAK", ".LOG")

$entries = @()
foreach ($p in $infPaths) {
  $inf = Read-Inf $p.FullName
  $entryRel = $p.Directory.FullName.Substring($root.Length + 1)   # e.g. LESSONS\L05
  $inf.rel = $entryRel
  $entries += $inf

  # the manifest itself ships - MENU.COM reads it there
  Stage (Join-Path $entryRel $p.Name) (Join-Path $entryRel $p.Name)

  $mentioned = @($p.Name)
  foreach ($field in @("main", "run")) {
    if ($inf[$field]) { $mentioned += $inf[$field] }
  }
  foreach ($field in @("needs", "reads", "ignore")) {
    if ($inf[$field]) { $mentioned += $inf[$field] }
  }

  if ($inf.main) { Stage (Join-Path $entryRel $inf.main) (Join-Path $entryRel $inf.main) }
  foreach ($field in @("needs", "reads")) {
    foreach ($n in @($inf[$field])) {
      if ($n) { Stage (Join-Path $entryRel $n) (Join-Path $entryRel $n) }
    }
  }
  foreach ($e in @($inf.engine)) {
    if ($e) { Stage $e $e; $mentioned += $e }   # repo-root-relative, same place on disk
  }

  $inf.mentioned = $mentioned
}

# ---- the other direction, the one that actually bites -----------------------
# A file added to an entry's directory and mentioned nowhere is exactly how
# SFX.DAT went missing for weeks - and it went missing in a SUBFOLDER, which
# is why this scan is recursive. It runs once per DIRECTORY against the
# union of every entry's mentions there (EXAMPLES holds thirteen entries in
# one flat folder, and each is somebody else's stray otherwise). Three
# layers keep the warning rare enough to be read: derived artifacts are
# silent (the student builds them), the repo-only list is silent, and
# everything else warns unless a manifest's .ignore names it. A mention of
# a directory covers everything inside it.
foreach ($grp in ($entries | Group-Object { $_.rel })) {
  $dirRel = $grp.Name
  $dirFull = Join-Path $root $dirRel
  $normMentioned = @()
  foreach ($e in $grp.Group) {
    $normMentioned += @($e.mentioned | Where-Object { $_ } | ForEach-Object { $_.TrimEnd("\").ToUpper() })
  }
  foreach ($f in Get-ChildItem $dirFull -Recurse -File) {
    $relf = $f.FullName.Substring($dirFull.Length + 1)
    $covered = $false
    $u = $relf.ToUpper()
    foreach ($m in $normMentioned) {
      if ($u -eq $m -or $u.StartsWith($m + "\")) { $covered = $true; break }
    }
    if ($covered) { continue }
    if ($relf -split "\\" | Where-Object { $REPOONLYDIRS -contains $_ }) { continue }
    if ($DERIVED -contains $f.Extension.ToUpper()) { continue }
    if ($REPOONLY -contains $f.Name) { continue }
    if ($f.Extension -ieq ".INF") { continue }   # another entry, not a stray
    $warnings.Add("$dirRel\$relf is mentioned by no manifest - ships nowhere. Deliberate? (.ignore silences this)")
  }
}

# ---- generated batches -----------------------------------------------------
# The disk's MAKE.BAT and RUN.BAT are derived from the manifest - its fourth
# reader - so no hand-written copy can drift. Every batch prints the command
# before running it; that is the whole pedagogy, and it is the rule the
# hand-written bundle batches already followed.
$byDir = $entries | Group-Object { $_.rel }
foreach ($grp in $byDir) {
  $dirRel = $grp.Name
  $built = @($grp.Group | Where-Object { $_.build.Count -gt 0 })

  # MAKE builds everything in the directory, in manifest order, echoing each
  # command before it runs - the batch is the printed transcript of what a
  # hand would type. One entry or thirteen, same shape: no NAME dispatch,
  # because COMMAND.COM's IF is case-sensitive and a dispatcher that fails
  # on a lowercase name is a trap, not a tool. Building one thing by hand is
  # exactly the command MAKE just showed.
  if ($built.Count -gt 0) {
    $mk = "@echo off`n"
    foreach ($e in $built) {
      foreach ($cmd in $e.build) {
        $mk += "echo $cmd`n$cmd`n"
      }
      if ($e.run) {
        $bin = ($e.run -split '\s+')[0]
        $mk += "if not exist $bin echo BUILD FAILED for $($e.name) - $bin was not written; the reason is printed above.`n"
      }
    }
    $names = ($built | ForEach-Object { $_.name }) -join ", "
    $mk += "echo.`necho Done: $names.  Type RUN to see what runs.`n"
    Put (Join-Path $dirRel "MAKE.BAT") $mk
  }

  $runnable = @($grp.Group | Where-Object { $_.run })
  if ($runnable.Count -eq 1) {
    $e = $runnable[0]
    $bin = ($e.run -split '\s+')[0]
    $rn = "@echo off`n"
    if ($e.rundir) { $rn += "cd $($e.rundir)`n" }   # a game that opens its data by bare name runs from where the data is
    $rn += "if not exist $bin goto nothing`n"
    $rn += "echo $($e.run)`n$($e.run)`n"
    if ($e.rundir) { $rn += "cd ..`n" }
    $rn += "goto end`n"
    $rn += ":nothing`n"
    if ($e.rundir) { $rn += "cd ..`n" }
    $rn += "echo Nothing to run yet - this disk ships the source and the assembler,`n"
    $rn += "echo never the program. Type MAKE first; the first binary you own is one you made.`n:end`n"
    Put (Join-Path $dirRel "RUN.BAT") $rn
  } elseif ($runnable.Count -gt 1) {
    # several programs share this directory: RUN lists them; typing a name
    # runs it, which is how DOS already works and worth saying out loud
    $rn = "@echo off`necho These run from here - type the name itself:`n"
    foreach ($e in $runnable) { $rn += "echo   $($e.run)`n" }
    $rn += "echo (not built yet? type MAKE first - the source ships, the program never does)`n"
    Put (Join-Path $dirRel "RUN.BAT") $rn
  }
}

# ---- the disk's own small files -------------------------------------------
Put "BOOT.BAT" @"
@echo off
set PATH=C:\TOOLS;Z:\
C:\TOOLS\CWSDPMI.EXE -p
MENU
"@

# SELFTEST.BAT - the automated half of "test it in DOS before packing":
# build every entry the way a student would, one MAKE after another, and
# leave SELFTEST.OK only if the walk finished. TOOLS\TESTWB.BAT drives it
# headless; the produced binaries are then compared outside.
$st = "@echo off`nset PATH=C:\TOOLS;Z:\`nC:\TOOLS\CWSDPMI.EXE -p`nif exist SELFTEST.OK del SELFTEST.OK`n"
foreach ($grp in $byDir) {
  $hasBuild = @($grp.Group | Where-Object { $_.build.Count -gt 0 })
  if ($hasBuild.Count -eq 0) { continue }
  $st += "cd \$($grp.Name)`ncall MAKE.BAT`ncd \`n"
}
$st += "echo done > SELFTEST.OK`nexit`n"
Put "SELFTEST.BAT" $st

Put "HELP\README.TXT" @"
One file per instruction goes in here - SAR.TXT, IMUL.TXT, LOOP.TXT - the
file name IS the instruction. Nothing is here yet; the reference is its own
piece of work. Until then, every lesson explains each instruction the first
time it uses it, in the comments beside the code.
"@

Put "WORK\README.TXT" @"
This directory is yours. Nothing on the disk writes here but you.

Press N in the menu to start a program of your own, or type:
  FASMD C:\WORK\MY.ASM
The machine forgets everything when the page closes - the button on the
web page saves this directory to your computer, and dropping the files
back onto the page restores them.
"@

$conf = @"
[sdl]
autolock=false
[dosbox]
machine=svga_s3
memsize=16
[cpu]
core=auto
cycles=max
[ipx]
ipx=true
[autoexec]
echo off
mount c .
c:
BOOT.BAT
"@
# ipx=true is for EXAMPLES\BBS and OWL FLY II's net play: it is what lets the
# page's networkConnect reach INT 7Ah (the BBS lesson, 2026-07-19).
Put "dosbox.conf" $conf
# NO .jsdos/jsdos.json - ever. js-dos draws its own stick and buttons from
# such a file, and the visitor would get both control sets on top of each
# other. The touch layer lives in the page. The second dosbox.conf copy
# (.jsdos/dosbox.conf) is written at pack time below.

# ---- CRLF: verify, never convert ------------------------------------------
# A lone LF shows a whole program as one endless line in every DOS editor
# there is. Converting here would make the disk's copy differ from the
# repository's and quietly break the byte-identity check, so a bad file
# fails the stage and gets fixed at the source.
$TEXTEXT = @(".ASM", ".INC", ".BAT", ".TXT", ".INI", ".INF", ".C", ".PAS", ".DOC")
$badCrlf = @()
foreach ($f in Get-ChildItem $disk -Recurse -File) {
  if ($TEXTEXT -notcontains $f.Extension.ToUpper()) { continue }
  $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
  for ($i = 0; $i -lt $bytes.Length; $i++) {
    if ($bytes[$i] -eq 10 -and ($i -eq 0 -or $bytes[$i-1] -ne 13)) {
      $badCrlf += $f.FullName.Substring($disk.Length + 1); break
    }
  }
}
foreach ($b in $badCrlf) { $problems.Add("$b has bare LF line endings - fix it in the repository, staging will not convert") }

# ---- report ----------------------------------------------------------------
Write-Host ""
foreach ($w in $warnings) { Write-Warning $w }
foreach ($p2 in $problems) { Write-Host "PROBLEM: $p2" -ForegroundColor Red }

$total = 0
foreach ($d in Get-ChildItem $disk -Directory) {
  $sz = (Get-ChildItem $d.FullName -Recurse -File | Measure-Object Length -Sum).Sum
  if ($null -eq $sz) { $sz = 0 }
  $total += $sz
  Write-Host ("  {0,-10} {1,9:N0} bytes" -f ($d.Name + "\"), $sz)
}
foreach ($f in Get-ChildItem $disk -File | Where-Object { $_.Name -ne ".STAGED" }) { $total += $f.Length }
Write-Host ("  {0,-10} {1,9:N0} bytes  ({2} entries from {3} manifests)" -f "TOTAL", $total, $entries.Count, $infPaths.Count)
Write-Host ""
Write-Host "Staged DISK\. Boot it: TOOLS\RUNWB.BAT - test in DOS before packing."

# ---- pack ------------------------------------------------------------------
if (-not $Pack) { exit 0 }
if ($problems.Count -gt 0) { throw "not packing with $($problems.Count) problem(s) above - a bundle that has never been complete looks exactly like one that has" }

# js-dos caches extracted bundles in IndexedDB keyed by the bundle PATH, so
# every release gets a NEW FILENAME, read from the page rather than a counter.
$page = Join-Path $root "docs\workbench.html"
$detect = "workbench_v(\d+)\.jsdos"
$n = 1
$pageText = $null
if (Test-Path $page) {
  $pageText = Get-Content $page -Raw
  $m = [regex]::Match($pageText, $detect)
  if ($m.Success) { $n = [int]$m.Groups[1].Value + 1 }
} else {
  $warnings.Add("docs\workbench.html does not exist yet - packing v$n, nothing to patch")
}
$name = "workbench_v$n.jsdos"
$out = Join-Path $root "docs\$name"

if (Test-Path $out) { Remove-Item -Force $out }
$fs  = [System.IO.File]::Open($out, [System.IO.FileMode]::CreateNew)
$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
foreach ($f in Get-ChildItem $disk -Recurse -File) {
  if ($f.Name -eq ".STAGED") { continue }
  if ($f.Name -eq "SELFTEST.BAT") { continue }   # the test rig, not the disk
  # FORWARD slashes: PS 5.1's Compress-Archive writes backslash entry names
  # and js-dos then fails to unzip - that is why this is .NET ZipArchive.
  $rel = $f.FullName.Substring($disk.Length + 1) -replace "\\", "/"
  $entry  = $zip.CreateEntry($rel, [System.IO.Compression.CompressionLevel]::Optimal)
  $stream = $entry.Open()
  $bytes  = [System.IO.File]::ReadAllBytes($f.FullName)
  $stream.Write($bytes, 0, $bytes.Length)
  $stream.Close()
}
# both dosbox.conf copies, identical content
$entry  = $zip.CreateEntry(".jsdos/dosbox.conf", [System.IO.Compression.CompressionLevel]::Optimal)
$stream = $entry.Open()
$bytes  = [System.Text.Encoding]::ASCII.GetBytes(($conf -replace "`r?`n", "`r`n"))
$stream.Write($bytes, 0, $bytes.Length)
$stream.Close()
$zip.Dispose()
$fs.Close()

Get-ChildItem (Join-Path $root "docs") -Filter "workbench_v*.jsdos" |
    Where-Object { $_.Name -ne $name } | Remove-Item -Force

if ($pageText) {
  $pageText = [regex]::Replace($pageText, $detect, $name)
  Set-Content -Encoding ascii $page $pageText
}
$outSize = (Get-Item $out).Length
Write-Host ("Created docs/$name - {0:N0} bytes compressed, {1:N0} staged" -f $outSize, $total)
