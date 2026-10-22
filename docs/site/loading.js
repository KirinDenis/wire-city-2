// The box a visit opens on while the site gets ready: what it is doing, a
// bar and its percent (2026-10-22, testers through the pilot: the site
// opened, the DOS disks loaded and were put together, and only then did the
// game's menu come - with nothing on the screen saying what was going on).
// It comes up as soon as the screen can paint, if the start is not over by
// then, and goes by itself when what the address asked for is there: the
// catalog, a lesson, a page's windows, a game or a demo running in DOS.
//
// The bar is honest where the work can be counted - drive C:'s files, one
// by one - and creeps where it cannot (the course disk coming down, DOSBox
// switching on): toward the end of its stage, slower the nearer it gets,
// and never there before the stage is done.

import { Style } from '../owlosui/owlosui.js';

/** A start over sooner than this, in ms, shows no box: one that flashes up and is gone is worse than none. */
const LATE = 600;
/** The box's width in cells; the bar's steps, ten to a percent. */
const W = 56, STEPS = 1000;
/** How often the bar creeps, in ms, and how much of what is left of its stage it takes each time: half in 3.4 s. */
const CREEP_MS = 200, CREEP = 0.04;
/** The longest the box waits for anything, in ms: then it goes, whatever is late. */
const GIVE_UP = 180000;

export class Loading {
  constructor(owl) {
    this.owl = owl;
    this.win = 0;
    this.text = 'The site is getting ready...';
    this.at = 0;            // where the bar is, 0..STEPS
    this.from = 0;          // where this stage began
    this.to = 0;            // ...and where it ends
    this.creeping = false;
    this.over = false;
    this.done = new Promise(resolve => { this.finished = resolve; });     // the start is over: what waits for it goes now
  }

  /**
   * The start begins. The box comes up when `screen` (a promise: the canvas
   * has its size) and LATE have both come, unless it is over by then. box:
   * the DOS PC's - the box goes when it is on (or has crashed), BEFORE the
   * DOS PC takes the keyboard: a window over the DOS window takes the keys
   * back from it (DosBox.layout).
   */
  begin(screen, box) {
    Promise.all([screen, new Promise(r => setTimeout(r, LATE))]).then(() => this.show());
    this.timer = setInterval(() => this.creep(), CREEP_MS);
    this.giveUp = setTimeout(() => this.end(), GIVE_UP);
    this.unhear = box.on(what => { if (what === 'started' || what === 'crashed') this.end(); });
  }

  /** A stage: its words, and the part of the bar it fills, in percent. creep: its work cannot be counted. */
  stage(text, from, to, { creep = false } = {}) {
    if (this.over) return;
    this.text = text;
    this.at = Math.max(this.at, from * 10);
    this.from = this.at;
    this.to = to * 10;
    this.creeping = creep;
    this.paint(true);
  }

  /** So much of the stage done: `done` of `total`. */
  part(done, total) {
    if (this.over || !total) return;
    this.at = Math.max(this.at, Math.round(this.from + ((this.to - this.from) * done) / total));
    this.paint();
  }

  /** A creeping stage a step nearer its end - to a percent short of it: the last percent is the work's own. */
  creep() {
    if (this.over || !this.creeping) return;
    const left = this.to - 10 - this.at;
    if (left <= 0) return;
    this.at += Math.max(1, Math.round(left * CREEP));
    this.paint();
  }

  /**
   * The DOS PC switching on - `run`, its run's promise, called the moment
   * its window opened in front: the box in front of it again, and gone when
   * the run is over, the machine on or not.
   */
  machine(run) {
    if (this.over) return;
    if (this.shown()) {
      this.owl.activate(this.win);
      this.owl.refresh?.();
    }
    run.finally(() => this.end());
  }

  /** The site is ready: the box closes, and nothing brings it back. */
  end() {
    if (this.over) return;
    this.over = true;
    clearInterval(this.timer);
    clearTimeout(this.giveUp);
    this.unhear?.();
    if (this.shown()) {
      this.owl.close(this.win);
      this.owl.refresh?.();
    }
    this.win = 0;
    this.finished();
  }

  show() {
    if (this.over || this.win) return;
    // The longest words are about 64 letters: two lines where they fit, three on a phone's screen.
    const owl = this.owl, w = Math.min(W, owl.width - 2), lines = w - 6 >= 48 ? 2 : 3;
    this.win = owl.window('WIRE CITY 86', w, lines + 6, { style: Style.Dialog, minimize: false });
    this.words = owl.staticText(this.win, 2, 1, this.text, w - 6, lines);
    this.bar = owl.progress(this.win, 2, lines + 2, w - 6, STEPS);
    this.paint(true);
  }

  /** The box is there - a person may have closed it: then it stays closed. */
  shown() { return !!this.win && !!this.owl.place(this.win); }

  paint(words = false) {
    if (!this.shown()) return;
    if (words) this.owl.setText(this.words, this.text);
    this.owl.setProgress(this.bar, this.at);
    this.owl.refresh?.();
  }
}
