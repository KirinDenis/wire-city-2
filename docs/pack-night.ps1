# pack-night.ps1 - stage OWL NIGHT for a GitHub RELEASE, not for a bundle.
#
#   powershell -File docs\pack-night.ps1               tag night-v1
#   powershell -File docs\pack-night.ps1 -Tag night-v2
#
# The story's products are hundreds of megabytes and GitHub Pages refuses a
# file over 100 MB, which is why the game used to be a .jsdos bundle that
# never fitted. A release is the other half of GitHub: assets of up to
# 2 GB each, outside the repository's history, served with CORS - so the
# page can fetch them one file at a time and hand them to the emulator
# BEFORE it boots (js-dos's initFs; the same way OWLOSUI's DOS PC builds its
# C:). Nothing big is committed any more.
#
# What this script does, and does NOT do:
#   - copies every file the game needs into docs\owlnight\release\ (ignored
#     by git) under a FLAT name, because release assets have no folders:
#     STORY\NIGHT\S01\320\CLIP.OWV becomes S01--320--CLIP.OWV;
#   - writes docs\owlnight.json - the manifest the page reads: where each
#     asset goes on C:, its size, its hash, and which edition it belongs to
#     (640, 320, or shared). This file IS committed; it is a few KB;
#   - writes docs\owlnight\upload.cmd: the gh commands that create the
#     release if it is missing and upload every asset whose hash differs
#     from the manifest that was committed last time. It does not run them.
#     Uploading is publishing, and publishing is the pilot's hand.
#
# Test before uploading: serve docs\ and open
#     owlvid.html?base=owlnight/release/
# - the page then fetches the staged files from this folder instead of the
# release, and plays exactly what the release will.
#
# WHERE THE FILES LIVE IS A PARAMETER, and here is why. Measured 2026-10-09
# with curl and an Origin header: a GitHub release download answers with NO
# Access-Control-Allow-Origin on either hop (github.com's 302, then the
# Azure blob behind release-assets.githubusercontent.com). A browser will
# not let the page read such a response, so the release can hold the files
# and people can download them, but the PAGE cannot fetch them from there.
# -Base names a host that does send the header: a folder on our own server
# behind one Caddy block (header Access-Control-Allow-Origin "*"), or the
# Google Drive API. Without -Base the manifest points at the release, which
# is right for the DOS player and wrong for the page - and the script says
# so.
param(
  [string]$Tag = "night-v1",
  [string]$Repo = "",
  [string]$Base = ""
)
$ErrorActionPreference = "Stop"
$root  = Split-Path -Parent $PSScriptRoot
$story = Join-Path $root "LAB\OWLFLY4\STORY\NIGHT"
$engine = Join-Path $root "LAB\OWLFLY4\ENGINE\STORY.COM"
$out   = Join-Path $root "docs\owlnight\release"
$manifestPath = Join-Path $root "docs\owlnight.json"
$uploadPath   = Join-Path $root "docs\owlnight\upload.cmd"

if ($Repo -eq "") {
  $url = (git -C $root remote get-url origin).Trim()
  if ($url -match "github\.com[:/]([^/]+/[^/.]+)") { $Repo = $Matches[1] } else { throw "cannot read the GitHub repository from the origin URL: $url" }
}
if (-not (Test-Path $engine)) { throw "STORY.COM is not built: $engine (LAB\OWLFLY4\ENGINE\MAKEWIN.BAT)" }

# ---- what was UPLOADED last time: upload.cmd copies the manifest it worked
# from to uploaded.json when it finishes, and only hashes that differ from
# that are uploaded next time. No uploaded.json: everything goes.
$uploadedPath = Join-Path $root "docs\owlnight\uploaded.json"
$old = @{}
if (Test-Path $uploadedPath) {
  $prev = Get-Content $uploadedPath -Raw | ConvertFrom-Json
  if ($prev.tag -eq $Tag) { foreach ($f in $prev.files) { $old[$f.asset] = $f.sha256 } }
}

New-Item -ItemType Directory -Force $out | Out-Null
Get-ChildItem $out -File | Remove-Item -Force

$sha = [Security.Cryptography.SHA256]::Create()
function Hash($path) { $s = [IO.File]::OpenRead($path); try { ([BitConverter]::ToString($sha.ComputeHash($s)) -replace '-', '').ToLower() } finally { $s.Dispose() } }

