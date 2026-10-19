# COMMANDS - the site's console as an API: the command contract

Everything the WIRE CITY page does - its menus, its windows, a model
working in it - is a line of its console. So the console's commands are
the page's API: a model calls them through the console tool, and a page
of one's own is buttons that run lines and show what comes back. Each
command says what it does to the person's things - its effect - and what
it gives back as data. That is the contract.

## Reading it

- `help --json` - every command's contract, a list.
- `man NAME --json` - one; `man NAME` says it in words.
- `--json` on any command gives its rows as data instead of text: one row
  is an object, several a list (`who --json`, `df --json`,
  `build A:\MY\HELI\HELI.ASM --json`). `man NAME` names the shape.

A contract:

```
{ "name": "lesson", "group": "programs",
  "summary": "a lesson opened: its source, its build, its video ...",
  "usage": "lesson NUMBER [--reset]", "where": "here",
  "options": { "reset": "its files on A: as the course ships them ..." },
  "valued": [], "effect": "shows", "effects": { "reset": "deletes" },
  "bare": null, "data": "{ lesson, title, reset }", "model": "yes" }
```

- where - `here`: it runs in the page; `server`: it calls the server
  (`set -x` shows the call).
- options, valued - its options; a valued one takes a word after it
  (`--days 7` or `--days=7`).
- model - `never`: a model may not run it at all (`agent`: the keys are
  the person's to make and to take back).

## The seven effects

| effect  | what it means                                             | asks |
|---------|-----------------------------------------------------------|------|
| reads   | only looks: nothing changes anywhere                      | no   |
| shows   | changes what the page shows, or where the terminal is      | no   |
| runs    | starts something on the DOS PC - what ran before is gone   | no   |
| writes  | makes new files or new things                             | no   |
| deletes | takes away, or writes over, what was there                | YES  |
| setup   | changes the person's setup: drives, settings, names       | YES  |
| shares  | gives something to others, or sends it out of the page    | YES  |

"Asks" is what the page does when a model runs the line: the person sees
it in a Yes / No box first, with each such command's effect under it. A
No comes back as an error; try another way or ask in words.

A command's effect for the words it was given:

1. an option named in `effects` that is there wins
   (`history -c` deletes, `share --stop` only shows);
2. else `bare` when no word follows the name
   (`mount` alone lists the drives - reads; `mount E: GAMES` is setup);
3. else `effect`. A command that declares none counts as setup: not
   knowing what it does is a reason to ask.

A line of several commands - `;`, `&&`, `||`, `|` - is judged command by
command, aliases undone first; one that asks makes the line ask. A model
may not redirect (`>`, `>>`): it writes files with write_file, which asks
before it replaces a file the model did not write itself.

## The commands, by what they do

- reads: help, man, echo, pwd, ls, cat, grep, sort, head, tail, wc, who,
  map, df, du, history, profile; and alone: alias, export, mount, dosbox.
- shows: clear, set, exit, cd, watch, sky, manual, edit, commander,
  lesson, share --stop.
- runs: play, run, build, dos, poweroff.
- writes: mkdir, zip, profile --save.
- deletes: rm, mv, cp (a copy onto a file that is there writes over it),
  history -c, lesson --reset.
- setup: alias, unalias, export, unset, source, mount, relabel, umount,
  dosbox, profile --load.
- shares: share.
- never by a model: agent.

## Making things with it

- A game: `build A:\MY\GAME\GAME.ASM` (runs - no question), then the
  screen and the keys; files by write_file and edit_file, not cp.
  `zip A:\MY\GAME` gives the folder to the person (writes).
- Several players: `build ... --net` [MULTI].
- A page of one's own is a set of these lines behind buttons; what it
  shows is their `--json`. What asks a model asks there too.

## For whoever adds a command

It goes in the site's console.js (or, for every UI of the server, in
OWLOS-LAN's web/console/commands.js) with its effect and data declared:
`effect`, and `effects` / `bare` when an option or no words change it;
`data` the shape of its rows, each row given by ctx.data(...). Choose the
effect by the worst it can do - a copy that may write over a file
deletes. A command added without one counts as setup and asks every
time.
