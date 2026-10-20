// The site's help, as pages with links (the pilot, 2026-10-20: "our help
// supports links - to other help pages and to elements that can be opened at
// once"). OWLOSUI's help view draws them (owl.html: links, headings, <b>,
// paragraphs, lists, rules, <pre>; Tab goes from link to link, Enter or a
// click follows one). A link is one of:
//
//   #name        a place in the same page - the view follows it itself
//   TOPIC        another page here: KEYS, DRIVES, NETWORK...
//   run:LINE     a line of the console, run as typed - judged by the command
//                contract first, as an item of a page of one's own is: what
//                deletes, changes the setup or gives something out asks
//   https://...  another site - its address said first, then a tab of its own
//
// `info [TOPIC]` opens a page (Help > ... sends it); `info --json` lists them,
// so a model or a page of one's own can link to them too.

import { Style } from '../owlosui/owlosui.js';

export const HELP_CLOSE = 980, HELP_BACK = 981;

const a = (href, text) => `<a href="${href}">${text}</a>`;
const run = (line, text) => a(`run:${line}`, text);

/** The pages, by topic: a title and its HTML. */
export const HELP = {
  INDEX: {
    title: 'WIRE CITY',
    html: `<h1>WIRE CITY 86 - help</h1>
<p>A DOS PC in your browser, with real drives: our games on C:, their sources and the lessons that teach how they are made on A:, your own files on D: - and the assembler, to change them and build them again. Free, and the sources are open. Tab goes from link to link, Enter follows one; Alt+F1 goes back.</p>
<h2>What is here</h2>
<ul>
<li>${a('GAMES', 'The games')} - what each one is, and its keys</li>
<li>${a('LESSONS', 'The lessons')} - the course in 8086 assembly</li>
<li>${a('DRIVES', 'Drives and letters')} - where every file is</li>
<li>${a('KEYS', 'Keys')} - every key of the site</li>
<li>${a('WINDOWS', 'Windows')} - side by side, one over the other, the list</li>
<li>${a('CONSOLE', 'The terminal')} - the commands every window and menu runs</li>
<li>${a('NETWORK', 'The network')} - who is here, shared screens, the live map, games for several</li>
<li>${a('AI', 'AI')} - a model that writes, builds and plays in this page</li>
<li>${a('PAGES', 'A page of your own')} - the site with only what you want, or a look all your own</li>
<li>${a('PRIVACY', 'Who sees what')}</li>
<li>${a('ABOUT', 'About')} - what WIRE CITY is, and what it is made with</li>
</ul>
<h2>Open at once</h2>
<ul>
<li>${run('window catalog', 'The games on C:')} - Enter plays one</li>
<li>${run('window lessons', 'The lessons')}</li>
<li>${run('window terminal', 'The terminal')}</li>
<li>${run('window who', 'Who is online')} - and ${run('sky', 'the live map')}</li>
<li>${run('window chat', 'The AI chat')}</li>
</ul>`,
  },
  GAMES: {
    title: 'The games',
    html: `<h1>The games</h1>
<p>Every game here is new code, written now for the 8086 in assembly, the way it was written then: mode 13h, integer maths, no libraries. Each runs on the DOS PC from its folder on C:, and its source is on A: - change it, build it again with F9.</p>
<ul>
<li>${run('play owlfly3', 'OWL FLY III')} - the war on CGA, EGA, VGA and Hercules; for several, in one sky</li>
<li>${run('play owlfly2', 'OWL FLY II')} - the flight simulator with its three-screen cockpit</li>
<li>${run('play owlfly', 'OWL FLY')} - where the flying began</li>
<li>${run('play trainer', 'The Flight School')} - learning to fly, a step at a time</li>
<li>${run('play wirecity', 'WIRE CITY')} - a night flight over a wireframe city</li>
<li>${run('play multsoko', 'MULTIPLAY SOKO')} - Sokoban for up to eight, one warehouse</li>
</ul>
<p>${run('window catalog', 'The catalog')} says each game's keys; while one runs, ${run('manual', 'Help &gt; Manual')} does. A click on the DOS picture gives it the keyboard, Right Ctrl takes it back. The networked ones meet the others here - ${a('NETWORK', 'the network')}.</p>`,
  },
  LESSONS: {
    title: 'The lessons',
    html: `<h1>The lessons</h1>
<p>A course in 8086 assembly, from the first byte to a flight simulator: each lesson is a video, a source, and a DOS PC that builds and runs it. F1 is the list; a lesson opens whole - its source on the left, its video on the right, the DOS PC building it.</p>
<ul>
<li>${run('window lessons', 'Every lesson')}</li>
<li>${run('lesson 1', 'Lesson 1')} - the beginning</li>
</ul>
<p>F9 saves the source in front, assembles it with FASM and runs what it made; Ctrl+F9 runs it again. <b>lesson N --reset</b> in the terminal puts a lesson's files back as the course ships them. The files are on A: (${a('DRIVES', 'drives')}).</p>`,
  },
  DRIVES: {
    title: 'Drives and letters',
    html: `<h1>Drives and letters</h1>
<p>A drive is a letter, and every part of the site sees the same ones: the Files menu, Map Drives, both Kirin Commanders, the terminal (/mnt/a, /mnt/c ...) and the DOS PC.</p>
<ul>
<li><b>A:</b> the course disk - the lessons, the examples, the games' sources and FASM. Kept in this browser.</li>
<li><b>B:</b> a second floppy, in this browser - for an installer that asks for disk 2.</li>
<li><b>C:</b> the DOS PC's hard disk, in this browser: C:\\GAMES. What DOS saves there is there tomorrow; a newer game from the site replaces only the files you have not changed.</li>
<li><b>D:</b> My files, in this browser: your own.</li>
<li><b>E: to Z:</b> what Map Drives adds - a folder of this browser, a folder on this computer (Chrome and Edge ask first; DOS writes to it only if you said so), or a ZIP from this computer or a link.</li>
</ul>
<p>"In this browser" is the browser's storage for this site: nobody else sees it, and a clean-up of the site's data takes it all, D: too. Files &gt; Save profile keeps the table of drives (not their files) in a file on your computer; Load profile puts it back. What you want to keep, copy to a folder of this computer.</p>
<p>DOS sees a change in the table at its next switch-on. A file deleted inside DOS comes back then: delete in Kirin Commander for Web or in the terminal.</p>
<ul>
<li>${run('window drives', 'Map Drives')}</li>
<li>${run('commander', 'Kirin Commander for Web')} - A: and D:</li>
<li>${run('commander dos', 'Kirin Commander for DOS')}</li>
</ul>`,
  },
  KEYS: {
    title: 'Keys',
    html: `<h1>Keys</h1>
<pre>THE SITE
  F10, Alt+a letter    the menu - Alt+F Files, Alt+G Games ...
  F1                   the lessons
  F3                   the games
  F2                   save the file in front
  F9                   build the source in front, and run it
  Ctrl+F9              run it again
  F5                   the window in front as big as it goes, and back
  F6, Shift+F6         the next window, the one before
  Alt+0                the list of windows
  Alt+F3               close the window in front
  Ctrl+\`               the terminal - Esc closes it

THE DOS PC
  a click on it        the keys go to DOS ("keys in DOS")
  Right Ctrl           the keys come back to the site

THE GAMES, MAP DRIVES, PAGES
  Enter                play; open the drive; put the page on
  F4                   the source; edit the drive; edit the page
  Ins, Del             add a drive; take one away

KIRIN COMMANDER FOR WEB
  Alt+F1, Alt+F2       a drive for the left panel, the right
  F3 view  F4 edit  F5 copy  F6 move  F7 new folder  F8 delete
  Ctrl+U               the panels change places

THE TERMINAL
  Tab                  finish a word
  Up, Down, Ctrl+R     what was typed, and a search in it
  Ctrl+C               stop a command</pre>
<p>A help page: Tab and Shift+Tab go from link to link, Enter or a click follows one, Alt+F1 goes back. More on ${a('WINDOWS', 'windows')} and ${a('CONSOLE', 'the terminal')}.</p>`,
  },
  WINDOWS: {
    title: 'Windows',
    html: `<h1>Windows</h1>
<p>Every part of the site is a window: the DOS PC, an editor, the terminal, the games, the chat. The Window menu arranges them - and each of its items is a line of the terminal, so a page of your own can have them too.</p>
<ul>
<li>${run('window tile', 'Tile')} - every window side by side</li>
<li>${run('window cascade', 'Cascade')} - one over the other, each title seen</li>
<li>${run('window next', 'Next')} (F6) and ${run('window previous', 'previous')} (Shift+F6)</li>
<li>${run('window zoom', 'Zoom')} (F5) - the one in front as big as it goes</li>
<li>${run('window list', 'The list')} (Alt+0) - every window, to pick one</li>
</ul>
<p>A window is dragged by its title, sized by its corner; the box at the top right closes it, the one beside it zooms, the arrow puts it away into its bar. <b>window NAME left</b> (right, top, bottom, full) opens one in that half: ${run('window chat left', 'the chat on the left')}, ${run('window dos right', 'the DOS PC on the right')}.</p>`,
  },
  CONSOLE: {
    title: 'The terminal',
    html: `<h1>The terminal</h1>
<p>Ctrl+\` drops it, Esc closes it. Everything the menus and windows do is a command - and shows there as the command it is, so the next time it can be typed: play a game, open a drive, build a source.</p>
<ul>
<li><b>help</b> - every command, by what it is for; <b>man NAME</b> - one, its options, its effect</li>
<li><b>help --json</b> - every command's contract, as data: what a model or a page of your own builds on</li>
<li>A: is /mnt/a, C:\\GAMES works too; ~ is D:, My files</li>
</ul>
<p>Each command says its effect: it reads, shows, runs, writes, deletes, changes your setup, or gives something out. A model working here, and a page of your own, run the first four at once; the rest only after your Yes. More in ${a('AI', 'AI')} and ${a('PAGES', 'pages')}.</p>
<p>${run('window terminal', 'Open the terminal')} - or ${run('help', 'list the commands')}.</p>`,
  },
  NETWORK: {
    title: 'The network',
    html: `<h1>The network</h1>
<p>The site connects to our server when it opens; the server names the connection an animal. Nobody signs in. ${a('PRIVACY', 'Who sees what')} says what the others see.</p>
<ul>
<li>${run('window who', 'Who is online')} - every animal here, and what each does</li>
<li>${run('sky', 'The live map')} - the sky of the game you fly, or OWL FLY III's: every jet where it is; a click on one that shares its screen watches it</li>
<li>${run('share', 'Share my screen')} - your DOS screen for the others to watch (it asks first); <b>share --stop</b> ends it</li>
<li><b>watch NAME</b> - a screen someone shares, in a window</li>
<li>${run('window netmon', 'The network monitor')} - the DOS PC on the relay: bytes each way, a graph, every packet; <b>net</b> in the terminal says the same as data</li>
</ul>
<p>The networked games meet in rooms of the server's relay: OWL FLY II and III fly in one sky with everyone who plays them here; MULTIPLAY SOKO is one warehouse. A program of your own goes on the relay with <b>build FILE.ASM --net</b> - in a room of its folder's name.</p>`,
  },
  AI: {
    title: 'AI',
    html: `<h1>AI</h1>
<p>A model works in this page while you watch: it writes a program in assembly, builds it with FASM on the DOS PC, looks at the screen, presses keys, and hands you the folder as a ZIP. It acts with your rights and no more; what would delete, replace your files or change your setup asks you first.</p>
<ul>
<li>${run('window chat', 'The chat')} - on your own Anthropic API key: /key sets it, kept in this browser only</li>
<li>${run('window agents', 'Agents')} - the chat, and your own Claude Code connected through MCP: a new token, its line, taken back</li>
<li>${run('window tasks', 'Tasks')} - what the models work on, and what it cost</li>
<li>${run('window calls', 'The console')} - every call a model made here</li>
</ul>
<p>A model reads the site's guide - what the work on these games found out: DOSBox, FASM, video, physics, the network. Every token is yours: start small, mend with a line, not the whole file again. A model can also make ${a('PAGES', 'a page of your own')}.</p>`,
  },
  PAGES: {
    title: 'A page of your own',
    html: `<h1>A page of your own</h1>
<p>The site holds everything. A page of your own shows only what you want, in two kinds - both files on D:\\PAGES, made by you or by your model:</p>
<ul>
<li><b>An INI desktop</b> (NAME.INI) - the site's own look with only your menus, keys and windows: "only games with my AI", "only writing and building code". A few lines.</li>
<li><b>An HTML page</b> (NAME.HTM) - the whole look your own: Bootstrap or any CSS, the DOS PC in it, buttons and lists of your design.</li>
</ul>
<p>There is no code of a page's own in either: its buttons are lines of the terminal, judged by what they do - what deletes, changes your setup or gives something out asks you each time. The WIRE CITY menu, or the button in the corner, always brings the whole site back; <b>?ui=off</b> in the address is the whole site for one visit.</p>
<ul>
<li>${run('window pages', 'Your pages')} - put one on, edit it, the whole site again</li>
<li>${run('page --example games', 'Write the "games with my AI" example')}</li>
<li>${run('page --example code', 'Write the "write and build" example')}</li>
<li>${run('page --example studio', 'Write the HTML studio example')}</li>
</ul>`,
  },
  PRIVACY: {
    title: 'Who sees what',
    html: `<h1>Who sees what</h1>
<p>Nobody signs in here. When the site opens it connects to our server, and the server names the connection an animal - Rabbit, Fox - different from the others open now. The name lasts as long as the connection: a reload, or the next visit, is a new animal.</p>
<h2>What the others here see of you</h2>
<p>Your animal, and what you are doing, as one of these words: here, plays GAME, in lesson N, builds a program, edits a file, goes through files, in the terminal, away. Never a file's or a folder's name, never what you type, never what is on your drives. A screen you share, while you share it.</p>
<h2>What the server sees</h2>
<p>The connection, as every server does - your address comes with it. The server passes it nowhere: not into the list, not to the others, not into its log. It keeps nothing about you once you have gone.</p>
<h2>What never leaves this browser</h2>
<p>Your files - A: to Z: are this browser's and this computer's; the terminal's history; your profile, unless you save it yourself; your API key and your tokens.</p>
<p>${run('window who', 'Who is online')} - ${a('NETWORK', 'the network')}</p>`,
  },
  ABOUT: {
    title: 'About',
    html: `<h1>About WIRE CITY 86</h1>
<p>Games and a step-by-step course written in 8086 assembly - VGA mode 13h, integer maths, no libraries - playable and buildable in a browser. Open source and free. It is given away by ${a('https://owlos.sk/', 'Owlos')}, whose work is keeping and modernising software of this kind, so that the way it was built stays understandable to the next programmers. Not a museum: a skill kept in working order. The name is a badge, not a date - this is new software, written now, the way it was written then.</p>
<p>The sources: ${a('https://github.com/KirinDenis/wire-city-2', 'github.com/KirinDenis/wire-city-2')}</p>
<h2>Made with</h2>
<ul>
<li>${a('https://github.com/KirinDenis/OWLOSUI', 'OWLOSUI')} - the windows, menus, editor and commanders: one core, in the browser, on a desktop and in DOS</li>
<li>${a('https://js-dos.com/', 'js-dos')} - the DOS PC: DOSBox compiled to WebAssembly</li>
<li>${a('https://www.dosbox.com/', 'DOSBox')} - the emulator under it</li>
<li>${a('https://flatassembler.net/', 'flat assembler')} - FASM, which builds every game and lesson, on the DOS PC itself</li>
<li>${a('https://github.com/modelcontextprotocol/csharp-sdk', 'MCP C# SDK')} - how your own Claude Code reaches this page</li>
<li>${a('https://getbootstrap.com/', 'Bootstrap')} - the one stylesheet an HTML page of your own may load</li>
</ul>
<p>${a('INDEX', 'The help')} - ${a('PRIVACY', 'who sees what')}</p>`,
  },
};