$files = @()
function Add($abs, $into, $edition) {
  $asset = ($into -replace '^STORY/NIGHT/', '') -replace '/', '--'
  if ($into -eq "ENGINE/STORY.COM") { $asset = "STORY.COM" }
  Copy-Item $abs (Join-Path $out $asset) -Force
  # an object, not a hashtable: Group-Object and ConvertTo-Json read properties
  $script:files += [pscustomobject][ordered]@{
    into = $into; asset = $asset; bytes = (Get-Item $abs).Length; sha256 = (Hash $abs); edition = $edition
  }
}

Add $engine "ENGINE/STORY.COM" "shared"
$exts = '.INI', '.OWV', '.SPR', '.SLT', '.PCM'
foreach ($f in Get-ChildItem $story -Recurse -File | Where-Object { $exts -contains $_.Extension.ToUpper() -and $_.FullName -notmatch '\\frames\\' } | Sort-Object FullName) {
  $rel = $f.FullName.Substring($story.Length + 1) -replace '\\', '/'
  $edition = if ($rel -match '/320/') { "320" } elseif ($f.Extension -match '^\.(INI|PCM)$') { "shared" } else { "640" }
  Add $f.FullName "STORY/NIGHT/$rel" $edition
}

# a release asset name: letters, digits, dot, dash, underscore - nothing else survives
foreach ($f in $files) { if ($f.asset -notmatch '^[A-Za-z0-9._-]+$') { throw "asset name GitHub would rewrite: $($f.asset)" } }
$dup = $files | Group-Object asset | Where-Object { $_.Count -gt 1 }
if ($dup) { throw "two files map to one asset name: $($dup[0].Name)" }

$release = "https://github.com/$Repo/releases/download/$Tag/"
# $fetchBase, not $base: PowerShell variable names are case-insensitive, and $base = ... overwrote the parameter
$fetchBase = if ($Base -ne "") { $Base.TrimEnd('/') + "/" } else { $release }
$manifest = [ordered]@{
  game = "OWL NIGHT"; tag = $Tag; base = $fetchBase; made = (Get-Date).ToString("yyyy-MM-dd HH:mm")
  files = $files
}
[IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 4) -replace "`r?`n", "`n") + "`n", (New-Object Text.UTF8Encoding($false)))

# ---- the upload script: only what changed since the committed manifest ----
$changed = $files | Where-Object { $old[$_.asset] -ne $_.sha256 }
$lines = @(
  "@echo off",
  "REM upload.cmd - written by docs\pack-night.ps1. Uploads OWL NIGHT's assets to the",
  "REM GitHub release $Tag of $Repo. Needs the GitHub CLI signed in:",
  "REM     winget install GitHub.cli      then      gh auth login",
  "REM Only the $($changed.Count) file(s) whose hash changed since the last upload (uploaded.json)",
  "REM are sent (--clobber replaces them in place). Run it from anywhere.",
  "where gh >nul 2>nul || (echo gh is not installed: winget install GitHub.cli & exit /b 1)",
  "cd /d `"$out`"",
  "gh release view $Tag --repo $Repo >nul 2>nul || gh release create $Tag --repo $Repo --title `"OWL NIGHT $Tag`" --notes `"The story's clips, rooms and music, fetched by docs/owlvid.html. Made by docs/pack-night.ps1.`" || exit /b 1"
)
foreach ($f in $changed) { $lines += "gh release upload $Tag `"$($f.asset)`" --repo $Repo --clobber || exit /b 1" }
$lines += "copy /y `"$manifestPath`" `"$uploadedPath`" >nul"
$lines += "echo done: $($changed.Count) file(s) uploaded to $release"
if ($Base -ne "") { $lines += "echo the page fetches from $fetchBase - copy the same files there (the release is for people, the host is for the page)" }
[IO.File]::WriteAllText($uploadPath, (($lines -join "`r`n") + "`r`n"), [Text.Encoding]::ASCII)

$by = $files | Group-Object edition
Write-Host "staged $($files.Count) files in $out"
foreach ($g in $by) { Write-Host ("  {0,-7} {1,3} files {2,8:F1} MB" -f $g.Name, $g.Count, (($g.Group | Measure-Object bytes -Sum).Sum / 1MB)) }
Write-Host "manifest  $manifestPath  (commit this)"
Write-Host "upload    $uploadPath  ($($changed.Count) changed - run it, then commit the manifest and the page)"
Write-Host "test      serve docs\ and open owlvid.html?base=owlnight/release/"
if ($Base -eq "") {
  Write-Host ""
  Write-Host "WARNING   the manifest points at the GitHub release, and a browser cannot read"
  Write-Host "          release assets cross-origin (no Access-Control-Allow-Origin, measured"
  Write-Host "          2026-10-09). Run again with -Base https://<a host with CORS>/owlnight/$Tag/"
  Write-Host "          before the page goes live; the release is still right for downloads."
}
