# PAGES - a page of one's own: the site as a person wants it

The WIRE CITY page holds everything: games, sources, lessons, the
network, the AI. A person can have a page of their own, in two kinds:

- an INI desktop (D:\PAGES\NAME.INI) - the site's own look, with only the
  menus, keys and windows they want: "only games with my AI", "only
  writing and building code". A few lines; the cheapest to write.
- an HTML page (D:\PAGES\NAME.HTM) - the whole look their own: HTML and
  CSS, Bootstrap or anything else, the DOS PC in a slot of it, buttons
  and lists of their own design. More to write; any look.

A model makes either with write_file; the person puts it on. There is no
code of the page's in either. Every menu item, key and button is a line
of the console, and the command contract says what each does [COMMANDS]:
what deletes, changes the setup or gives something out asks the person
each time it is clicked; what a model may never run, a page never runs.

## An INI desktop

```
; D:\PAGES\GAMES.INI
[PAGE]
Name=Games with my AI
Open=chat left, dos right

[MENU ~G~ame]
~B~uild and run=build A:\MY\GAME\GAME.ASM
~R~un again=run A:\MY\GAME\GAME.COM
-
~Z~ip it to downloads=zip A:\MY\GAME

[MENU ~A~I]
~C~hat=window chat left
~T~asks=window tasks

[KEYS]
F9 Build=build A:\MY\GAME\GAME.ASM
Ctrl+F9 Run=run A:\MY\GAME\GAME.COM
```

- [PAGE] - `Name`, and `Open`: the windows it opens, in order, each with
  a place. Opening runs no command: only windows.
- [MENU title] - a menu on the bar, in the file's order; `~X~` marks the
  letter that opens it. Each line `Label=console line`; a line `-` is a
  separator. The hint under an item says its line and its effect.
- [KEYS] - `F9 Label=line`; F1..F12, Ctrl+F.., Alt+F..; on the status
  line. F2 (save), F5 (zoom), F10 (the menu), Alt+F3 (close) and Alt+X
  stay the site's.
- `;` starts a comment. At most 16 KB, 8 menus, 30 items a menu, 12 keys,
  a label 40 letters, a line 300.

`window NAME [PLACE]` opens a window - in a menu, or typed: dos (switched
on if off), chat, agents, tasks, calls (every call a model made),
terminal, who, drives, catalog, pages (the Pages window), lessons,
commander. Places: left, right, top, bottom, full - halves of the screen
under the menu bar. A running DOS PC keeps its window (a new one would
switch it off and on); it takes the place the next time it opens.
lessons and commander open where they always do.

## An HTML page

```
<!doctype html>
<html><head>
<title>My game studio</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
<style> .dos { aspect-ratio: 4 / 3; background: #000; } </style>
</head><body>
<div class="container py-4"><div class="row g-4">
  <div class="col-lg-8"><div class="dos" data-part="dos"></div></div>
  <div class="col-lg-4 d-grid gap-2">
    <button class="btn btn-primary" data-run="build A:\MY\GAME\GAME.ASM">Build and run</button>
    <button class="btn btn-outline-secondary" data-run="zip A:\MY\GAME">Zip it</button>
    <ul class="list-group" data-list="ls A:\MY\GAME">
      <li class="list-group-item" data-field="name"></li>
    </ul>
  </div>
</div></div>
</body></html>
```

- `data-run="LINE"` on any element - a button, a link, a card: a click
  runs the line. In a list's row, `{field}` puts the row's field in -
  only a plain name (letters, digits, `_ . - ~ ( ) ^ @`), else refused.
- `data-list="LINE"` - a command that only READS: its first child is the
  row, repeated once a row of the command's data; `data-field="name"` in
  it shows a field. `man NAME` says each command's fields (its --json).
  Filled again after every button, and every N seconds with
  `data-every="N"` (2 at the least). Worth knowing: `ls FOLDER` (name,
  info), `who` (name, doing, sharing), `net` (server, state, relay,
  relayState, sent, received, packetsIn, packetsOut...), `net --packets`
  (at, dir, size, from, to), `machine` (running, program, cycles,
  machine, network), `df` (letter, kind, files, bytes), `page`,
  `window`, `info --list`.
- `data-text="LINE"` - an element shows a reading command's words; with
  `data-every` too - `<pre data-text="net" data-every="2">` is a monitor.
- `data-part="dos"` - the DOS PC, switched on, its picture over this
  element (give it 4:3); a click on it gives it the keyboard, Right Ctrl
  takes it back.
- `data-part="map" data-room="owlfly3"` - the live map of a game's sky
  (owlfly3 or owlfly2): every jet where it is; the wheel zooms, a drag
  moves it, a click on a jet that shares its screen watches it.
- chat and terminal parts come later; until then a button
  `data-run="window chat"` opens the site's chat (the page steps aside).
- `page --parts` in the console lists all of this with an example of
  each - the place to start; `page --example studio` writes a page that
  uses every part.
- The `<title>` is the page's name. Only the `<body>` is used.
- Stylesheets: Bootstrap 5.3.3 and Bootstrap Icons 1.11.3 from
  cdn.jsdelivr.net, exactly those addresses (each checked by its hash).
  Anything else is the page's own `<style>`.
- Taken out, never run, and said by the check: `<script>`, on...=
  handlers, `javascript:` links, frames, forms and inputs, `<svg>`,
  pictures but `data:` ones, url() in CSS but a `data:` picture,
  @import, CSS escapes. A link is https: only; it opens in a tab of its
  own after the person sees where it goes.
- CSS may not name the site's own elements (`wc-...`, `#screen`); a page
  that hides or covers the WIRE CITY button is taken off at once.
- At most 64 KB. A policy goes on with the page: nothing it shows can
  reach another address.

A button that opens a window of the whole site (edit, commander, window
chat) steps the page aside so the window is seen; the WIRE CITY button
then says "Back to my page".

## Making one, as a model

1. write_file D:\PAGES\NAME.INI or NAME.HTM - the person's own files; DOS
   names. `page --example games`, `code` (INI) or `studio` (HTML) writes
   one to start from (it refuses a file that is there).
2. `page D:\PAGES\NAME.HTM` - the check: what it holds, each button and
   list with its effect, what was taken out, the problems. Mend them with
   edit_file; a page with problems is never put on.
3. `page D:\PAGES\NAME.HTM --use` - the person sees the page described in
   a Yes box and says Yes or No. What was checked is kept: change the
   file after, and it takes another --use.
4. `page` lists the pages and which is on; `page --off` is the whole site
   again. Files > Pages (or `window pages`) is the same as a window.

Every token is the person's: an INI desktop is a few hundred; an HTML
page a few thousand - write it once, mend it with edit_file.

## What stays the site's

- In an INI desktop the WIRE CITY menu, last on the bar; in an HTML page
  the WIRE CITY button in the corner: the whole site again (for a while,
  or the page off), the pages. A page cannot take either away.
- Only one's own: a page is put on from D: only - not from a link, a ZIP
  or a disk someone else made. Sharing a page is sharing its words: the
  other person's model writes their own file from them.
- A profile does not carry the page; D:\PAGES does, in a ZIP
  (`zip D:\PAGES`).
- `?ui=off` in the address is the whole site for one visit, whatever page
  is on - the way out of a page gone wrong.
