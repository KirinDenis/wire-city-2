# pack-course.ps1 [-Playlist <tsv>] - the course page's disk and lesson list, into docs\.
#
# The course page (docs\course\) gives the student a DOS PC whose drive A:
# holds the course AS THE REPOSITORY HOLDS IT - the same folders, the same
# sources, the same MAKE.BAT and RUN.BAT - so every lesson, example and game
# is there to read, change and build from the commander, exactly as it was
# built. GitHub Pages serves docs\ alone, so this script puts it there:
#
#   docs\course\disk.zip     the course disk, unpacked once onto A: by the page:
#       TOOLS\FASM\          FASM.EXE and its licence
#       TOOLS\CWSDPMI\       CWSDPMI.EXE and its notice
#       TOOLS\COMMANDR\      the DOS commander the DOS PC starts into (ours: a
#                            copy of an OWLOSUI example - see its README)
#       ENGINE\              every *.INC
#       LESSONS\Lnn\         sources, includes, batch files, notes
#       EXAMPLES\            the teaching machines: sources, batch files, notes
#       GAMES\OWLFLY\, OWLFLY2\, OWLFLY3\
#                            SRC\ and INSTALL\ (the data the build does not
#                            make, and the game as built), MAKE.BAT, RUN.BAT...
#   docs\course\course.json  every lesson, its title and notes (its .INF), its
#                            main source, its video - and the disk's version
#
# Left out: the Windows-only batch files (*WIN.BAT, PUBLISH.BAT, CONVERT.BAT
# - they drive C# tools, not DOS), build logs, pictures, and the games'
# res\ folders (20 MB of artwork CONVERT.BAT turns into INSTALL\ - which IS
# on the disk).
#
# ONE CHANGE TO THE COPIES, and only to the copies: every line that runs
# FASM.EXE on a source gets `-m 4096`. In the page's DOS PC FASM without it
# grabs CWSDPMI's virtual memory and the emulator dies (measured; see
# docs\course\README.md). The repository's batch files are not touched.
#
# A video row whose folder carries a letter - L05B - is a second lecture on
# the same folder: its program is that folder's SECOND .build line (L05:
# TURN.ASM is lecture 5, PIVOT.ASM is lecture 5B).
param([string]$Playlist = "C:\DOSFiles\lecture-rig\youtube\playlist.tsv")

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path -Parent $PSScriptRoot
$course = Join-Path $root "docs\course"

# ---- the videos: folder -> { id, length, title } --------------------------
if (-not (Test-Path $Playlist)) { throw "No playlist at $Playlist - pass -Playlist." }
$videos = [ordered]@{}
foreach ($l in Get-Content $Playlist) {
  if ($l -match '^#' -or -not $l.Trim()) { continue }
  $p = $l -split "`t"
  if ($p[0] -ne '-') { $videos[$p[0]] = @{ id = $p[1]; length = $p[2]; title = $p[3] } }
}

# ---- the disk: which files of which folders ------------------------------
$TEXT = '\.(ASM|INC|BAT|INF|TXT|MD|C|H|PAS|CONF)$'
$NOT  = '(WIN\.BAT|^PUBLISH\.BAT|^CONVERT\.BAT|^MAKEINFO\.BAT|\.LOG$|^stdout\.txt$|^stderr\.txt$|^YOUTUBE\.txt$)'
function Pick([string]$dir, [string]$pattern, [switch]$recurse) {
  Get-ChildItem -File -Recurse:$recurse (Join-Path $root $dir) |
    Where-Object { $_.Name -match $pattern -and $_.Name -notmatch $NOT }
}
$picked = @()
$picked += Get-Item (Join-Path $root "TOOLS\FASM\FASM.EXE"), (Join-Path $root "TOOLS\FASM\LICENSE.TXT"),
                    (Join-Path $root "TOOLS\CWSDPMI\CWSDPMI.EXE"), (Join-Path $root "TOOLS\CWSDPMI\cwsdpmi.doc"),
                    (Join-Path $root "TOOLS\COMMANDR\COMMANDR.EXE"), (Join-Path $root "TOOLS\COMMANDR\COMMANDR.PAS"),
                    (Join-Path $root "TOOLS\COMMANDR\README.md")