/** The help window: a page at a time, the links followed, Back through the pages seen. */
export class Help {
  constructor(app) {
    this.app = app;
    this.win = 0;
    this.view = 0;
    this.topic = null;
    this.back = [];
  }

  get owl() { return this.app.owl; }
  get isOpen() { return !!this.win && !!this.owl.place(this.win); }
  owns(id) { return !!id && id === this.win; }
  handles(cmd) { return cmd === HELP_CLOSE || cmd === HELP_BACK; }

  /** A page shown - in the window if it is open, the page before it kept for Back. False for a topic there is none of. */
  show(topic = 'INDEX', { back = false } = {}) {
    const key = String(topic).toUpperCase(), t = HELP[key];
    if (!t) return false;
    const owl = this.owl;
    if (!this.isOpen) {
      const W = owl.width, H = owl.height;
      const w = Math.min(W, Math.max(60, Math.round(W * 0.62))), h = Math.min(H - 2, Math.max(14, Math.round((H - 2) * 0.82)));
      this.win = owl.window(`Help - ${t.title}`, w, h, { x: Math.floor((W - w) / 2), y: 1 + Math.floor((H - 2 - h) / 2), style: Style.Help, closeCmd: HELP_CLOSE });
      this.view = owl.html(this.win, t.html);
      owl.windowStatus(this.win,
        { label: '~Tab~ Next link', cmd: 0 }, { label: '~Enter~ Follow', cmd: 0 },
        { label: '~Alt-F1~ Back', cmd: HELP_BACK, key: 'F1', alt: true }, { label: '~Esc~ Close', cmd: HELP_CLOSE, key: 'Escape' });
      this.back = [];
    } else {
      if (!back && this.topic && this.topic !== key) this.back.push(this.topic);
      owl.setText(this.view, t.html);
      owl.setText(this.win, `Help - ${t.title}`);
    }
    this.topic = key;
    owl.activate(this.win);
    owl.refresh?.();
    return true;
  }

  close() {
    if (this.isOpen) this.owl.close(this.win);
    this.win = 0;
    this.view = 0;
    this.topic = null;
  }

  onCommand(cmd) {
    if (cmd === HELP_CLOSE) this.close();
    if (cmd === HELP_BACK && this.back.length) this.show(this.back.pop(), { back: true });
  }

  /** After every event: a link followed in the page, done. */
  poll() {
    if (!this.isOpen) return;
    const href = this.owl.takeLink(this.view);
    if (href) this.app.track(this.follow(href));
  }

  async follow(href) {
    const app = this.app;
    if (/^run:/i.test(href)) { await app.runPageLine(href.slice(4).trim(), href.slice(4).trim(), { from: 'Help', whose: 'in the help' }); return; }
    if (/^https:\/\//i.test(href)) { await app.leaveFor(href); return; }
    if (!this.show(href)) app.tell('Help', `${href}: no such page here`);
  }
}

/** `info --json`: every page, for a model or a page of one's own to link to. */
export const helpTopics = () => Object.entries(HELP).map(([topic, t]) => ({ topic, title: t.title }));
