// The site's guided tour: site/?tour=W03-site plays a lecture-rig script of
// the site's own features, for the videos that present it - not a lesson.
//
// It IS the course page's tour (../course/tour.js - read its header first:
// the script, its `;@ action args` comments, the narration s00.wav..., the
// click that starts it, &tourshots), with the site's own actions on top and
// every key it presses SHOWN: a badge in the corner with the keys as a
// person presses them and what they do. A screen recorder's key overlay
// cannot do that - it hooks the operating system, and these keys never leave
// the page (the pilot chose ours, 2026-10-28).
//
// THE FILES, beside this page for a take (docs/site/tour/ is not published -
// .gitignore): tour/NAME.txt, its narration tour/NAME/s00.wav..., and what
// `pickfile` hands the page (tour/DUKE3D.zip).
//
// A TAKE IS ONE LINK (the pilot, 2026-10-28: "a link, I open it, it plays,
// I record"). The network's part needs another visitor; `extra NAME` makes
// one inside the page - the site again in a frame under the screen, playing
// ?tour=NAME&go (no click: it has no narration), its own connection, its own
// animal. Under the screen, not off it: a frame off the screen is slowed.
//
// THE ACTIONS - the course's (keys, type, wait, doskeys, hold, menus, grab,
// release, fly, settings, speed, waitred, front...) and these:
//   ... # WHAT                keys, doskeys, hold and menus may end in `# WHAT`: the badge's caption
//   badge K... # WHAT         a badge alone, nothing pressed - for a click, a drop
//   term LINE                 the terminal in front, LINE typed into it, Enter, its answer awaited
//   chat LINE                 the same into AI > Chat - the model's work is not awaited
//   send LINE                 a console line as a menu sends it - seen only in the terminal's record
//   play KEY [--machine CARD] a game of C:, as the Games menu starts it; waits for the DOS PC
//   waitdos [S]               until the DOS PC runs, S seconds at most
//   waitpeople N [S]          until N others are here - the second browser has come
//   watch [NAME]              the first other screen on air (or NAME's), in its window
//   waitmodel [S]             until a model's next call comes in over MCP - the take's operator gives Claude Code its task now
//   pickfile NAME             the next file picker gets tour/NAME, as if chosen - the picker never shows
//   quiet                     the DOS PC without sound, quietly: the narration is the sound
//   forget KEY...             those localStorage keys gone (site.manuals.1: a game's manual opens as on a first play)
//   repeat N A ; B ; C        actions A, B, C, N times over - the second visitor flying on its own
//   extra NAME                a second visitor of the site, in a frame under the screen, playing tour NAME
//   menu ALT+K N # WHAT       a menu walked as a person walks it: open, N steps down at a reading pace, a pause, Enter
//   step KEY N # WHAT         KEY pressed N times at that pace - a list walked, not jumped
//   waitcall TOOL[ REGEX] [S] until the model's next call of TOOL (its arguments matching REGEX) - narration on its real steps
//   waittask [S]              until the chat's model has finished its request
//   untillit PCT [S] [KEY]    KEY (enter) into DOS every 1.5 s until PCT per cent of the picture is lit - a game's
//                             text menu left for its world (SOKO II's menu took an Enter too early, and its
//                             blinking cursor fooled `menus`: the player stood in the menu, alone, 2026-10-28)
//   frontfile NAME            the editor of the file NAME (CITY.ASM) to the front
//   seek TEXT                 the editor that holds TEXT to the front, TEXT found and selected - checked, not hoped
//   retype NEW                NEW typed over what `seek` found - and nothing typed if it found nothing
//                             (a `find` that missed left the caret where a scroll had put it, and `type`
//                             wrote the colour into line 77: Wire City broke on camera, 2026-10-28)
//   headline TEXT | SMALLER   the beat's title, big over the screen for a moment, as an advertisement puts it
//   spot [dos|front] [MS]     the rest of the screen dimmed round a window - what just appeared, seen
//
// A `menu` spots the window it opened by itself (the pilot, 2026-10-28:
// windows came "out of nowhere" - the eye must be shown what is new).
//
// While a tour plays, the Claude Code line shows its token as dots: a video
// must not carry one - whoever read it would act in this page for a day. And
// the public server's address, not this computer's: the line a visitor of
// the site is given (a take runs on a server of its own, on localhost).

