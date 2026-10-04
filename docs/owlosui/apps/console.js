// Tools > Console: the page's log in a window - a terminal, black, coloured
// by the ANSI sequences in each line - from the first moment of the visit,
// not from when the window was opened. For a bug report: open it, F4 for
// the state of everything now, then Ctrl+C or F2, and paste. The mouse
// selects, dragged with its button down; a right click is Copy and Select
// all - the core's own, as in every console.

import { Style } from '../owlosui.js';
import { log } from './log.js';

const Cm = { Close: 430, State: 431, Save: 432, Copy: 433, Clear: 434 };

/** The record without its colours: what a paste or a file wants. */
const plain = s => s.replace(/\x1b\[[0-9;:?]*[ -/]*[@-~]/g, '');

export class ConsoleWindow {
  static CmFirst = 430;
  static CmLast = 439;

  /** state(): the lines F4 adds - what the page, DOS and the network are doing now. */
  constructor(owl, { state }) {
    this.owl = owl;
    this.state = state;
    this.win = 0;
    this.view = 0;
    this.queue = [];
    this.unlisten = null;
  }

  handles(cmd) { return cmd >= ConsoleWindow.CmFirst && cmd <= ConsoleWindow.CmLast; }
  owns(id) { return id !== 0 && id === this.win; }
  poll() {}

  show() {
    const owl = this.owl;
    if (this.win) { owl.activate(this.win); return; }
    const w = Math.min(110, owl.width - 2), h = Math.max(10, owl.height - 4);
    // Black, frame and all: the window is the colour of what is in it, as a
    // document's is its blue.
    this.win = owl.window('Console', w, h, { style: Style.Terminal, closeCmd: Cm.Close });
    this.view = owl.console(this.win, { scrollback: 2000 });
    owl.consoleWrite(this.view, log.text());
    // Written a moment later, not inside whatever is logging: a line can
    // come from the middle of a call into the core, and the core is not
    // asked a second thing while it is answering the first.
    this.unlisten = log.listen(line => {
      this.queue.push(line);
      if (this.queue.length === 1) setTimeout(() => this.flush(), 0);
    });
    // Short, beside the desktop's own keys on one line; F8 is a key with no
    // words, said in the Console menu instead. Ctrl+C is the console's own:
    // it copies what the mouse selected, or everything when nothing is,
    // and the page carries it to the computer's clipboard.
    owl.windowStatus(this.win,
      { label: '~F4~ State', cmd: Cm.State, key: 'F4' },
      { label: '~Ctrl+C~ Copy', cmd: 0 },
      { label: '~F2~ Save', cmd: Cm.Save, key: 'F2' },
      { label: '', cmd: Cm.Clear, key: 'F8' });
    owl.windowMenu(this.win, {
      label: '~C~onsole', items: [
        { label: '~S~tate now', cmd: Cm.State, shortcut: 'F4', hint: 'What the page, the DOS PC and the network are doing, written into the console' },
        { label: '~C~opy all', cmd: Cm.Copy, hint: 'The whole console as text, for a bug report; Ctrl+C copies what the mouse selected' },
        { label: 'Sa~v~e as a file', cmd: Cm.Save, shortcut: 'F2', hint: 'The whole console, downloaded as a .txt file' },
        { label: 'C~l~ear', cmd: Cm.Clear, shortcut: 'F8', hint: 'Empty the window; the page goes on recording' },
      ],
    });
    owl.activate(this.win);
  }

  flush() {
    if (!this.view) { this.queue = []; return; }
    const text = this.queue.join('');
    this.queue = [];
    this.owl.consoleWrite(this.view, text);
    this.owl.refresh?.();
  }

  onCommand(cmd) {
    switch (cmd) {
      case Cm.Close: return this.close();
      case Cm.State: return this.writeState();
      case Cm.Copy: return this.copy();
      case Cm.Save: return this.save();
      case Cm.Clear:
        this.owl.consoleWrite(this.view, '\x1b[2J');
        return null;
    }
    return null;
  }

  async writeState() {
    log.info('state', '--- the state now ---');
    try {
      for (const line of await this.state()) log.info('state', line);
    } catch (e) {
      log.error('state', `could not be gathered: ${e?.message ?? e}`);
    }
  }

  /** The whole console, as the core keeps it, without colours. */
  text() { return plain(this.owl.getText(this.view)); }

  async copy() {
    const text = this.text();
    try {
      await navigator.clipboard.writeText(text);
      log.info('console', `copied: ${text.split('\n').length} lines - paste them into the bug report`);
    } catch (e) {
      log.warn('console', `the browser would not copy (${e?.message ?? e}); F2 saves the same text as a file`);
    }
  }

  save() {
    const d = new Date(), p = n => String(n).padStart(2, '0');
    const name = `owlosui-console-${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}.txt`;
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([this.text().replace(/\n/g, '\r\n')], { type: 'text/plain' }));
    a.download = name;
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
    log.info('console', `saved as ${name}`);
  }

  close() {
    this.unlisten?.();
    this.unlisten = null;
    if (this.win) this.owl.close(this.win);
    this.win = 0;
    this.view = 0;
  }

  closeWindow() { return this.close(); }
}
