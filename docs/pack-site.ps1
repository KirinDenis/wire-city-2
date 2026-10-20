# pack-site.ps1 [-Repo] - drive C: of the new site's DOS machine, into docs\site\.
#
# The site (docs\site\) gives the visitor one DOS machine whose drive C:
# holds the games as REAL FILES - C:\GAMES\OWLFLY3\OWLFLY3.EXE and the data
# beside it, each a file of its own on the site - not a bundle that boots
# one game. GitHub Pages serves docs\ alone, so this script puts them there:
#
#   docs\site\C\GAMES\<DIR>\   each game's files as DOS sees them, and a
#                              RUN.BAT: cd GAMES\<DIR>, RUN - as in the repo
#   docs\site\drive-c.json     the list of files the page puts C: together by
#   docs\site\sources.json     the Sources menu: each game's and example's
#                              title, words and main source, from its .INF -
#                              the sources are on A:, the course disk
#
# By default the files are the RELEASED ones - what each game's own page
# plays now, taken out of the .jsdos bundle that page names (docs\pack.ps1
# gives every release a new name). -Repo takes the repository's builds
# instead (GAMES\<DIR>\INSTALL\, or the game's folder): on 2026-10-16
# OWLFLY3.EXE, FLYOWL.COM and FIELD.COM there were newer than the released
# ones, and OWL FLY III's INSTALL\ held files its release does not. A game
# with no page of its own (MULTIPLAY SOKO) always comes from the repository.
#
# docs\site\C\ is made again from nothing on every run.
param([switch]$Repo)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$docs = $PSScriptRoot
$root = Split-Path $docs -Parent
$out = Join-Path $docs "site\C"

# The games, in the order of the site's Games menu. page/bundle: where the
# released files are; repo: the repository's build; exe: what RUN.BAT runs.
$games = @(
  @{ dir = "OWLFLY3";  name = "OWL FLY III";       page = "owlfly3.html"; bundle = "owlfly3_v\d+\.jsdos";  repo = "GAMES\OWLFLY3\INSTALL"; exe = "OWLFLY3.EXE" },
  @{ dir = "OWLFLY2";  name = "OWL FLY II";        page = "owlfly2.html"; bundle = "owlfly2_v\d+\.jsdos";  repo = "GAMES\OWLFLY2\INSTALL"; exe = "FLYOWL2.EXE" },
  @{ dir = "OWLFLY";   name = "OWL FLY";           page = "owlfly.html";  bundle = "owlfly_v\d+\.jsdos";   repo = "GAMES\OWLFLY\INSTALL";  exe = "FLYOWL.COM" },
  @{ dir = "TRAINER";  name = "The Flight School"; page = "play.html";    bundle = "field_v\d+\.jsdos";    repo = "GAMES\TRAINER";         exe = "FIELD.COM" },
  @{ dir = "WIRECITY"; name = "WIRE CITY";         page = "play.html";    bundle = "wirecity_v\d+\.jsdos"; repo = "GAMES\WIRECITY";        exe = "CITY.COM" },
  # No page and no bundle of its own: always the repository's build.
  @{ dir = "MULTSOKO"; name = "MULTIPLAY SOKO";                                                         repo = "GAMES\MULTSOKO";        exe = "MULTSOKO.COM" }
)

# What of a game's folder in the repository is the game: the program and
# its data, not its sources, notes or batch files.
$shipped = @("*.COM", "*.EXE", "*.DAT", "*.RAW")

if (Test-Path $out) { Remove-Item $out -Recurse -Force }
$files = New-Object System.Collections.ArrayList
$from = [ordered]@{}

function Put([string]$rel, [byte[]]$bytes) {
  $path = Join-Path $out $rel.Replace('/', '\')
  New-Item -ItemType Directory -Force (Split-Path $path -Parent) | Out-Null
  [IO.File]::WriteAllBytes($path, $bytes)
  [void]$files.Add([ordered]@{ path = $rel; size = $bytes.Length })
}

foreach ($g in $games) {
  $dir = "GAMES/$($g.dir)"
  if ($Repo -or -not $g.page) {
    $src = Join-Path $root $g.repo
    $taken = Get-ChildItem -Path "$src\*" -File -Include $shipped | Sort-Object Name
    foreach ($f in $taken) { Put "$dir/$($f.Name.ToUpper())" ([IO.File]::ReadAllBytes($f.FullName)) }
    $from[$g.dir] = $g.repo
  } else {
    $page = Get-Content (Join-Path $docs $g.page) -Raw
    $m = [regex]::Match($page, $g.bundle)
    if (-not $m.Success) { throw "$($g.page) names no bundle like $($g.bundle)" }
    $zip = [IO.Compression.ZipFile]::OpenRead((Join-Path $docs $m.Value))
    try {
      foreach ($e in $zip.Entries) {
        $n = $e.FullName
        if ($n.EndsWith('/') -or $n.StartsWith('.jsdos/') -or $n -ieq 'dosbox.conf') { continue }
        $s = $e.Open(); $ms = New-Object IO.MemoryStream; $s.CopyTo($ms); $s.Close()
        Put "$dir/$($n.ToUpper())" $ms.ToArray()
      }
    } finally { $zip.Dispose() }
    $from[$g.dir] = $m.Value
  }
  # cd GAMES\<DIR>, RUN - the way the repository runs every game.
  $bat = "@echo off`r`nREM RUN.BAT - $($g.name). From C:\: cd GAMES\$($g.dir), then RUN.`r`n$($g.exe)`r`n"
  Put "$dir/RUN.BAT" ([Text.Encoding]::ASCII.GetBytes($bat))
}

$list = [ordered]@{
  made = (Get-Date).ToString("yyyy-MM-dd HH:mm")
  source = $(if ($Repo) { "repository" } else { "released" })
  from = $from
  files = $files
}
$json = $list | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $docs "site\drive-c.json"), $json, (New-Object Text.UTF8Encoding $false))

# ---- the Sources menu: every program whose source is on the course disk ----
# Read from the .INF beside each one (.title, .what, .main), as pack-course
# reads the lessons'. The sources themselves are on drive A:, the course disk.
function Inf([string]$path) {
  $o = [ordered]@{}
  foreach ($l in Get-Content $path) { if ($l -match '^\.(\w+)\s+(.*)$') { $o[$Matches[1]] = $Matches[2].Trim() } }
  $o
}
$sources = [ordered]@{ games = @(); examples = @() }
foreach ($g in $games) {
  $i = Inf (Join-Path $root "GAMES\$($g.dir)\$($g.dir).INF")
  $sources.games += [ordered]@{ dir = $g.dir; title = $i.title; what = $i.what; main = "GAMES/$($g.dir)/$($i.main.Replace('\', '/'))" }
}
foreach ($f in Get-ChildItem (Join-Path $root "EXAMPLES") -Filter *.INF | Sort-Object Name) {
  $i = Inf $f.FullName
  $sources.examples += [ordered]@{ title = $i.title; what = $i.what; main = "EXAMPLES/$($i.main)" }
}
[IO.File]::WriteAllText((Join-Path $docs "site\sources.json"), ($sources | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding $false))
"Sources: $($sources.games.Count) games, $($sources.examples.Count) examples (site\sources.json)"

$bytes = ($files | ForEach-Object { $_.size } | Measure-Object -Sum).Sum
"Drive C: $($files.Count) files, $([math]::Round($bytes / 1KB)) KB, $($list.source):"
foreach ($k in $from.Keys) { "  GAMES\$k <- $($from[$k])" }
