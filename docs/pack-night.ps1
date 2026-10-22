# pack-night.ps1 - stage OWL NIGHT as a DISK: a folder tree for a repository
# of its own, which the game's page fetches file by file.
#
#   powershell -File docs\pack-night.ps1
#   powershell -File docs\pack-night.ps1 -Base https://kirindenis.github.io/owlnight-disk/
#
# The story's products are hundreds of megabytes and this repository stays
# thin, so they live in a SEPARATE repository - owlnight-disk - as plain
# files in the same tree the DOS engine reads: ENGINE\STORY.COM and
# STORY\NIGHT\<scene>\... GitHub serves such files with CORS from
# raw.githubusercontent.com (measured 2026-10-09; a GitHub RELEASE does
# not, and that is why this is a repository and not a release), each under
# 100 MB - the biggest clip is 69 MB; a longer one is cut at a six-second
# keyframe group. The page (docs\owlvid.html) reads docs\owlnight.json,
# fetches one edition's files from `base` and hands them to js-dos before
# it boots. Nothing big is committed here.
#
# What this script does:
#   - copies every file the game needs into docs\owlnight\disk\ (ignored by
#     git here) in the DOS tree, nothing else: no frames\, no .INF, .LOG,
#     SCENARIO.JSON;
#   - writes docs\owlnight.json - the manifest: each file's path (the same
#     on the disk and on C:), size, sha256 and edition (640, 320, shared).
#     COMMITTED, a few KB; the page reads it from this site.
#
# Then (by hand, see the instruction in Skill\POINTTASK.md): robocopy /MIR
# the disk folder into the clone of owlnight-disk, commit, push.
#
# Test before pushing: serve docs\ and open  owlvid.html?base=owlnight/disk/
# - the page then fetches from the staged folder on this site.
param(
  [string]$Base = "",
  [string]$DiskRepo = "owlnight-disk"
)
$ErrorActionPreference = "Stop"
$root  = Split-Path -Parent $PSScriptRoot
$story = Join-Path $root "LAB\OWLFLY4\STORY\NIGHT"
$engine = Join-Path $root "LAB\OWLFLY4\ENGINE\STORY.COM"
$out   = Join-Path $root "docs\owlnight\disk"
$manifestPath = Join-Path $root "docs\owlnight.json"

if ($Base -eq "") {
  $url = (git -C $root remote get-url origin).Trim()
  if ($url -match "github\.com[:/]([^/]+)/") { $owner = $Matches[1] } else { throw "cannot read the GitHub owner from the origin URL: $url" }
  $Base = "https://raw.githubusercontent.com/$owner/$DiskRepo/main/"
}
$Base = $Base.TrimEnd('/') + "/"
if (-not (Test-Path $engine)) { throw "STORY.COM is not built: $engine (LAB\OWLFLY4\ENGINE\MAKEWIN.BAT)" }

if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null

$sha = [Security.Cryptography.SHA256]::Create()
function Hash($path) { $s = [IO.File]::OpenRead($path); try { ([BitConverter]::ToString($sha.ComputeHash($s)) -replace '-', '').ToLower() } finally { $s.Dispose() } }

$files = @()
function Add($abs, $into, $edition) {
  $dest = Join-Path $out ($into -replace '/', '\')
  New-Item -ItemType Directory -Force (Split-Path $dest -Parent) | Out-Null
  Copy-Item $abs $dest -Force
  # an object, not a hashtable: Group-Object and ConvertTo-Json read properties
  $script:files += [pscustomobject][ordered]@{
    into = $into; bytes = (Get-Item $abs).Length; sha256 = (Hash $abs); edition = $edition
  }
}

Add $engine "ENGINE/STORY.COM" "shared"
$exts = '.INI', '.OWV', '.SPR', '.SLT', '.PCM'
foreach ($f in Get-ChildItem $story -Recurse -File | Where-Object { $exts -contains $_.Extension.ToUpper() -and $_.FullName -notmatch '\\frames\\' } | Sort-Object FullName) {
  $rel = $f.FullName.Substring($story.Length + 1) -replace '\\', '/'
  $edition = if ($rel -match '/320/') { "320" } elseif ($f.Extension -match '^\.(INI|PCM)$') { "shared" } else { "640" }
  Add $f.FullName "STORY/NIGHT/$rel" $edition
}

# a path GitHub and DOS both take as it is: letters, digits, dot, dash, underscore, slashes
foreach ($f in $files) { if ($f.into -notmatch '^[A-Za-z0-9._/-]+$') { throw "a path with a character a URL would rewrite: $($f.into)" } }
$big = $files | Where-Object { $_.bytes -gt 100MB }
if ($big) { throw "GitHub refuses a file over 100 MB: $($big[0].into) ($([int]($big[0].bytes / 1MB)) MB) - cut the clip at a keyframe group" }

# a README for the disk repository, so a visitor knows what it is
$readme = @"
# OWL NIGHT - the disk

The files of OWL NIGHT, a DOS story played by the engine in
[wire-city-2](https://github.com/KirinDenis/wire-city-2) (LAB/OWLFLY4):
``ENGINE/STORY.COM`` and ``STORY/NIGHT/`` - every scene's INI, its clips and
rooms at 640x400 (beside the INI) and at 320x200 (in each scene's ``320/``),
and the music. Made by ``docs/pack-night.ps1`` there, from the recipes in
``LAB/OWLFLY4/STORY/NIGHT``; this repository holds products only.

To play in DOS: put this tree on a disk, ``cd ENGINE``, ``STORY``. In the
browser: https://kirindenis.github.io/wire-city-2/owlvid.html fetches these
files from here.
"@
[IO.File]::WriteAllText((Join-Path $out "README.md"), $readme.Replace("`r`n", "`n"), (New-Object Text.UTF8Encoding($false)))

$manifest = [ordered]@{
  game = "OWL NIGHT"; base = $Base; made = (Get-Date).ToString("yyyy-MM-dd HH:mm")
  files = $files
}
[IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 4) -replace "`r?`n", "`n") + "`n", (New-Object Text.UTF8Encoding($false)))

$by = $files | Group-Object edition
Write-Host "staged $($files.Count) files in $out"
foreach ($g in $by) { Write-Host ("  {0,-7} {1,3} files {2,8:F1} MB" -f $g.Name, $g.Count, (($g.Group | Measure-Object bytes -Sum).Sum / 1MB)) }
Write-Host "manifest  $manifestPath  (commit this; base = $Base)"
Write-Host "disk      robocopy `"$out`" <clone of $DiskRepo> /MIR /XD .git   then commit and push there"
Write-Host "test      serve docs\ and open owlvid.html?base=owlnight/disk/"