import { log } from '../owlosui/apps/log.js';
import { Tour } from '../course/tour.js';

const sleep = ms => new Promise(r => setTimeout(r, ms));

/** The actions that press keys, and so show them. */
const BADGED = new Set(['keys', 'doskeys', 'hold', 'menus', 'badge', 'menu', 'step', 'untillit']);

/** A person's pace through a menu: the eye finds the menu, follows the bar, reads the item. */
const PACE = { open: 1100, step: 520, read: 800, after: 700 };

/** A script's key name as a keycap says it. */
const CAPS = {
  down: '↓', arrowdown: '↓', up: '↑', arrowup: '↑', left: '←', arrowleft: '←', right: '→', arrowright: '→',
  return: 'Enter', enter: 'Enter', esc: 'Esc', escape: 'Esc', pgdn: 'PgDn', pagedown: 'PgDn', pgup: 'PgUp', pageup: 'PgUp',
  del: 'Del', delete: 'Del', ins: 'Ins', insert: 'Ins', bs: 'Backspace', backspace: 'Backspace', space: 'Space', tab: 'Tab',
  ctrl: 'Ctrl', alt: 'Alt', shift: 'Shift', home: 'Home', end: 'End', rctrl: 'Right Ctrl', click: 'Click',
};

/** `alt+g` as Alt+G, `Down*3` as ↓ ×3. */
function capOf(spec) {
  const [k, times] = spec.split('*');
  const name = k.split('+').map(p => CAPS[p.toLowerCase()] ?? (p.length === 1 ? p.toUpperCase() : p[0].toUpperCase() + p.slice(1))).join('+');
  return Number(times) > 1 ? `${name} ×${times}` : name;
}

/** An action's arguments and its badge's caption: `alt+g Return # Games, Catalog`. */
function captioned(args) {
  const at = args.indexOf(' # ');
  return at < 0 ? [args, ''] : [args.slice(0, at), args.slice(at + 3).trim()];
}

/** The keys an action presses, for its badge. */
function keysOf(name, body) {
  const words = body.trim().split(/\s+/).filter(Boolean);
  // hold w+a 3000: the keys, not the time
  if (name === 'hold') {
    return words.slice(0, 1);
  }
  // menu alt+g 3: Alt+G ↓ ×3 Enter; step down 7: ↓ ×7
  if (name === 'menu') {
    return [words[0], ...(Number(words[1]) > 0 ? [`down*${words[1]}`] : []), 'return'];
  }
  if (name === 'step') {
    return [`${words[0]}*${Number(words[1]) || 1}`];
  }
  if (name === 'untillit') {
    return [words[2] || 'enter'];
  }
  return words;
}

/** The badge in the corner: the keys of the action that runs, and what they do. */
class Badge {
  constructor() {
    this.el = document.createElement('div');
    this.el.id = 'tour-badge';
    this.el.style.cssText = 'position:fixed;right:28px;bottom:56px;z-index:25;display:flex;flex-direction:column;align-items:flex-end;gap:6px;' +
      'pointer-events:none;opacity:0;transition:opacity .25s;font:700 22px/1.25 Consolas,"Courier New",monospace';
    document.body.append(this.el);
    this.hideAt = 0;
  }

  show(keys, caption) {
    clearTimeout(this.timer);
    const caps = keys.map(k => `<kbd style="display:inline-block;min-width:1.4em;text-align:center;padding:4px 10px;margin-left:6px;color:#fff;` +
      `background:#0000aa;border:2px solid #55ffff;border-radius:6px;box-shadow:0 3px 0 #000">${escape(capOf(k))}</kbd>`).join('');
    const what = caption ? `<div style="color:#ffff55;background:rgba(0,0,0,.78);padding:2px 10px;font-size:18px">${escape(caption)}</div>` : '';
    this.el.innerHTML = `<div>${caps}</div>${what}`;
    this.el.style.opacity = '1';
  }