$picked += Pick "ENGINE" '\.INC$'
foreach ($d in Get-ChildItem (Join-Path $root "LESSONS") -Directory | Where-Object { $_.Name -match '^L\d\d$' }) {
  $picked += Pick "LESSONS\$($d.Name)" $TEXT          # the lesson's own folder, not its WEB\ copies
  # ...and its notebook, when the notebook carries its own BGI driver (lesson
  # 18 on). The older ones load EGAVGA.BGI from D:\BGI, which the course disk
  # does not have, so shipping them would only ship an error message.
  $deck = Join-Path $d.FullName "INFOGR.PAS"
  if ((Test-Path $deck) -and (Select-String -Path $deck -Pattern 'RegisterBGIdriver' -Quiet) -and
      (Test-Path (Join-Path $d.FullName "INFOGR.EXE"))) {
    $picked += Get-Item (Join-Path $d.FullName "INFOGR.EXE")
  }
}
$picked += Pick "EXAMPLES" $TEXT
foreach ($g in "OWLFLY", "OWLFLY2", "OWLFLY3") {
  $picked += Pick "GAMES\$g" $TEXT
  $picked += Pick "GAMES\$g\SRC" '.' -recurse | Where-Object { $_.Extension -notmatch '^\.(LST|MAP|LOG)$' }
  $picked += Pick "GAMES\$g\INSTALL" '.' -recurse
}

# FASM gets -m 4096 on the disk's copies: a line that runs it ON something,
# not the "if not exist ...FASM.EXE goto" checks.
function Patch([string]$text) {
  [regex]::Replace($text, '(?im)^(\s*\S*FASM\.EXE)\s+(?!-m\b)(?=\S)', '$1 -m 4096 ')
}

$zipPath = Join-Path $course "disk.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath }
$zip = [IO.Compression.ZipFile]::Open($zipPath, 'Create')
$patched = 0; $bytes = 0
try {
  foreach ($f in $picked) {
    $rel = $f.FullName.Substring($root.Length + 1).Replace('\', '/')    # forward slashes: a zip's own
    $data = [IO.File]::ReadAllBytes($f.FullName)
    if ($f.Extension -eq '.BAT' -or $f.Extension -eq '.bat') {
      $text = [Text.Encoding]::GetEncoding(437).GetString($data)
      $new = Patch $text
      if ($new -ne $text) { $data = [Text.Encoding]::GetEncoding(437).GetBytes($new); $patched++ }
    }
    $e = $zip.CreateEntry($rel, 'Optimal')
    $e.LastWriteTime = $f.LastWriteTime
    $s = $e.Open(); $s.Write($data, 0, $data.Length); $s.Close()
    $bytes += $data.Length
  }
} finally { $zip.Dispose() }
$hash = (Get-FileHash $zipPath -Algorithm SHA256).Hash.Substring(0, 12)

# ---- the lessons: every folder, and every lettered lecture on one --------
$ids = @(Get-ChildItem (Join-Path $root "LESSONS") -Directory | Where-Object { $_.Name -match '^L\d\d$' } | ForEach-Object Name)
$ids += @($videos.Keys | Where-Object { $_ -match '^L\d\d[A-Z]$' })
$ids = $ids | Sort-Object
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
  $buildable = [bool]($main -and $build -like 'FASM*')
  $size = if ($main -and (Test-Path (Join-Path $dir $main))) { (Get-Item (Join-Path $dir $main)).Length } else { 0 }
  $lessons += [ordered]@{
    id = $id; folder = $folder; lecture = $lecture; title = $title; about = $what
    main = $main; buildable = $buildable; size = $size
    video = if ($v) { $v.id } else { $null }; length = if ($v) { $v.length } else { $null }
  }
}

$json = [ordered]@{
  playlist = 'PLYAv8-EdgIF8'
  disk = [ordered]@{ url = 'disk.zip'; version = $hash; files = $picked.Count; bytes = $bytes }
  lessons = $lessons
} | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $course "course.json"), $json)
$old = Join-Path $course "files"
if (Test-Path $old) { Remove-Item -Recurse -Force $old }      # the per-file copies this replaced
"$($lessons.Count) lessons; disk.zip ${hash}: $($picked.Count) files, $bytes bytes ($((Get-Item $zipPath).Length) packed), FASM -m 4096 in $patched batch files"
