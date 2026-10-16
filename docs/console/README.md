# docs/console - a copy, never edited here

The console's shared core - the shell's grammar (`shell.js`), its own
commands (`commands.js`: the shell's, files and paths, text in pipes) and the
terminal Ctrl+` drops (`terminal.js`) - belongs to **OWLOS LAN**
(`C:\repos\OWLOS-LAN\web\console\`): one server, several UIs, one console.

`../pull-console.ps1` copies it here; `VERSION.txt` says from which commit.
A change to the core is made in OWLOS-LAN, checked there by its
`tests\ShellRig`, and pulled. What only the site has - its paths over the
drive table (`/mnt/a`, `C:\GAMES`) and its commands (mount, df, play, run,
build, lesson...) - is `../site/console.js`.

The copy imports `../owlosui/owlosui.js`: in OWLOS-LAN that is its
`web/owlosui/`, here `docs/owlosui/` - the same place beside it.