  /** The action is over: the badge stays a moment - the eye needs it after the key, not only during. */
  done(ms = 1400) {
    clearTimeout(this.timer);
    this.timer = setTimeout(() => { this.el.style.opacity = '0'; }, ms);
  }
}

/** A window's place on the page, in CSS pixels: OWLOSUI places it in cells of the screen's canvas. */
function windowRect(owl, win) {
  const p = win ? owl.place(win) : null;
  const cv = document.getElementById('screen');
  if (!p || !cv || !owl.screen) {
    return null;
  }
  const r = cv.getBoundingClientRect(), sx = r.width / cv.width, sy = r.height / cv.height;
  return { x: r.left + p.x * owl.screen.cellW * sx, y: r.top + p.y * owl.screen.cellH * sy, w: p.w * owl.screen.cellW * sx, h: p.h * owl.screen.cellH * sy };
}

/** The beat's title, big and short - "No install. Just a link." - and a smaller line under it. */
async function headline(text) {
  const [big, small] = text.split('|').map(s => s.trim());
  const el = document.createElement('div');
  el.id = 'tour-headline';
  el.style.cssText = 'position:fixed;left:0;right:0;top:38%;z-index:26;pointer-events:none;text-align:center;padding:22px 16px;' +
    'background:linear-gradient(90deg,rgba(0,0,40,0),rgba(0,0,40,.88) 18%,rgba(0,0,40,.88) 82%,rgba(0,0,40,0));' +
    'opacity:0;transform:scale(.96);transition:opacity .35s,transform .35s;font-family:Consolas,"Courier New",monospace';
  el.innerHTML = `<div style="font:700 54px/1.1 Consolas,'Courier New',monospace;color:#ffff55;text-shadow:0 3px 0 #000">${escape(big)}</div>` +
    (small ? `<div style="margin-top:10px;font:400 26px/1.3 Consolas,'Courier New',monospace;color:#55ffff">${escape(small)}</div>` : '');
  document.getElementById('tour-headline')?.remove();
  document.body.append(el);
  await sleep(30);
  el.style.opacity = '1';
  el.style.transform = 'scale(1)';
  await sleep(2200);
  // Going while the beat begins under it.
  el.style.opacity = '0';
  setTimeout(() => el.remove(), 600);
}

/** The screen dimmed round one window for a moment: the eye is shown what just appeared. */
async function spot(rect, ms = 1800) {
  if (!rect) {
    return;
  }
  const el = document.createElement('div');
  el.style.cssText = `position:fixed;left:${rect.x - 4}px;top:${rect.y - 4}px;width:${rect.w + 8}px;height:${rect.h + 8}px;z-index:24;` +
    'pointer-events:none;border:3px solid #ffff55;border-radius:4px;box-shadow:0 0 0 9999px rgba(0,0,0,.5);opacity:0;transition:opacity .3s';
  document.body.append(el);
  await sleep(30);
  el.style.opacity = '1';
  await sleep(ms);
  el.style.opacity = '0';
  setTimeout(() => el.remove(), 400);
}

function escape(s) {
  return String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
}

export class SiteTour extends Tour {
  constructor(app, name) {
    super(app, name);
    // The site's take files, not the course's: site/tour/NAME.
    this.base = new URL(`tour/${name}`, import.meta.url);
    this.badge = new Badge();
  }

  async start() {
    this.maskTokens();
    this.listenToCalls();
    return super.start();
  }

  /** Every tool a model calls in this page, in order - `waitcall` reads them from where it last stopped. */
  listenToCalls() {
    const agent = this.app.agent;
    this.calls = [];
    this.callsRead = 0;
    if (!agent) {
      return;
    }
    const run = agent.run.bind(agent);
    agent.run = (tool, args, who) => {
      this.calls.push({ tool, args: JSON.stringify(args ?? {}), at: Date.now() });
      return run(tool, args, who);
    };
  }

