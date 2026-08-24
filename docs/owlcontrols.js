// owlcontrols.js - the flight controls every OWL FLY page shares: the
// touch stick and buttons over the picture, and the switch panel js-dos
// opens from its side menu.
//
// WHY THIS FILE EXISTS. All of it lived inside owlfly2.html, and OWL FLY III
// was forked from the GAME, not from the page - so the third one shipped
// with no controls at all and nobody noticed until it was published. One
// copy, three pages: a fix or a new switch now lands on all of them, and a
// fourth OWL FLY starts with hands already on it.
//
// EVERYTHING IS INSIDE THIS FUNCTION, and that is not tidiness. A page
// script shares the global lexical scope with the minified js-dos.js, which
// declares its own short names there - a plain `const K` collided with one,
// the whole page script failed to parse, and the emulator never started at
// all. One name leaves here: OwlControls.

// ---- the heartbeat shim (2026-08-25). js-dos paces the emulator on
// requestAnimationFrame, and a hidden or fully covered tab stops rAF
// COLD: the jet freezes, its position broadcasts stop, and five silent
// seconds later every other pilot watches it vanish - then reappear on
// refocus (the "planes flap in and out" report; the squadron was
// alt-tabbing to the messenger between passes). This wraps rAF in a
// race against a plain timer: on a visible page rAF wins every frame
// and NOTHING changes; hidden, the browser throttles the timer to
// about one fire a second - a slideshow, but one position a second
// keeps the pilot on the wire (the ghost sweep needs five of silence).
// This file must load BEFORE js-dos.js, and the pages do so.
(function () {
  var raf = window.requestAnimationFrame.bind(window);
  var caf = window.cancelAnimationFrame.bind(window);
  var seq = 1, live = {};
  window.requestAnimationFrame = function (cb) {
    var key = seq++;
    var fire = function (ts) {
      var e = live[key];
      if (!e) return;
      delete live[key];
      caf(e.r); clearTimeout(e.t);
      cb(ts);
    };
    live[key] = {
      r: raf(fire),
      t: setTimeout(function () { fire(performance.now()); }, 250)
    };
    return -key;              // negative: never collides with a real rAF id
  };
  window.cancelAnimationFrame = function (id) {
    if (id < 0) {
      var e = live[-id];
      if (e) { delete live[-id]; caf(e.r); clearTimeout(e.t); }
      return;
    }
    caf(id);
  };
})();

