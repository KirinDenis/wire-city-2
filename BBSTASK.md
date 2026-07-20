# TASK: BBS.COM — write from scratch, replace CHAT.COM entirely

Start here. Read fully before touching anything. This replaces days of
debugging with one clean rebuild. Budget-conscious user: state costs, no
hypothesis spirals (stop after 2 failed guesses and re-plan).

## Goal

A new DOS program `EXAMPLES/BBS.ASM` -> `BBS.COM` (8086, TASM): the WIRE
CITY 86 BBS terminal. Multi-user IPX broadcast chat with nicknames.
Delete CHAT.COM and all chat_v*.jsdos bundles once BBS works. Keep
EXAMPLES/CHAT.ASM until BBS.COM is verified (it is the working reference
for the ECB/IPX layout), then delete it too.

## RESOLVED 2026-07-19: BBS.COM works end-to-end. Three stacked bugs:

1. **The 2026-07-18 hub regression (the big one).** RelayServer.cs
   gained the "* new caller on the wire" announce, fired concurrently
   BEFORE the RegAck was delivered. Both frames carry checksum FFFF;
   the js-dos client takes its own address from the first FFFF frame
   it sees, so when the announce won the race the client's node became
   FF:FF:FF:FF:FF:FF and the whole tunnel (and with it the emulator's
   input) wedged. This is why EVERYTHING worked on 07-17 and NOTHING
   after. Fix: ack first, announce after (see RelayServer.cs comment).
   Diagnosed by running the untouched 07-17 relay/IpxRelay on :1901 -
   keep that trick: it logs every frame in hex.
2. **DOS side needed a real idle.** The main loop must call
   `INT 2Fh AX=1680h` (release time slice) every iteration, plus the
   IPX 0Ah yield. Without 1680h the send queue never pumped.
3. **The original nick bug (07-17, real).** Non-yielding input loops
   (DOS AH=0Ah, tight INT 16h) are deaf in the browser. Solved by
   deleting the nick prompt entirely - one loop, no pre-loop states.

Working config: bbs.html = worker mode (default), minimal Dos()
options (url, pathPrefix, theme, imageRendering, noNetworking:false),
plain `ci.networkConnect(0, relay+"/ipx/"+room)` on ci-ready. No
ipx:/ipxBackend:/room: options, no interceptor, no workerThread:false.
Red herrings burned this session: page ipx options, direct mode,
WAITVR pacing, INT 9 keyboard, LISTEN-before-loop. The keyboard was
never broken in worker mode - the poisoned tunnel just looked like it.

Nick is GONE from the DOS side. Options for identity: hub-side prefix
by node, or ?nick= baked into the bundle. Decide before production.

## THE OLD THEORY (disproved; kept for history)

CHAT.COM v1 (no nick) typed perfectly in every browser. Both nick-prompt
implementations (DOS AH=0Ah buffered input; then a tight INT 16h poll
loop) were DEAF to real keyboards in real browsers, while the main loop
always typed fine. The main loop differs in ONE way: every iteration it
calls IPX function 0Ah ("relinquish control", `mov bx,0Ah; call dword
ptr [ipxep]`) — a yield to the emulator.

Therefore BBS.COM must have EXACTLY ONE loop and it must yield every
iteration. Nick entry is a STATE inside that loop, not a separate
pre-loop:

```
main:  mov bx,0Ah / call [ipxep]          ; ALWAYS yield first
       poll receive ECB (skip in NICK state)
       poll INT 16h AH=1; no key -> main
       dispatch on state:
         STATE_NICK: printable(>32,no space,max 10)->store+echo;
                     BS->erase; Enter+nonempty->build "nick: " prefix,
                     arm LISTEN, print banner, state=CHAT
         STATE_CHAT: as old CHAT.ASM @@key..@@send (line buf 100,
                     Enter->broadcast prefix+line, ESC->quit)
```

No INT 21h AH=0Ah anywhere. No wait loop without the 0Ah yield.

