# pull-console.ps1 [-From C:\repos\OWLOS-LAN] - copy the console's shared core
# into docs\console\, for the site (docs\site\).
#
# The console - the shell's grammar, its own commands (the shell's, files,
# text in pipes) and the terminal dropped by Ctrl+` - is OWLOS LAN's: every
# UI of the one OWLOS LAN server has it (the pilot, 2026-10-16: one server,
# several UIs). It lives in OWLOS-LAN\web\console\; this repository takes a
# copy when we choose to, and says in docs\console\VERSION.txt which commit
# it came from. The site adds its own commands and paths (docs\site\console.js);
# it never edits the copy - a change to the core is made in OWLOS-LAN, tried
# there (tests\ShellRig), and pulled.
#
# The copy imports ../owlosui/owlosui.js: in OWLOS-LAN that is web\owlosui\,
# here docs\owlosui\ - the same place beside it, so nothing is rewritten.
# docs\console\README.md is ours and stays.
param([string]$From = "C:\repos\OWLOS-LAN")

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $From "web\console"
$to   = Join-Path $root "docs\console"

if (-not (Test-Path (Join-Path $src "shell.js"))) { throw "No console core at $src (looked for shell.js)." }

$commit = (& git -C $From rev-parse HEAD).Trim()
$dirty  = & git -C $From status --porcelain -- web/console
$state  = if ($dirty) { "plus changes not yet committed in web\console\ (" + @($dirty).Count + " entries)" } else { "clean" }

New-Item -ItemType Directory -Force $to | Out-Null
# What the copy had and the core no longer has goes; README.md is ours.
Get-ChildItem $to -File -Filter *.js | Remove-Item
$files = Get-ChildItem $src -File -Filter *.js
foreach ($f in $files) { Copy-Item $f.FullName (Join-Path $to $f.Name) }

$version = @"
The console's shared core, copied from OWLOS-LAN\web\console\
commit $commit - $state
copied $(Get-Date -Format "yyyy-MM-dd HH:mm") by docs\pull-console.ps1
files: $(($files | ForEach-Object Name) -join ', ')
"@
[IO.File]::WriteAllText((Join-Path $to "VERSION.txt"), $version.Replace("`n", "`r`n"))
"Console core: $($files.Count) files from $From ($state) -> docs\console\"
