// The guided tour: the course page plays a script of its own features, for
// a video that presents the page (not a lesson). course/?tour=W02-course
//
// THE SCRIPT is a lecture-rig script (C:\DOSFiles\lecture-rig\scripts\), so
// the rig renders its narration as it does every lesson's:
//
//     Director.exe --render W02-course --voice=kokoro
//
// Its `say` lines are the narration; its browser actions are COMMENTS the
// rig skips and this file reads - `;@ action args`. An action written under
// a say runs when that say STARTS (the rig's own rule for keys), one after
// another; the next say starts when its narration has ended AND its actions
// are done. Actions before the first say run before it.
//
// THE FILES, copied beside this page for the take (docs/course/tour/ is not
// published - .gitignore): tour/W02-course.txt, and the rendered narration
// tour/W02-course/s00.wav, s01.wav... one per say, in order.
//
// THE TAKE: open the page with ?tour=NAME, start OBS, click the page - a
// browser plays sound only after a click - and keep hands off: every key
// is the script's.
//
// ACTIONS (keys are KeyboardEvent names: Down, Return, F9, End, Escape,
// ctrl+End, alt+d; Down*4 presses four times):
//   wait MS                  pause
//   keys K...                keys to the page, as typed
//   type TEXT                the rest of the line, typed at a person's pace
//   front editor|dos|video|build|commander   that window to the front (commander: its right panel)
//   find TEXT                the caret to TEXT in the editor in front
//   waitbuild                until the Build strip shows FASM's last line
//   waitlog REGEX            until a log line matches (a game's MAKE.BAT)
//   doskeys K...             keys to DOS: enter esc space f10 ... (js-dos codes)
//   hold K+K MS              keys held down together in DOS: hold w+a 3000 (throttle and burner)
//   menus K...               keys to a DOS program's menus, one each: waits for the menu, checks it changed, presses again if not
//   grab | release           the keyboard to DOS, or back
//   commander                Tools > Commander; closecommander closes both its panels
//   cmdto NAME               Down in the commander's panel until NAME is under the cursor
//   settings PAGE            DOS > Settings on page PAGE (0 Machine, 1 CPU...)
//   click X Y                a click in the front window, X Y inside it, in cells
//   cmd N                    a command by number
//   waitred X0 Y0 X1 Y1 [S]  until red shows in that box of the DOS picture (a STALL warning), S seconds at most
//   waitnored X0 Y0 X1 Y1 [S] until it is gone again
//   lesson Lnn              open that lesson as the list does (it builds; `waitbuild` waits for it)
//   run Lnn NAME            a program in that lesson's folder on A:, as Enter in the commander runs it
//   game KEY                a game from the DOS menu (owlfly, owlfly2, owlfly3)
//   fly [S]                  Enter through OWL FLY's front screens into the cockpit (S seconds at most, 60)
//   fresh Lnn                that lesson's files on A: as the course ships them
//   speed auto|max           the DOS PC's speed, quietly - every take starts the same

import { log } from '../owlosui/apps/log.js';
import { KEYS } from '../owlosui/dosbox/dosbox.js';
import { DosCm } from '../owlosui/apps/dos.js';

const sleep = ms => new Promise(r => setTimeout(r, ms));
/** The script's short key names, as KeyboardEvent calls them. */
const ALIASES = {
  down: 'ArrowDown', up: 'ArrowUp', left: 'ArrowLeft', right: 'ArrowRight', return: 'Enter', enter: 'Enter',
  esc: 'Escape', escape: 'Escape', pgdn: 'PageDown', pgup: 'PageUp', del: 'Delete', bs: 'Backspace', tab: 'Tab',
};
const DOSKEYS = { ...KEYS, space: 32, y: 89, n: 78, '1': 49, '2': 50, '3': 51, '6': 54, up: 265, down: 264, left: 263, right: 262 };
/** A script's DOS key name as js-dos's code: a letter is its capital's ASCII. */
const dosCode = k => DOSKEYS[k.toLowerCase()] ?? k.toUpperCase().charCodeAt(0);

