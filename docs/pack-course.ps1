# pack-course.ps1 [-Playlist <tsv>] - put the course page's lessons into docs\.
#
# The course page (docs\course\) opens a lesson by writing its files onto
# the DOS PC's floppies, and it fetches them over the web. GitHub Pages
# serves docs\ alone, so what it fetches must be IN docs\: this script copies
#
#   LESSONS\Lnn\<main source and what it includes>  -> docs\course\files\LESSONS\Lnn\
#   ENGINE\*.INC                                      -> docs\course\files\ENGINE\
#   TOOLS\FASM\FASM.EXE, LICENSE.TXT                  -> docs\course\files\TOOLS\FASM\
#   TOOLS\CWSDPMI\CWSDPMI.EXE, cwsdpmi.doc            -> docs\course\files\TOOLS\CWSDPMI\
#
# and writes docs\course\course.json: every lesson, its title and notes (its
# .INF), its main source, and its video (the YouTube playlist table kept by
# the lecture rig). Run it after a lesson's source changes; the copy is never
# edited by hand.
#
# A video row whose folder carries a letter - L05B - is a second lecture on
# the same folder: its program is that folder's SECOND .build line (L05:
# TURN.ASM is lecture 5, PIVOT.ASM is lecture 5B).
param([string]$Playlist = "C:\DOSFiles\lecture-rig\youtube\playlist.tsv")

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$out  = Join-Path $root "docs\course\files"

# ---- the videos: folder -> { id, length, title } --------------------------
if (-not (Test-Path $Playlist)) { throw "No playlist at $Playlist - pass -Playlist." }
$videos = [ordered]@{}
foreach ($l in Get-Content $Playlist) {
  if ($l -match '^#' -or -not $l.Trim()) { continue }
  $p = $l -split "`t"
  if ($p[0] -ne '-') { $videos[$p[0]] = @{ id = $p[1]; length = $p[2]; title = $p[3] } }
}

# ---- the lessons: every folder, and every lettered lecture on one --------
$ids = @(Get-ChildItem (Join-Path $root "LESSONS") -Directory | Where-Object { $_.Name -match '^L\d\d$' } | ForEach-Object Name)
$ids += @($videos.Keys | Where-Object { $_ -match '^L\d\d[A-Z]$' })
$ids = $ids | Sort-Object

if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $out | Out-Null

function Copy-Into([string]$from, [string]$to) {
  New-Item -ItemType Directory -Force (Split-Path -Parent $to) | Out-Null
  Copy-Item $from $to
}

$lessons = @()
foreach ($id in $ids) {
  $folder = $id.Substring(0, 3)
  $dir = Join-Path $root "LESSONS\$folder"
  $inf = Join-Path $dir "$folder.INF"
  $v = $videos[$id]
  $title = $null; $what = ''; $main = $null; $builds = @()
  if (Test-Path $inf) {
    foreach ($l in Get-Content $inf) {
      if ($l -match '^\.title\s+(.*)') { $title = $Matches[1].Trim() }
      if ($l -match '^\.what\s+(.*)')  { $what  = $Matches[1].Trim() }
      if ($l -match '^\.main\s+(.*)')  { $main  = $Matches[1].Trim() }
      if ($l -match '^\.build\s+(.*)') { $builds += $Matches[1].Trim() }
    }
  }
  # A lettered lecture: the folder's second program, and the video's title.
  $build = $builds | Select-Object -First 1
  if ($id.Length -gt 3) {
    $build = $builds | Select-Object -Skip 1 -First 1
    $main = if ($build) { ($build -split '\s+')[1] } else { $null }
    $title = $null; $what = ''
  }
  if (-not $title -and $v) { $title = $v.title -replace '^(Owl Fly II - )?Lecture [0-9A-F]+B?:\s*', '' }
  $lecture = if ($v -and $v.title -match 'Lecture ([0-9A-F]+B?)') { $Matches[1] } else { '' }

  # The files: the main source and everything it includes, followed down;
  # ENGINE includes go to ENGINE\ once, for every lesson that has them.
  $files = @(); $engine = $false; $buildable = $false
  if ($main -and $build -like 'FASM*') {
    $buildable = $true
    $todo = [System.Collections.Generic.Queue[string]]::new()
    $todo.Enqueue($main)
    while ($todo.Count) {
      $f = $todo.Dequeue()
      if ($files -contains $f) { continue }
      $files += $f
      Copy-Into (Join-Path $dir $f) (Join-Path $out "LESSONS\$folder\$f")
      $src = [IO.File]::ReadAllText((Join-Path $dir $f))
      foreach ($m in [regex]::Matches($src, "(?im)^\s*include\s+'([^']+)'")) {
        $inc = $m.Groups[1].Value
        if ($inc -like '..\..\ENGINE\*') { $engine = $true } else { $todo.Enqueue($inc) }
      }
    }
  }
  $size = if ($main -and (Test-Path (Join-Path $dir $main))) { (Get-Item (Join-Path $dir $main)).Length } else { 0 }
  $lessons += [ordered]@{
    id = $id; folder = $folder; lecture = $lecture; title = $title; about = $what
    main = $main; files = $files; engine = $engine; buildable = $buildable; size = $size
    video = if ($v) { $v.id } else { $null }; length = if ($v) { $v.length } else { $null }
  }
}

foreach ($f in Get-ChildItem (Join-Path $root "ENGINE") -Filter *.INC) { Copy-Into $f.FullName (Join-Path $out "ENGINE\$($f.Name)") }
foreach ($f in "FASM\FASM.EXE", "FASM\LICENSE.TXT", "CWSDPMI\CWSDPMI.EXE", "CWSDPMI\cwsdpmi.doc") {
  Copy-Into (Join-Path $root "TOOLS\$f") (Join-Path $out "TOOLS\$f")
}

$json = [ordered]@{ playlist = 'PLYAv8-EdgIF8'; lessons = $lessons } | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $root "docs\course\course.json"), $json)
$n = (Get-ChildItem -Recurse -File $out | Measure-Object Length -Sum)
"$($lessons.Count) lessons, $($n.Count) files, $($n.Sum) bytes in docs\course\files"
