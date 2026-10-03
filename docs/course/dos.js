// The course's DOS PC: DOSBox in WebAssembly (js-dos), in an OWLOSUI window.
//
// Built on OWLOSUI's library only (../owlosui/dosbox/): DosBox lays the
// emulator's picture over a window, DriveGates makes two folders of this
// browser's storage into floppies A: and B: - what the page writes there DOS
// finds, and what DOS writes there the page gets back within a couple of
// seconds. That is the whole road between the editor and DOS: the lesson's
// files are written to "DOS A Drive", BUILD.BAT runs FASM there, and
// BUILD.TXT comes back.
//
// Every run is a fresh boot with one line in its AUTOEXEC - the batch file
// to call - so a lesson starts from a clean machine each time.


import { DosBox } from '../owlosui/dosbox/dosbox.js';
import { DriveGates } from '../owlosui/dosbox/gates.js';
import { log, describe } from './log.js';

const GATES = [{ letter: 'A', folder: '/DOS A Drive/' }, { letter: 'B', folder: '/DOS B Drive/' }];
const crlf = s => s.replace(/\r?\n/g, '\r\n');

/** A promise, or TIMEOUT if it has not settled in `ms`: for anything that asks the emulator. */
const TIMEOUT = Symbol('timeout');
const within = (promise, ms) => Promise.race([promise, new Promise(r => setTimeout(() => r(TIMEOUT), ms))]);

/**
 * The machine, and why each line is what it is:
 *   core=normal    on `auto` this DOSBox takes its dynamic core in protected
 *                  mode, and FASM dies there on its first macro - every
 *                  course source is macros, through E_8086.INC
 *   cycles=auto    FASM runs in protected mode, where `auto` is full speed:
 *                  HOUSES.ASM in under a second. A lesson is then slowed to
 *                  the machine it was made on by GO.BAT (course.js)
 *   xms=true       CWSDPMI, which FASM needs, takes its memory from XMS
 *   no network     the course needs none
 */
function conf(line) {
  return crlf(`[sdl]
autolock=false
[dosbox]
machine=svga_s3
memsize=16
[cpu]
core=normal
cputype=auto
cycles=auto
[mixer]
rate=44100
[sblaster]
sbtype=sb16
[speaker]
pcspeaker=true
[dos]
xms=true
ems=true
umb=true
[ipx]
ipx=false
[autoexec]
@echo off
mount c C
mount a A -t floppy
mount b B -t floppy
path B:\\;Z:\\
${line}
`);
}

/** Drive C: holds only a word on where things are. */
const DRIVE_C = [{
  path: 'C/README.TXT',
  contents: new TextEncoder().encode(crlf(`
  This PC runs in your browser: DOSBox, compiled to WebAssembly.

    A:\\LESSONS\\Lnn   each lesson you opened: its source, BUILD.BAT, GO.BAT
    A:\\ENGINE         the engine files the later lessons include
    B:\\               FASM and CWSDPMI

  A: and B: are folders of this browser's storage. Right Ctrl gives the
  keyboard back to the page.
`)),
}];