/** The script: [{ say, actions: [[name, args]] }], and the actions before the first say. */
export function parse(text) {
  const steps = [];
  const before = [];
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (/^say\s/i.test(line)) steps.push({ say: line.slice(4).trim(), actions: [] });
    const m = /^;@\s*(\S+)\s*(.*)$/.exec(line);
    if (m) (steps.length ? steps[steps.length - 1].actions : before).push([m[1].toLowerCase(), m[2]]);
  }
  return { steps, before };
}

export class Tour {
  constructor(app, name) {
    this.app = app;
    this.owl = app.owl;
    this.name = name;
    this.base = new URL(`tour/${name}`, import.meta.url);
    // read now: opening a lesson rewrites the address, ?tourshots and all
    this.shots = new URLSearchParams(location.search).has('tourshots');
  }

  async start() {
    const r = await fetch(`${this.base}.txt`);
    if (!r.ok) throw new Error(`no tour script at ${this.base}.txt`);
    this.script = parse(await r.text());
    log.info('tour', `${this.name}: ${this.script.steps.length} says`);
    await this.clickToStart();
    for (const a of this.script.before) await this.act(a);
    // ?tourshots: a contact sheet of the DOS picture every 3 s, shown at the
    // end - to check a whole take without watching it.
    // A WATCHDOG ON THE EMULATOR. js-dos sometimes stands still on its own -
    // its cycle count stops while the page is plainly visible - and only
    // ci.resume() starts it again (measured 2026-10-05: 4.3 million cycles
    // for forty seconds, then 94 million three seconds after a resume). In a
    // take that is a frozen picture under the narration, so: every 3 s, if
    // the page is visible and the count has not moved, resume it.
    let lastCycles = -1;
    const watchdog = setInterval(async () => {
      const ci = this.app.dos.box.ci;
      if (!ci || document.hidden) { lastCycles = -1; return; }
      const c = (await ci.asyncifyStats?.().catch(() => null))?.cycles ?? -1;
      if (c >= 0 && c === lastCycles) { log.warn('tour', 'the DOS PC stood still: resumed'); ci.resume(); }
      lastCycles = c;
    }, 3000);
    const sheet = this.shots ? [] : null;
    let saying = 0;
    const shooter = sheet && setInterval(async () => {
      const im = await this.app.dos.box.ci?.screenshot().catch(() => null);
      if (!im) return;
      const c = document.createElement('canvas');
      c.width = im.width; c.height = im.height;
      c.getContext('2d').putImageData(im, 0, 0);
      sheet.push({ say: saying, url: c.toDataURL('image/jpeg', 0.6) });
    }, 3000);
    for (const [i, step] of this.script.steps.entries()) {
      saying = i + 1;
      log.info('tour', `say ${i + 1}: ${step.say.slice(0, 70)}`);
      const spoken = this.speak(i);
      for (const a of step.actions) await this.act(a);
      await spoken;
      await sleep(350);
    }
    log.info('tour', 'the end');
    clearInterval(watchdog);
    if (sheet) { clearInterval(shooter); this.showSheet(sheet); }
  }

  showSheet(sheet) {
    const d = document.createElement('div');
    d.id = 'tour-sheet';
    d.style.cssText = 'position:fixed;inset:0;z-index:30;overflow:auto;background:#111;display:flex;flex-wrap:wrap;gap:2px;align-content:flex-start';
    for (const s of sheet) {
      const f = document.createElement('figure');
      f.style.cssText = 'margin:0;width:156px;color:#ff0;font:10px monospace;position:relative';
      f.innerHTML = `<img src="${s.url}" style="width:156px;height:98px;display:block"><span style="position:absolute;left:2px;top:0;background:#000">${s.say}</span>`;
      d.append(f);
    }
    document.body.append(d);
  }