(function (root) {

  // ---- the layer's own CSS, injected rather than copied into three pages.
  // left/top/width/height are written by the mount below: the layer is laid
  // exactly over the CANVAS, not over its box. The box is 16/10 or 4/3 and
  // the picture inside it is letterboxed, so anchoring to the box puts the
  // buttons on the black margin under the aeroplane.
  //
  // The #dos.kb rule is the phone again: js-dos puts its switch panel INSIDE
  // the box, under the picture. Measured on a 375-pixel screen: a 294-pixel
  // panel in a 225-pixel box, so the sky disappears behind the switches. The
  // box has to grow while the panel is open - and only while it is open, or
  // a closed panel leaves half a screen of black. watchPanel() does that.
  var CSS =
    ".owl-touch{position:absolute;z-index:1000;pointer-events:none;" +
    "font-family:monospace;-webkit-user-select:none;user-select:none}" +
    ".owl-touch *{touch-action:none;-webkit-tap-highlight-color:transparent}" +
    ".owl-pad{position:absolute;right:2%;bottom:3%;display:grid;" +
    "grid-template-columns:repeat(3,auto);gap:5px}" +
    ".owl-btn{pointer-events:auto;display:flex;align-items:center;" +
    "justify-content:center;height:19%;min-height:38px;aspect-ratio:1;" +
    "box-sizing:border-box;border:1px solid rgba(255,255,255,.55);" +
    "border-radius:8px;background:rgba(255,255,255,.16);color:#fff;" +
    "font-size:9px;letter-spacing:.5px;text-shadow:0 1px 2px #000}" +
    ".owl-btn.on{background:rgba(255,255,255,.5);border-color:#fff}" +
    ".owl-btn.gap{visibility:hidden;pointer-events:none}" +
    ".owl-stick{position:absolute;left:3%;bottom:3%;height:42%;min-height:84px;" +
    "aspect-ratio:1;pointer-events:auto;border-radius:50%;" +
    "background:rgba(255,255,255,.16);border:1px solid rgba(255,255,255,.5)}" +
    ".owl-knob{position:absolute;left:50%;top:50%;width:44%;height:44%;" +
    "margin-left:-22%;margin-top:-22%;border-radius:50%;" +
    "background:rgba(255,255,255,.5);pointer-events:none}" +
    "@media (max-width:820px){#dos.kb{aspect-ratio:auto;height:min(80vh,600px)}}";

  var styled = false;
  function style() {
    if (styled) return;
    styled = true;
    var s = document.createElement("style");
    s.textContent = CSS;
    document.head.appendChild(s);
  }

  // ---- the phone: what the switches are called, and where they live.
  //
  // js-dos ships a generic DOS keyboard - ESC, F1-F12, the digits, a numpad.
  // Fifty-five keys, and not one of them flies this aeroplane.
  //
  // The DIVISION OF LABOUR matters more than the layout. What you hold -
  // stick, throttle, trigger - belongs on the buttons drawn over the picture,
  // which are always on screen. What you press ONCE - gear, flaps, a radio, a
  // camera - belongs here, on a panel you open, use and shut. Putting the
  // stick on a pop-up panel would mean flying blind whenever you touched it.
  //
  // So this is the SWITCHES, and nothing else. Three rows: js-dos lays the
  // first group of a row to the left, the second to the middle, the third
  // to the right.
  //
  // NO SECOND PAGE, deliberately. A `{layout}` key would buy a QWERTY board
  // and the game asks you to type nothing at all. The one keystroke that is
  // not a switch is Alt+Q, and that is two keys held with two fingers -
  // which is why they sit next to each other.
  var PANEL = [
    ["l f b",          "m z x"],
    ["g u i",          "r n v"],
    ["{f2} {f3} {f4}", "{f5} {f6} {f7}", "{alt} q"]
  ];

  // The labels. js-dos looks a key's caption up by its own token, so this
  // renames the caps without touching what is sent - `l` still sends L, it
  // just stops pretending the pilot knows that L is the landing gear.
  // Four characters is the most a cap holds before the text wraps.
  //
  // ASCII only, all of it: the packing scripts rewrite these pages with
  // Set-Content -Encoding ascii to point them at a new bundle, and a pretty
  // arrow would come back from that as a question mark.
  var CAPS = {
    l: "GEAR", f: "FLAP", b: "BRK",
    m: "MFD",  z: "ZM+",  x: "ZM-",
    g: "GND",  u: "AIR",  i: "IFF",
    r: "T-R",  n: "NGT",  v: "SND",
    "{f2}": "CPIT", "{f3}": "CHSE", "{f4}": "ORBT",
    "{f5}": "MCAM", "{f6}": "LK<", "{f7}": "LK>",
    "{alt}": "ALT", q: "Q"
  };

  // keyboard(extraRows, extraCaps) -> what Dos() wants for the side panel.
  // OWL FLY III adds a row for its front step - the card menu answers to
  // digits - without either page owning a second copy of the switches.
  function keyboard(extraRows, extraCaps) {
    var rows = PANEL.slice();
    if (extraRows) rows = rows.concat(extraRows);
    var caps = {};
    for (var k in CAPS) if (CAPS.hasOwnProperty(k)) caps[k] = CAPS[k];
    if (extraCaps) for (var e in extraCaps) if (extraCaps.hasOwnProperty(e)) caps[e] = extraCaps[e];
    return { layout: [rows], symbols: [caps] };
  }

  // ---- the flight controls on a touch screen.
  //
  // Codes are js-dos's own KBD_ table, the same numbers the physical
  // keyboard ends up sending.
  var OWLK = { UP: 265, DOWN: 264, LEFT: 263, RIGHT: 262,
               ENTER: 257, SPACE: 32, MSL: 259, BURN: 65,
               THRUP: 334, THRDN: 333, RUDL: 49, RUDR: 51 };

  // THE CAPS SAY WHAT THE GAME SAYS. Not what the switch does - what the
  // words on the screen call it. The game asks for ENTER to take a jet and
  // SPACE to take a fresh one after a crash, and a pilot on a phone should
  // not have to work out that the cannon button is also the one the death
  // screen means. So the trigger says SPACE, and the page explains that
  // SPACE is the cannon. The other way round leaves the game's own prompts
  // pointing at nothing.
  var OWLPAD = [
    ["THR+", OWLK.THRUP], ["ENTER", OWLK.ENTER], ["BURN",  OWLK.BURN],
    ["THR-", OWLK.THRDN], ["MSL",   OWLK.MSL],   ["SPACE", OWLK.SPACE],
    ["RUD<", OWLK.RUDL],  ["RUD>",  OWLK.RUDR],  null
  ];

  // A CARDINAL IS WIDER THAN A DIAGONAL, and that is the whole fix. Eight
  // equal sectors give straight-down 45 degrees, so a thumb 25 degrees off
  // centre gets a roll it did not ask for - which is exactly what flying it
  // felt like. Here a cardinal owns 60 degrees and a diagonal 30: twice the
  // room for the four you mean most, and it still tiles the circle
  // (4*60 + 4*30 = 360). You have to MEAN a diagonal to get one now.
  //
  // This is the ONE number to turn if it still feels wrong. Bigger and the
  // diagonals get harder to hit - and they are not decoration, a turn is
  // roll and pitch together. 30 is a working compromise, not a law.
  var OWLCARD = 30;
  var OWLDIRS = [
    { a:  90, k: [OWLK.UP] },              { a: 270, k: [OWLK.DOWN] },
    { a: 180, k: [OWLK.LEFT] },            { a:   0, k: [OWLK.RIGHT] },
    { a:  45, k: [OWLK.UP, OWLK.RIGHT] },  { a: 135, k: [OWLK.UP, OWLK.LEFT] },
    { a: 225, k: [OWLK.DOWN, OWLK.LEFT] }, { a: 315, k: [OWLK.DOWN, OWLK.RIGHT] }
  ];
  function pickDir(ang) {
    for (var i = 0; i < OWLDIRS.length; i++) {
      var d = OWLDIRS[i];
      var off = Math.abs(ang - d.a) % 360;
      if (off > 180) off = 360 - off;
      if (off <= (d.k.length === 1 ? OWLCARD : 45 - OWLCARD)) return d.k;
    }
    return [];
  }

  function mountTouch(ci, hostId) {
    style();
    // Fine pointers get nothing: a mouse cannot fly this and the buttons
    // would only sit on top of the instruments.
    if (!window.matchMedia("(pointer: coarse)").matches) return;
    // js-dos only builds its .emulator-mouse-overlay when ITS OWN control
    // layer is switched on, and ours replaced it - so there is nothing to
    // hang this on but the canvas's own parent, which js-dos keeps
    // position:relative for exactly this sort of thing.
    var canvas = document.querySelector("#" + (hostId || "dos") + " canvas");
    if (!canvas) { setTimeout(function () { mountTouch(ci, hostId); }, 300); return; }
    var host = canvas.parentElement;
    if (host.querySelector(".owl-touch")) return;

    var layer = document.createElement("div");
    layer.className = "owl-touch";

    // THE CANVAS IS LOOKED UP AFRESH EVERY TIME, never held. js-dos replaces
    // the element after boot and resizes it again after that, and a
    // ResizeObserver left on the first one reported 300x150 for ever while
    // the picture was really 312x195 - the whole layer sat 15 pixels high
    // and short of the right edge. Watching the PARENT survives both.
    var lastFit = "";
    var fit = function () {
      var c = host.querySelector("canvas");
      if (!c) return;
      var cb = c.getBoundingClientRect(), hb = host.getBoundingClientRect();
      var want = [cb.x - hb.x, cb.y - hb.y, cb.width, cb.height].join("|");
      if (want === lastFit) return;      // our own write comes back through
      lastFit = want;                     // the observer below - stop here
      layer.style.left   = (cb.x - hb.x) + "px";
      layer.style.top    = (cb.y - hb.y) + "px";
      layer.style.width  = cb.width + "px";
      layer.style.height = cb.height + "px";
    };
    new ResizeObserver(fit).observe(host);
    new MutationObserver(fit).observe(host, { childList: true, subtree: true,
        attributes: true, attributeFilter: ["style", "width", "height"] });
    window.addEventListener("resize", fit);
    fit();

    // ---- which keys the stick is holding down right now. Everything goes
    // through here so a direction change releases what it replaces; a stick
    // that presses without releasing leaves the aeroplane in a turn.
    var held = [];
    var setDir = function (keys) {
      for (var i = 0; i < held.length; i++)
        if (keys.indexOf(held[i]) < 0) ci.sendKeyEvent(held[i], false);
      for (var j = 0; j < keys.length; j++)
        if (held.indexOf(keys[j]) < 0) ci.sendKeyEvent(keys[j], true);
      held = keys;
    };

    var stick = document.createElement("div");
    stick.className = "owl-stick";
    var knob = document.createElement("div");
    knob.className = "owl-knob";
    stick.appendChild(knob);
    layer.appendChild(stick);

    var sid = null;
    var place = function (dx, dy) {
      knob.style.transform = "translate(" + dx + "px," + dy + "px)";
    };
    var track = function (ev) {
      var r = stick.getBoundingClientRect();
      var R = r.width / 2;
      var dx = ev.clientX - (r.x + R), dy = ev.clientY - (r.y + R);
      var dist = Math.sqrt(dx * dx + dy * dy);
      if (dist < R * 0.3) { setDir([]); place(0, 0); return; }   // dead centre
      var ang = (Math.atan2(-dy, dx) * 180 / Math.PI + 360) % 360;
      setDir(pickDir(ang));
      var c = Math.min(1, dist / R) * R * 0.5;
      place(dx / dist * c, dy / dist * c);
    };
    var release = function (ev) {
      if (sid === null || (ev && ev.pointerId !== sid)) return;
      sid = null; setDir([]); place(0, 0);
      if (ev) { ev.preventDefault(); ev.stopPropagation(); }
    };
    stick.addEventListener("pointerdown", function (ev) {
      if (sid !== null) return;
      sid = ev.pointerId;
      try { stick.setPointerCapture(sid); } catch (err) {}
      track(ev); ev.preventDefault(); ev.stopPropagation();
    });
    stick.addEventListener("pointermove", function (ev) {
      if (ev.pointerId !== sid) return;
      track(ev); ev.preventDefault(); ev.stopPropagation();
    });
    stick.addEventListener("pointerup", release);
    stick.addEventListener("pointercancel", release);

    var pad = document.createElement("div");
    pad.className = "owl-pad";
    for (var n = 0; n < OWLPAD.length; n++) {
      var item = OWLPAD[n];
      var b = document.createElement("div");
      if (!item) { b.className = "owl-btn gap"; pad.appendChild(b); continue; }
      b.className = "owl-btn";
      b.textContent = item[0];
      (function (btn, code) {
        var down = false;
        btn.addEventListener("pointerdown", function (ev) {
          if (down) return;
          down = true; btn.classList.add("on");
          try { btn.setPointerCapture(ev.pointerId); } catch (err) {}
          ci.sendKeyEvent(code, true);
          ev.preventDefault(); ev.stopPropagation();
        });
        var up = function (ev) {
          if (!down) return;
          down = false; btn.classList.remove("on");
          ci.sendKeyEvent(code, false);
          ev.preventDefault(); ev.stopPropagation();
        };
        btn.addEventListener("pointerup", up);
        btn.addEventListener("pointercancel", up);
      })(b, item[1]);
      pad.appendChild(b);
    }
    layer.appendChild(pad);
    host.appendChild(layer);

    // A phone that rings mid-sortie takes the pointer events with it and
    // never sends the release. Without this the jet flies away holding
    // whatever was last pressed.
    window.addEventListener("blur", function () { release(null); });
    document.addEventListener("visibilitychange", function () {
      if (document.hidden) release(null);
    });
  }

  // ---- room for the switch panel, and only while it is open.
  // js-dos has no event for this and no class on the host element, so we
  // watch for its panel arriving in the tree. Cheap: the observer fires on
  // the sidebar opening and closing, which is a handful of times a flight.
  function watchPanel(hostId) {
    style();
    var host = document.getElementById(hostId || "dos");
    if (!host) return;
    var sync = function () {
      host.classList.toggle("kb", !!host.querySelector(".soft-keyboard"));
    };
    new MutationObserver(sync).observe(host, { childList: true, subtree: true });
    sync();
  }

  // ---- the '+' fix: js-dos has KBD_equals/KBD_minus constants but its
  // DOM-code table has no "Equal"/"Minus" entry at all, so the physical
  // +/-/= keys are simply never delivered to DOSBox. They work in native
  // DOSBox and die in the browser - proven with a key probe 2026-07-27.
  // We hand them to the emulator ourselves, press AND release, so the
  // throttle ramps while the key is held - and Shift rides js-dos's own
  // path, so '+' still slams the lever to the stop.
  function fixPlusMinus(getCi) {
    var KBDFIX = { Equal: 61, Minus: 45, NumpadAdd: 334, NumpadSubtract: 333 };
    var down = {};
    window.addEventListener("keydown", function (e) {
      var k = KBDFIX[e.code], ci = getCi();
      if (!k || !ci) return;
      e.preventDefault();
      if (down[e.code]) return;          // ignore auto-repeat: DOS wants one press
      down[e.code] = true;
      ci.sendKeyEvent(k, true);
    }, true);
    window.addEventListener("keyup", function (e) {
      var k = KBDFIX[e.code], ci = getCi();
      if (!k || !ci) return;
      e.preventDefault();
      down[e.code] = false;
      ci.sendKeyEvent(k, false);
    }, true);
  }

  root.OwlControls = {
    keyboard: keyboard,
    mountTouch: mountTouch,
    watchPanel: watchPanel,
    fixPlusMinus: fixPlusMinus,
    KEYS: OWLK
  };
})(window);