## Protocol facts (from working CHAT.ASM — copy its data section)

- SOCKN equ 3986h (wire bytes 86 39 at header offsets 16/28).
- IPX detect: INT 2Fh AX=7A00h, AL=FFh; entry point from ES:DI.
- Open socket bx=0, get own address bx=9 (net 4 + node 6 bytes).
- Receive ECB: fragment = 30-byte header + 128 payload; re-arm after
  each packet; own-echo filter: compare src node (hdr+22) vs mynode.
- Send ECB: immediate address FF*6, dest node FF*6 (broadcast), payload
  "nick: text",0; fragment size = 30 + len + 1.
- Packet type 4, dest socket/src socket = SOCKN.

## Build & pack (proven recipe)

- Headless build:
  `"C:/DOSBox-0.74-3/DOSBox.exe" -noautoexec -noconsole -c "mount c
  C:\DOSFiles\wire-city-2" -c "mount d C:\DOSFiles\bp" -c "c:" -c
  "<BAT that does: set PATH=c:\bp\bin;d:\bin;%PATH% && cd EXAMPLES &&
  TASM /T BBS.ASM && TLINK /t BBS.OBJ, log to BUILD.LOG>" -c "exit"`
- Bundle: adapt docs/packchat.ps1 -> bbs_v1.jsdos (contents: BBS.COM +
  .jsdos/dosbox.conf + dosbox.conf from docs/chat.conf, autoexec `bbs`).
  New filename per release (IndexedDB caches by URL).
- Page: docs/bbs.html already exists (relay/room via ?relay=&?room=,
  auto networkConnect, header diagnostics). Point its url: at
  bbs_v1.jsdos. REMOVE the temporary keyboard interceptor and
  diagnostics from bbs.html once typing is verified. Page must run
  worker mode (like the game pages) — NEVER add workerThread:false.

## Verification protocol (non-negotiable, in this order)

1. Local hub: run relay/WireCityChat exe (serves docs :8080, relay
   :1900, bot ALEX). Status: GET localhost:8080/api/bbs/status.
2. FIRST verify typing with REAL keys in a REAL browser — via the
   claude-in-chrome extension (user opens Chrome with the plugin;
   navigate to localhost:8080/bbs.html, click play, computer.type the
   nick, screenshot). NOTE: if the Chrome window is covered/minimized,
   js-dos pauses — check document.visibilityState; ask the user to keep
   the window visible instead of spoofing.
3. Then message round-trip: type a line, see "nick: line" in the WPF
   hub log (relay/WireCityChat/logs/) and ALEX's reply.
4. The embedded Claude pane is NOT a browser: js-dos pages freeze there
   (no rAF, hidden visibility), screenshots time out. Only the
   nettest.html harness (dosboxDirect + simulateKeyPress) works there —
   good for protocol tests, USELESS for keyboard verification. Never
   put pane workarounds into product pages.

## Existing infrastructure (works, do not rebuild)

- relay/WireCityChat: WPF hub = relay(1900) + docs server(8080) +
  Claude bots ALEX/BORIS (API key in gitignored settings.local.json,
  hard caps). RUN-BOT2.BAT = second bot.
- ViewOwl repo (C:\Source\Repos\ViewOwl, NEVER commit/push): /ipx/{room}
  WS relay + /chatweb/{room} JSON bridge + GET /api/bbs/status in
  Grabber.WebAPI — the production pipe behind Caddy (wss).
- docs/index.html: bold "ENTER THE WIRE CITY BBS" bar + live online
  counter from /api/bbs/status.
- Memory files: chat-plan, viewowl-repo, debug-own-change-first,
  browser-pane-jsdos-limits, budget-conscious, no-python-all-csharp.

## Ruled out already (do not re-investigate)

Networking (relay/pipe/registration/broadcast) is solid. cpu/frames/
network all run while typing fails. Key delivery reaches js-dos. The
failure is between js-dos key queue and a NON-YIELDING wait loop in the
DOS program. Hence the one-loop-with-yield architecture above.