  /** A browser plays sound only after a click: the take starts on one. */
  clickToStart() {
    return new Promise(resolve => {
      const c = document.createElement('div');
      c.textContent = `Tour ${this.name} - click to start`;
      c.style.cssText = 'position:fixed;inset:0;z-index:20;display:flex;align-items:center;justify-content:center;' +
        'background:rgba(0,0,0,.6);color:#fff;font:20px monospace;cursor:pointer';
      c.onclick = () => { c.remove(); resolve(); };
      document.body.append(c);
    });
  }

  /** Narration n, playing; resolves when it has ended (or at once, with no file). */
  speak(i) {
    return new Promise(resolve => {
      // The rig numbers them from s00, one per say, in order.
      const a = new Audio(`${this.base}/s${String(i).padStart(2, '0')}.wav`);
      a.onended = resolve;
      a.onerror = () => { log.warn('tour', `no narration s${String(i).padStart(2, '0')}: silent, 3 s`); setTimeout(resolve, 3000); };
      a.play().catch(() => setTimeout(resolve, 3000));
    });
  }

  // ------------------------------------------------------------ actions

  /** A key to the page, as a person types it: keydown then keyup on the document. */
  key(spec) {
    const parts = spec.split('+');
    const key = parts.pop();
    const mods = { ctrlKey: parts.includes('ctrl'), altKey: parts.includes('alt'), shiftKey: parts.includes('shift') };
    const name = key.length === 1 ? key : ALIASES[key.toLowerCase()] ?? key[0].toUpperCase() + key.slice(1);
    for (const type of ['keydown', 'keyup']) document.dispatchEvent(new KeyboardEvent(type, { key: name, bubbles: true, cancelable: true, ...mods }));
    this.owl.refresh?.();
  }

  async keys(list, pace = 140) {
    // A build F9 starts is the one `waitbuild` waits for: counted before the key.
    if (/\bF9\b/i.test(list)) this.buildMark = this.app.buildsStarted ?? 0;
    for (const k of list.split(/\s+/).filter(Boolean)) {
      const [spec, times] = k.split('*');
      const n = Number(times) || 1;
      // A long run of one key - forty lines down - goes quicker, as a held key does.
      for (let i = 0; i < n; i++) { this.key(spec); await sleep(n > 10 ? 45 : pace); }
    }
  }

  /** A cheap fingerprint of DOS's picture, to see that a key did something. */
  async screenPrint() {
    const im = await this.app.dos.box.ci?.screenshot().catch(() => null);
    if (!im) return 0;
    let h = 0;
    for (let p = 0; p < im.data.length; p += 97) h = (h * 31 + im.data[p]) | 0;
    return h;
  }

  /**
   * Keys to a DOS program's menus, one menu each: wait for the menu to stand
   * still, press, and see the picture change - a key pressed before the
   * program reads it is lost, so one that changed nothing is pressed again.
   */
  async menus(list) {
    for (const k of list.split(/\s+/).filter(Boolean)) {
      let before = await this.screenPrint();
      for (let t = 0; t < 4000; t += 600) {            // still for a moment: the menu is up
        await sleep(600);
        const now = await this.screenPrint();
        if (now === before) break;
        before = now;
      }
      for (let tries = 0; tries < 3; tries++) {
        await this.dosKeys(k);
        let changed = false;
        for (let t = 0; t < 6000 && !changed; t += 500) { await sleep(500); changed = (await this.screenPrint()) !== before; }
        if (changed) break;
        log.info('tour', `${k} changed nothing: again`);
      }
    }
  }

  async type(text) {
    for (const ch of text) {
      this.key(ch === ' ' ? ' ' : ch);
      await sleep(70 + Math.random() * 90);       // a person's pace, never even
    }
  }

  async dosKeys(list) {
    const ci = this.app.dos.box.ci;
    if (!ci) return;
    for (const k of list.split(/\s+/).filter(Boolean)) {
      const code = dosCode(k);
      ci.sendKeyEvent(code, true); await sleep(120); ci.sendKeyEvent(code, false); await sleep(250);
    }
  }

