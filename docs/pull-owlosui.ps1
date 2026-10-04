# pull-owlosui.ps1 [-From C:\repos\OWLOSUI] - copy OWLOSUI's web library
# into docs\owlosui\, for the course page (docs\course\).
#
# OWLOSUI is its own project, in its own repository:
#   https://github.com/KirinDenis/OWLOSUI
# This repository does not follow it live. It takes a copy of the library -
# lib\js only, never the examples - when we choose to, and says in
# docs\owlosui\VERSION.txt which commit the copy came from. The course page
# imports only that copy, so it keeps working whatever OWLOSUI is doing
# today, and GitHub Pages, which serves docs\ alone, has everything it needs.
#
# What is copied, unchanged: owlosui.js, owlosui-wire.wasm (the Rust core,
# built by lib\js\build.cmd - it is not in OWLOSUI's git), dosbox\, files\,
# jsdos\, apps\ (the web commander, documents, DOS PC, console, log), three
# files of lib\dos for the DOS PC's C: (into dos\), and OWLOSUI's LICENSE.
# Never anything of OWLOSUI's Examples: what the course takes from them is
# its own copy (TOOLS\COMMANDR, the DOS commander).
# docs\owlosui\README.md is ours and stays.
param([string]$From = "C:\repos\OWLOSUI")

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$lib  = Join-Path $From "lib\js"
$to   = Join-Path $root "docs\owlosui"

if (-not (Test-Path (Join-Path $lib "owlosui.js"))) { throw "No OWLOSUI at $From (looked for lib\js\owlosui.js)." }

# The core is built, not tracked: a wasm older than the Rust it is built
# from would ship yesterday's core beside today's owlosui.js.
$wasm = Get-Item (Join-Path $lib "owlosui-wire.wasm")
$rust = Get-ChildItem -Recurse -Include *.rs, Cargo.toml (Join-Path $From "lib\core"), (Join-Path $From "lib\serve"), (Join-Path $lib "wire") |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($rust.LastWriteTime -gt $wasm.LastWriteTime) {
  throw "owlosui-wire.wasm ($($wasm.LastWriteTime)) is older than $($rust.FullName) ($($rust.LastWriteTime)). Run lib\js\build.cmd in OWLOSUI first."
}

# Which OWLOSUI this is: the commit, and whether lib\ had changes not yet committed.
$commit = (& git -C $From rev-parse HEAD).Trim()
$dirty  = & git -C $From status --porcelain -- lib
$state  = if ($dirty) { "plus changes not yet committed in lib\ (" + @($dirty).Count + " files)" } else { "clean" }

# Everything but our README goes; then the library, as it is.
New-Item -ItemType Directory -Force $to | Out-Null
Get-ChildItem $to | Where-Object { $_.Name -ne "README.md" } | Remove-Item -Recurse -Force
foreach ($f in "owlosui.js", "owlosui-wire.wasm") { Copy-Item (Join-Path $lib $f) $to }
foreach ($d in "dosbox", "files", "jsdos", "apps") { Copy-Item -Recurse (Join-Path $lib $d) (Join-Path $to $d) }
# The DOS PC's drive C: (apps\dos.js, BASE_DISK): the toolkit resident and
# its DPMI host - from lib\dos, into dos\, which the page passes to DosTool as
# `dosFiles`. NOT the DOS commander: that is an OWLOSUI example, and the
# course keeps its own copy (TOOLS\COMMANDR).
foreach ($f in "CWSDPMI.EXE", "OWLOSRES.COM", "OWLOSRES.BIN") {
  $dst = Join-Path $to "dos\$f"
  New-Item -ItemType Directory -Force (Split-Path -Parent $dst) | Out-Null
  Copy-Item (Join-Path $From "lib\dos\$f") $dst
}
Copy-Item (Join-Path $From "LICENSE") (Join-Path $to "LICENSE.txt")

$files = Get-ChildItem -Recurse -File $to | Where-Object { $_.Name -notin "README.md", "VERSION.txt" }
$bytes = ($files | Measure-Object Length -Sum).Sum
$version = @(
  "OWLOSUI web library, copied from $From",
  "repository  https://github.com/KirinDenis/OWLOSUI",
  "commit      $commit",
  "state       $state",
  "copied      $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
  "wasm built  $($wasm.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))",
  "files       $($files.Count), $bytes bytes",
  "",
  "Refresh with docs\pull-owlosui.ps1. Do not edit these files here: change",
  "OWLOSUI, then pull again."
)
[IO.File]::WriteAllLines((Join-Path $to "VERSION.txt"), $version)
$version | Select-Object -First 7