  /** The model's next call of TOOL whose arguments match RE, from where the last wait stopped: true when it came. */
  async waitCall(tool, re, ms) {
    const found = () => {
      for (let i = this.callsRead; i < this.calls.length; i++) {
        if (this.calls[i].tool === tool && (!re || re.test(this.calls[i].args))) {
          this.callsRead = i + 1;
          return true;
        }
      }
      return false;
    };
    return this.until(found, ms, `the model's ${tool}`);
  }

  /** A menu as a person walks it: open it, follow the bar down, read the item, take it - and the window it opened, spotted. */
  async menu(args) {
    const [hot, n] = args.trim().split(/\s+/);
    const was = this.owl.active();
    this.key(hot);
    await sleep(PACE.open);
    for (let i = 0; i < (Number(n) || 0); i++) {
      this.key('ArrowDown');
      await sleep(PACE.step);
    }
    await sleep(PACE.read);
    this.key('Enter');
    await sleep(PACE.after);
    const now = this.owl.active();
    if (now && now !== was) {
      await spot(windowRect(this.owl, now));
    }
  }

  /** KEY N times at a reading pace: a list walked, not jumped. */
  async step(args) {
    const [k, n] = args.trim().split(/\s+/);
    for (let i = 0; i < (Number(n) || 1); i++) {
      this.key(k);
      await sleep(PACE.step);
    }
    await sleep(PACE.read);
  }

  /** The Claude Code line with its token as dots, for as long as the page plays a tour. */
  maskTokens() {
    const agent = this.app.agent;
    if (!agent) {
      return;
    }
    const line = agent.addLine.bind(agent);
    agent.addLine = token => line(`${'•'.repeat(12)}${String(token).slice(-4)}`).replace(/https?:\/\/(localhost|127\.0\.0\.1):\d+/, 'https://lan.owlos.sk');
  }

  /** ?tour=NAME&go starts at once: a second visitor in a frame has no narration to unlock with a click. */
  clickToStart() {
    if (new URLSearchParams(location.search).has('go')) {
      return Promise.resolve();
    }
    return super.clickToStart();
  }

  /** A second visitor: the site again, in a frame UNDER the screen - covered, never off it (a frame off the screen is slowed). */
  startExtra(name) {
    const f = document.createElement('iframe');
    f.id = 'tour-extra';
    f.src = `${location.pathname}?tour=${encodeURIComponent(name)}&go`;
    f.style.cssText = 'position:fixed;left:0;top:0;width:960px;height:640px;border:0;z-index:-1;pointer-events:none';
    f.setAttribute('aria-hidden', 'true');
    document.body.append(f);
    log.info('tour', `a second visitor: ${name}, in a frame under the screen`);
  }

  /** A page key; Ctrl+` also needs the key's place - the terminal opens by it (terminal.js key). */
  key(spec) {
    if (!spec.endsWith('`')) {
      super.key(spec);
      return;
    }
    const mods = { ctrlKey: spec.includes('ctrl+'), altKey: spec.includes('alt+'), shiftKey: spec.includes('shift+') };
    for (const type of ['keydown', 'keyup']) {
      document.dispatchEvent(new KeyboardEvent(type, { key: '`', code: 'Backquote', bubbles: true, cancelable: true, ...mods }));
    }
    this.owl.refresh?.();
  }

  /**
   * TEXT found and selected in the editor that holds it, that editor in
   * front: each open editor tried, the newest first, from its caret and then
   * from its top. True when it is selected - and only then may `retype` type.
   */
  async seek(text) {
    const owl = this.owl;
    const docs = [...this.app.docs.entries()].reverse();
    for (const [win, doc] of docs) {
      if (!owl.place(win)) {
        continue;
      }
      owl.activate(win);
      owl.refresh?.();
      await sleep(300);
      if (owl.active() !== win) {
        continue;
      }
      if (owl.find(doc.text, text)) {
        owl.refresh?.();
        return true;
      }
      // Past it: from the top.
      this.key('ctrl+Home');
      await sleep(200);
      if (owl.find(doc.text, text)) {
        owl.refresh?.();
        return true;
      }
    }
    log.warn('tour', `seek: no open editor holds ${text}`);
    return false;
  }