  /** Keys held down together in DOS for a while - a throttle, a stick: `w+a 3000`. */
  async hold(args) {
    const ci = this.app.dos.box.ci;
    const [list, ms] = args.split(/\s+/);
    if (!ci || !list) return;
    const codes = list.split('+').map(dosCode);
    for (const c of codes) ci.sendKeyEvent(c, true);
    await sleep(Number(ms) || 1000);
    for (const c of codes) ci.sendKeyEvent(c, false);
    await sleep(150);
  }

  async until(test, ms = 90000, what = 'it') {
    for (let t = 0; t < ms; t += 250) { if (test()) return true; await sleep(250); }
    log.warn('tour', `waited ${ms / 1000} s for ${what}: going on`);
    return false;
  }

  frontWindow(which) {
    const app = this.app;
    const id = {
      editor: [...app.docs.keys()].at(-1), dos: app.dos.win, video: app.video?.win, build: app.buildWin,
      commander: app.commander.right?.win ?? app.commander.left?.win,
    }[which];
    if (id) this.owl.activate(id);
    this.owl.refresh?.();
  }

  async act([name, args]) {
    const app = this.app, owl = this.owl;
    try {
      switch (name) {
        case 'wait': await sleep(Number(args) || 1000); break;
        case 'keys': await this.keys(args); break;
        case 'type': await this.type(args); break;
        case 'front': this.frontWindow(args.trim()); break;
        case 'find': {
          const doc = app.docs.get(owl.active());
          if (doc) owl.find(doc.text, args);
          owl.refresh?.();
          break;
        }
        case 'waitbuild': {
          // FASM's answer to a build that started after the key: counted, not
          // read - a rebuild can answer in the very words of the last one (a
          // colour changes no size), and the Build strip may still show it.
          const started = this.buildMark ?? app.buildsStarted ?? 0;
          this.buildMark = undefined;
          await this.until(() => (app.buildsStarted ?? 0) > started && (app.buildsAnswered ?? 0) > started, 90000, 'the build');
          break;
        }
        case 'waitlog': {
          const re = new RegExp(args, 'i'), from = log.lines.length;
          await this.until(() => log.lines.slice(from).some(l => re.test(l)), 120000, args);
          break;
        }
        case 'doskeys': await this.dosKeys(args); break;
        case 'hold': await this.hold(args); break;
        case 'menus': await this.menus(args); break;
        case 'grab': app.dos.box.grab(); break;
        case 'release': app.dos.box.release(); break;
        case 'commander': app.onCommand(6); break;
        case 'closecommander':
          for (const s of [app.commander.left, app.commander.right]) if (s?.win) app.commander.closeWindow(s.win);
          owl.refresh?.();
          break;
        case 'cmdto': {
          const want = args.trim().toUpperCase();
          const side = [app.commander.left, app.commander.right].find(s => s && s.win === owl.active()) ?? app.commander.left;
          // From the top, as a person who knows where the name is: `..`
          // is first, and Down alone would never come back to it.
          if ((owl.markedNames(side.files)[0] ?? '').toUpperCase() !== want) { this.key('Home'); await sleep(150); }
          for (let n = 0; n < 80; n++) {
            const [here] = owl.markedNames(side.files);
            if ((here ?? '').toUpperCase() === want) break;
            this.key('ArrowDown'); await sleep(110);
          }
          break;
        }
        case 'settings': app.dos.showSettings(Number(args) || 0); owl.refresh?.(); break;
        case 'click': {
          const p = owl.place(owl.active());
          const [x, y] = args.split(/\s+/).map(Number);
          if (p) { owl.mouse(0, p.x + x, p.y + y); await sleep(90); owl.mouse(1, p.x + x, p.y + y); }
          owl.refresh?.();
          break;
        }
        case 'cmd': app.onCommand(Number(args)); break;
        case 'fly': {
          // OWL FLY's front screens - video system, detail, sound, title -
          // take an Enter each, but a key sent before the game reads it is
          // lost, and on a slow DOS PC the game takes long to get there. So
          // Enter, every two seconds, until the picture is the cockpit:
          // 320x200 and most of it lit. The title is 320x200 too, and
          // moves, but it is drawn on black.
          //
          // OWL FLY III opens in the WATCHING seat - "HOLDING, PRESS ENTER
          // TO JOIN", the world lit and turning - and only sometimes does an
          // early Enter join it straight away. So one more Enter at the end,
          // always: from the watching seat it takes a jet, in a jet it is
          // the lock key and harmless. Either way: the cockpit, on the
          // concrete, brakes on (B, W, A take off).
          const box = app.dos.box;
          const limit = Date.now() + (Number(args) || 60) * 1000;
          while (Date.now() < limit) {
            await sleep(2000);
            const im = box.frameSize?.w === 320 ? await box.ci?.screenshot().catch(() => null) : null;
            let lit = 0;
            if (im) for (let p = 0; p < im.data.length; p += 16) if (im.data[p] + im.data[p + 1] + im.data[p + 2] > 60) lit++;
            if (im && lit / (im.data.length / 16) > 0.4) {
              await sleep(1500);
              await this.dosKeys('enter');
              log.info('tour', 'in the cockpit');
              break;
            }
            await this.dosKeys('enter');
          }
          break;
        }
        // Every take starts the same: a lesson's files as shipped, the DOS
        // PC's speed as a first visit has it. Neither shows on the screen.
        case 'fresh': {
          const l = app.course.lessons.find(x => x.id === args.trim());
          if (l) await app.install(l, true);
          break;
        }
        case 'speed': {
          app.dos.settings = { ...app.dos.settings, cycles: args.trim() };
          try { localStorage.setItem(app.dos.settingsKey, JSON.stringify(app.dos.settings)); } catch { /* this visit only */ }
          break;
        }
        case 'waitred':
        case 'waitnored': {
          // Until something RED is on the DOS picture inside a box - a
          // program's own warning, like lesson 18's STALL. Live physics on a
          // random island cannot be timed in milliseconds; the picture says
          // when. Args: X0 Y0 X1 Y1 in the program's pixels, then seconds.
          const [x0, y0, x1, y1, s] = args.trim().split(/\s+/).map(Number);
          const limit = Date.now() + (s || 20) * 1000;
          while (Date.now() < limit) {
            const im = await app.dos.box.ci?.screenshot().catch(() => null);
            let red = 0;
            if (im) for (let y = y0; y < Math.min(y1, im.height); y++) for (let x = x0; x < Math.min(x1, im.width); x++) {
              const p = (y * im.width + x) * 4;
              if (im.data[p] > 150 && im.data[p + 1] < 90 && im.data[p + 2] < 90) red++;
            }
            if ((red > 4) === (name === 'waitred')) { log.info('tour', name === 'waitred' ? 'red on the screen' : 'the red is gone'); break; }
            await sleep(250);
          }
          break;
        }
        case 'lesson': {
          // A lesson opened the way the list opens it: source, video, build.
          // The F9 counters are marked first, so a `waitbuild` after this
          // waits for THIS build and not the last one.
          const l = app.course.lessons.find(x => x.id === args.trim());
          this.buildMark = app.buildsStarted ?? 0;
          if (l) await app.openLesson(l);
          break;
        }
        case 'run': {
          // A program on the course disk, run as the commander's Enter runs
          // it: a lesson's .COM or .EXE at the lessons' speed, then a key.
          const [folder, file] = args.trim().split(/\s+/);
          await app.runFile(app.browser, `/DOS A Drive/LESSONS/${folder}/`, file);
          break;
        }
        case 'game': {
          const i = app.dos.pageStarts.indexOf(args.trim());
          if (i >= 0) app.onCommand(DosCm.Start + i);
          break;
        }
        default: log.warn('tour', `unknown action ${name}`);
      }
    } catch (e) {
      log.warn('tour', `${name} ${args}: ${e.message}`);
    }
  }
}
