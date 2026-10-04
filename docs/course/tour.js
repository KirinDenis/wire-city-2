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
//   grab | release           the keyboard to DOS, or back
//   commander                Tools > Commander
//   cmdto NAME               Down in the commander's panel until NAME is under the cursor
//   settings PAGE            DOS > Settings on page PAGE (0 Machine, 1 CPU...)
//   click X Y                a click in the front window, X Y inside it, in cells
//   cmd N                    a command by number
//   game KEY                 a game from the DOS menu (owlfly, owlfly2, owlfly3)
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
  }

  async start() {
    const r = await fetch(`${this.base}.txt`);
    if (!r.ok) throw new Error(`no tour script at ${this.base}.txt`);
    this.script = parse(await r.text());
    log.info('tour', `${this.name}: ${this.script.steps.length} says`);
    await this.clickToStart();
    for (const a of this.script.before) await this.act(a);
    for (const [i, step] of this.script.steps.entries()) {
      log.info('tour', `say ${i + 1}: ${step.say.slice(0, 70)}`);
      const spoken = this.speak(i);
      for (const a of step.actions) await this.act(a);
      await spoken;
      await sleep(350);
    }
    log.info('tour', 'the end');
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
    for (const k of list.split(/\s+/).filter(Boolean)) {
      const [spec, times] = k.split('*');
      for (let n = 0; n < (Number(times) || 1); n++) { this.key(spec); await sleep(pace); }
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
      const code = DOSKEYS[k.toLowerCase()] ?? k.toUpperCase().charCodeAt(0);
      ci.sendKeyEvent(code, true); await sleep(120); ci.sendKeyEvent(code, false); await sleep(250);
    }
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
          const from = app.lastBuildShown ?? '';
          await this.until(() => app.lastBuildShown !== from && /bytes\.|error|crashed/i.test(app.lastBuildShown ?? ''), 90000, 'the build');
          break;
        }
        case 'waitlog': {
          const re = new RegExp(args, 'i'), from = log.lines.length;
          await this.until(() => log.lines.slice(from).some(l => re.test(l)), 120000, args);
          break;
        }
        case 'doskeys': await this.dosKeys(args); break;
        case 'grab': app.dos.box.grab(); break;
        case 'release': app.dos.box.release(); break;
        case 'commander': app.onCommand(6); break;
        case 'cmdto': {
          const want = args.trim().toUpperCase();
          const side = [app.commander.left, app.commander.right].find(s => s && s.win === owl.active()) ?? app.commander.left;
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