  /** How much of DOS's picture is lit, 0..1 - a text menu is mostly black, a game's world is not. */
  async lit() {
    const im = await this.app.dos.box.ci?.screenshot().catch(() => null);
    if (!im) {
      return 0;
    }
    let n = 0;
    for (let p = 0; p < im.data.length; p += 16) {
      if (im.data[p] + im.data[p + 1] + im.data[p + 2] > 60) {
        n++;
      }
    }
    return n / (im.data.length / 16);
  }

  /** Who this page is, as the server named it. */
  myName() {
    const me = this.app.presence?.me;
    return typeof me === 'string' ? me : me?.name;
  }

  /** The others here now - the people the server lists, this page left out. */
  others() {
    const me = this.myName();
    return (this.app.presence?.people ?? []).filter(p => p.name !== me);
  }

  /** LINE typed into a terminal in front, Enter, and - if asked - its answer awaited. */
  async typeInto(t, line, wait = true) {
    if (!t.front) {
      await t.show();
      await sleep(500);
    }
    await this.until(() => !t.busy, 30000, 'the terminal');
    await this.type(line);
    await sleep(350);
    this.key('Enter');
    if (wait) {
      await sleep(250);
      await this.until(() => !t.busy, 120000, line);
    }
  }

  async act([name, args]) {
    // A repeat's actions carry their own captions: `repeat 8 doskeys enter # front screens ; wait 1500`.
    const [body, caption] = name === 'repeat' ? [args ?? '', ''] : captioned(args ?? '');
    const shows = BADGED.has(name);
    if (shows) {
      this.badge.show(keysOf(name, body), caption);
    }
    try {
      await this.siteAct(name, body);
    } catch (e) {
      log.warn('tour', `${name} ${body}: ${e.message}`);
    } finally {
      if (shows) {
        this.badge.done();
      }
    }
  }

