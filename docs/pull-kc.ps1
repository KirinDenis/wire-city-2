# pull-kc.ps1 [-From C:\repos\KIRIN-COMMANDER] - copy Kirin Commander for
# DOS into TOOLS\KC\, for the course disk (pack-course.ps1 packs it).
#
# Kirin Commander is its own project, in its own repository. This
# repository does not follow it live: it takes the built commander when we
# choose to, and says in TOOLS\KC\VERSION.TXT which commit it came from -
# as docs\pull-owlosui.ps1 does for OWLOSUI.
#
# What is copied, unchanged: KC.COM (the loader) and KC.BIN (the commander)
# from dos\, as dos\build.cmd left them, and the licence. TOOLS\KC\README.md
# is ours and stays. Build first, in the commander's repository:
#     dos\build.cmd
param([string]$From = "C:\repos\KIRIN-COMMANDER")

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dos  = Join-Path $From "dos"
$to   = Join-Path $root "TOOLS\KC"

foreach ($f in "KC.COM", "KC.BIN") {
  if (-not (Test-Path (Join-Path $dos $f))) { throw "No $f in $dos - run dos\build.cmd there first." }
}

# A KC.BIN older than the Rust it is built from would ship yesterday's
# commander.
$bin  = Get-Item (Join-Path $dos "KC.BIN")
$rust = Get-ChildItem -Recurse -Include *.rs, Cargo.toml (Join-Path $From "kc\src"), (Join-Path $From "dos\src") |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($rust.LastWriteTime -gt $bin.LastWriteTime) {
  throw "KC.BIN ($($bin.LastWriteTime)) is older than $($rust.FullName) ($($rust.LastWriteTime)). Run dos\build.cmd in $From first."
}

# Which commander this is: the commit, if there is one yet, and whether
# kc\ and dos\ had changes not yet committed.
$commit = (& git -C $From rev-parse --verify --quiet HEAD 2>$null)
$commit = if ($commit) { $commit.Trim() } else { "none yet" }
$dirty  = & git -C $From status --porcelain -- kc dos 2>$null
$state  = if ($dirty) { "plus changes not yet committed in kc\ and dos\ (" + @($dirty).Count + " entries)" } else { "clean" }

New-Item -ItemType Directory -Force $to | Out-Null
Get-ChildItem $to | Where-Object { $_.Name -ne "README.md" } | Remove-Item -Force
Copy-Item (Join-Path $dos "KC.COM"), (Join-Path $dos "KC.BIN") $to
# The licence as DOS shows it: CRLF, an 8.3 name.
$lic = [IO.File]::ReadAllText((Join-Path $From "LICENSE")) -replace "`r?`n", "`r`n"
[IO.File]::WriteAllText((Join-Path $to "LICENSE.TXT"), $lic)

$version = @(
  "Kirin Commander for DOS, copied from $From",
  "commit      $commit",
  "state       $state",
  "copied      $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
  "KC.BIN      $($bin.Length) bytes, built $($bin.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))",
  "",
  "Refresh with docs\pull-kc.ps1. Do not edit these files here: change the",
  "commander, build it, then pull again."
)
[IO.File]::WriteAllText((Join-Path $to "VERSION.TXT"), ($version -join "`r`n") + "`r`n")
$version | Select-Object -First 5