export class CourseDos {
  /** storage: the BrowserStorage the floppies live in. closeCmd: what the window's close box sends. */
  constructor(owl, storage, { closeCmd = 0 } = {}) {
    this.owl = owl;
    this.storage = storage;
    this.closeCmd = closeCmd;
    this.box = new DosBox(owl);
    this.gates = new DriveGates(this.box, storage, GATES);
    this.win = 0;
    this.what = '';
    this.box.on((what, box, detail) => {
      if (what === 'keys') this.retitle();
      if (what === 'stopped') this.retitle();
      if (what === 'frame') log.info('dos', `picture ${box.frameSize.w}x${box.frameSize.h}`);
      if (what === 'stdout') log.info('dos out', detail.replace(/\s+$/, ''));
      // DOSBox's own [LOG_...] lines arrive as errors; they are its diary.
      if (what === 'message') log[/^\s*\[LOG_/.test(detail.text) || detail.type !== 'error' ? 'info' : 'error']('dos', detail.text.replace(/\s+$/, ''));
    });
    // What DOS wrote to a floppy, into its folder.
    if (typeof setInterval !== 'undefined') setInterval(() => this.pull(), 1500);
    // js-dos sometimes dies - `RuntimeError: unreachable`, seen right after
    // FASM's banner, cause not found - and a dead one never answers again.
    // It is noticed here, said, and the next run starts a fresh machine.
    this.crashed = false;
    this.onCrash = () => {};
    if (typeof window !== 'undefined') {
      window.addEventListener('error', e => {
        if (!/unreachable/.test(String(e.message ?? e.error)) || !this.box.running) return;
        this.crashed = true;
        log.error('dos', 'js-dos crashed (RuntimeError: unreachable); the next run starts a fresh machine');
        this.retitle();
        this.onCrash();
      });
    }
    // js-dos 8 listens for keys on the whole WINDOW, not on its picture, so
    // without this every key typed in the editor went to DOS as well
    // (measured 2026-10-03: three Downs in the editor, three Downs in DOS).
    // OWLOSUI hears keys on `document`, a step before the window: there a
    // key is stopped unless DOS has the focus. A key that went down while
    // DOS had it is still let up, so nothing stays held in DOS.
    if (typeof document !== 'undefined') {
      const held = new Set();
      const gate = e => {
        if (this.box.hasKeys()) {
          if (e.type === 'keydown') held.add(e.code); else held.delete(e.code);
          return;
        }
        if (e.type === 'keyup' && held.delete(e.code)) return;
        e.stopPropagation();
      };
      document.addEventListener('keydown', gate);
      document.addEventListener('keyup', gate);
    }
  }

  owns(id) { return id !== 0 && id === this.win; }

  /** The window, at rect { x, y, w, h } in cells; one already open elsewhere is closed first. */
  openWindow(rect) {
    const owl = this.owl;
    if (this.win) owl.close(this.win);
    this.win = owl.window('DOS', rect.w, rect.h, { x: rect.x, y: rect.y, closeCmd: this.closeCmd });
    owl.staticText(this.win, 2, 1, 'The DOS PC is switching on. Its picture lies over this window, and is taken away ' +
      'while a menu or another window is over it - DOS keeps running.', rect.w - 6, 4);
    owl.windowStatus(this.win, { label: '~Right Ctrl~ Keys back', cmd: 0 });
    this.retitle();
  }

  retitle() {
    if (!this.win) return;
    const state = this.crashed ? ' (crashed)' : !this.box.running ? ' (off)' : this.box.hasKeys() ? ' - keys in DOS' : '';
    this.owl.setText(this.win, `DOS: ${this.what || 'off'}${state}`);
    this.owl.refresh?.();
  }

  /**
   * Switch on and call `name` - a .BAT in `dir`, a folder of a floppy
   * ("/DOS A Drive/LESSONS/L03/"). The keyboard goes to DOS.
   */
  async run(dir, name) {
    const at = this.gates.dosPath(`${dir}${name}`);
    if (!at) throw new Error(`${dir}${name} is not on a floppy`);
    const folder = at.slice(0, at.lastIndexOf('\\'));
    const line = [folder.slice(0, 2), `cd ${folder.slice(2) || '\\'}`, `call ${name.toUpperCase()}`].join('\n');
    this.what = name.toUpperCase();
    log.info('dos', `switching on: ${line.replace(/\n/g, ' | ')}`);
    try {
      // What DOS saved in its last moments goes into the folders first;
      // the folders are then the disks of the PC switching on. Both steps
      // talk to the old machine, and a crashed js-dos never answers - so
      // each has a time limit, and a machine that does not stop is dropped:
      // its picture taken off the page, a new one started in its place.
      if (!this.crashed && await within(this.gates.pull().catch(() => {}), 3000) === TIMEOUT) log.warn('dos', 'the old machine did not give its floppies back');
      const old = this.box.el;
      if (await within(this.box.stop(), 3000) === TIMEOUT) {
        log.warn('dos', 'the old machine did not switch off: dropped');
        old?.remove();
      }
      this.crashed = false;
      this.pulling = false;      // a pull stuck on the old machine is forgotten
      const files = [...DRIVE_C.map(f => ({ path: f.path, contents: f.contents.slice() })), ...(await this.gates.files())];
      // 'fill': the picture as big as the window, at 4:3. DosBox's 'sharp'
      // takes only whole multiples of the frame, and a window a few pixels
      // short of 400 showed 320x200 at x1, a stamp in a black field (the
      // pilot, 2026-10-03). The pixels stay blocks, not blur: course.css.
      await this.box.start(this.win, { conf: conf(line), files, what: this.what, keepRunning: true, picture: 'fill' });
      await this.gates.started();
      this.box.grab();
    } catch (e) {
      log.error('dos', `did not start: ${describe(e)}`);
      this.owl.messageBox('DOS', `The DOS PC did not start: ${e.message}`, { label: '~O~K', cmd: 0, default: true });
    }
    this.retitle();
  }

  async pull() {
    if (!this.box.running || this.pulling || this.crashed) return;
    this.pulling = true;
    try {
      const got = await within(this.gates.pull(), 10000);
      if (got === TIMEOUT) log.warn('files', 'the DOS PC did not answer for its floppies in 10 s');
      else if (got) log.info('files', 'DOS wrote to a floppy: the folder in this browser has it now');
    } catch { /* switching off */ }
    this.pulling = false;
  }

  /** The window closes and the PC is switched off with it. */
  async close() {
    if (this.win) this.owl.close(this.win);
    this.win = 0;
    this.what = '';
    await this.box.stop();
  }
}