  async siteAct(name, args) {
    const app = this.app;
    switch (name) {
      case 'badge': await sleep(900); break;
      case 'term': await this.typeInto(app.terminal, args.trim()); break;
      case 'chat': {
        await app.ai.chat.show();
        await this.typeInto(app.ai.chat.term, args.trim(), false);
        break;
      }
      case 'send': await app.send(args.trim(), 'Tour'); break;
      case 'play': {
        await app.send(`play ${args.trim()}`, 'Games');
        await sleep(1500);
        await this.until(() => app.dos.box.running, 60000, 'the DOS PC');
        break;
      }
      case 'waitdos': await this.until(() => app.dos.box.running, (Number(args) || 60) * 1000, 'the DOS PC'); break;
      case 'waitpeople': {
        const [n, s] = args.trim().split(/\s+/).map(Number);
        await this.until(() => this.others().length >= (n || 1), (s || 60) * 1000, `${n || 1} others here`);
        break;
      }
      case 'watch': {
        const want = args.trim();
        const onAir = () => this.others().find(p => p.sharing && (!want || p.name === want));
        await this.until(() => !!onAir(), 60000, 'a screen on air');
        const who = onAir();
        if (who) {
          await app.send(`watch ${who.name}`, 'LAN');
        }
        break;
      }
      case 'waitmodel': {
        // The calls this page has answered (agent.js): the next one is the model at work.
        const before = app.agent?.calls ?? 0;
        log.info('tour', 'waiting for the model: give Claude Code its task now');
        await this.until(() => (app.agent?.calls ?? 0) > before, (Number(args) || 300) * 1000, 'the model');
        break;
      }
      case 'pickfile': await this.pickFile(args.trim()); break;
      case 'extra': this.startExtra(args.trim()); break;
      case 'seek': this.sought = await this.seek(args.trim()); break;
      case 'frontfile': {
        // The editor of NAME in front - not "the newest editor", which a stray Enter in a commander can change.
        const want = args.trim().toUpperCase();
        const hit = [...app.docs.entries()].reverse().find(([win, d]) => this.owl.place(win) && String(d.name ?? d.path ?? '').toUpperCase().endsWith(want));
        if (hit) {
          this.owl.activate(hit[0]);
          this.owl.refresh?.();
          await sleep(300);
        } else {
          log.warn('tour', `frontfile: no editor holds ${want}`);
        }
        break;
      }
      case 'retype': {
        if (!this.sought) {
          log.warn('tour', `retype ${args.trim()}: the seek found nothing - nothing typed`);
          break;
        }
        await this.type(args.trim());
        this.sought = false;
        break;
      }
      case 'untillit': {
        const [pct, s, k] = args.trim().split(/\s+/);
        const limit = Date.now() + (Number(s) || 30) * 1000;
        while (Date.now() < limit) {
          if (await this.lit() * 100 > (Number(pct) || 30)) {
            log.info('tour', `the picture is lit: in`);
            break;
          }
          await this.dosKeys(k || 'enter');
          await sleep(1500);
        }
        break;
      }
      case 'menu': await this.menu(args); break;
      case 'headline': await headline(args); break;
      case 'spot': {
        const [which, ms] = args.trim().split(/\s+/);
        const win = which === 'dos' ? app.dos.win : this.owl.active();
        await spot(windowRect(this.owl, win), Number(ms) || 1800);
        break;
      }
      case 'step': await this.step(args); break;
      case 'waitcall': {
        // waitcall console build 240: the tool, a word its arguments hold, seconds
        const [tool, ...rest] = args.trim().split(/\s+/);
        const s = /^\d+$/.test(rest.at(-1) ?? '') ? Number(rest.pop()) : 180;
        await this.waitCall(tool, rest.length ? new RegExp(rest.join(' '), 'i') : null, s * 1000);
        break;
      }
      case 'waittask': {
        const chat = app.ai?.chat;
        await sleep(1500);
        await this.until(() => !chat?.working, (Number(args) || 600) * 1000, 'the model to finish');
        break;
      }
      case 'quiet': {
        // The narration is the sound. The DOS PC keeps its Sound Blaster - a
        // game set up for one leaves without it (Duke's own DUKE3D.CFG did,
        // with sbtype=none, 2026-10-28) - and is muted instead: every start
        // makes a new machine, so each one as it comes.
        clearInterval(this.muter);
        this.muter = setInterval(() => {
          const ci = app.dos.box.ci;
          if (ci && ci !== this.muted) {
            ci.mute();
            this.muted = ci;
          }
        }, 250);
        break;
      }
      case 'forget': {
        for (const k of args.trim().split(/\s+/).filter(Boolean)) {
          try { localStorage.removeItem(k); } catch { /* nothing kept */ }
        }
        break;
      }
      case 'repeat': {
        const at = args.search(/\s/);
        const n = Number(args.slice(0, at)) || 1;
        const steps = args.slice(at + 1).split(/\s+;\s+/).map(s => s.trim()).filter(Boolean)
          .map(s => { const sp = s.search(/\s|$/); return [s.slice(0, sp).toLowerCase(), s.slice(sp + 1)]; });
        for (let i = 0; i < n; i++) {
          for (const a of steps) {
            await this.act(a);
          }
        }
        break;
      }
      default: await super.act([name, args]);
    }
  }

  /**
   * The next file picker the page opens gets tour/NAME, as if the person had
   * chosen it: the picker is the browser's own window, which a script can
   * neither open nor fill, and which a recording does not need to show.
   */
  async pickFile(name) {
    const r = await fetch(new URL(name, this.base));
    if (!r.ok) {
      throw new Error(`no ${name} beside the tour (${r.status})`);
    }
    const file = new File([await r.arrayBuffer()], name.split('/').pop(), { type: r.headers.get('content-type') ?? '' });
    const click = HTMLInputElement.prototype.click;
    HTMLInputElement.prototype.click = function () {
      if (this.type !== 'file') {
        click.call(this);
        return;
      }
      HTMLInputElement.prototype.click = click;
      const dt = new DataTransfer();
      dt.items.add(file);
      this.files = dt.files;
      setTimeout(() => this.onchange?.(new Event('change')), 700);
    };
    log.info('tour', `the next file picker gets ${name}, ${file.size} bytes`);
  }
}
