# NET - multiplayer over IPX: INT 7Ah, ECBs, packets, hosts, the relay

Adding multiplayer to a small DOS game: the IPX calls, the layouts that work
in DOSBox and js-dos, how OWL FLY shares one sky and one war, and what the
WIRE CITY relay does. Code: A:\EXAMPLES\BBS.ASM (a chat, the whole API),
A:\GAMES\OWLFLY3\SRC\NET.INC (positions, the ad), WAR.INC (the war), UI.INC
(XMENU, UWWAIT: the join and the wait).

## Rules you must not break

- `sti` after EVERY call into IPX: the driver may return with interrupts
  off, the BIOS tick freezes and every timed wait hangs.
- The ECB is 42 bytes with InUse at +8 (a link dword, THEN the ESR far
  pointer). The textbook map with InUse at +4 puts a segment word where
  DOSBox reads the fragment count: 4514 fragments, a send that never returns.
- A frame never waits on the wire. Send ECB still InUse: drop the packet.
  After a send, relinquish (BX=0Ah) a bounded number of times (NET.INC: 5000).
- In a browser the node address is all zeros until the relay answers: do
  not name the player from it before its six node bytes are non-zero.
- Your own broadcasts come back to you on your socket: filter them, and post
  enough listen ECBs to hold them as well as everyone else's.
- A socket of your own, a palindrome (6A6Ah...): sockets are big-endian,
  and a palindrome's byte order cannot bite. On the site never 5757h or
  5858h: the server sends OWL FLY's sky ad on 5757h into every room, once a
  second.
- Packets under 512 bytes: older relays dropped bigger ones silently.

## The calls

- Detect: INT 2Fh AX=7A00h; AL=FFh means IPX, ES:DI = its far entry. Call
  it with `call dword [ipxep]` or `int 7Ah` (both work in DOSBox), BX = the
  function: 0 open socket (DX = socket, AL=0: until exit; returns AL=0 when
  open), 1 close (DX = socket; before exit), 3 send and 4 listen (ES:SI =
  ECB), 9 own address (ES:SI -> 10 bytes: network 4, node 6), 0Ah relinquish.
- INT 2Fh is not there under DOS 2.x and jumps into garbage: if the game may
  meet DOS 2, check INT 21h AH=30h (AL >= 3) first.
- No ESR: poll. Post the listens once, check InUse every frame, CC = 0 is a
  packet, read it, re-arm at once. Do not mask IRQ 11: that silenced
  DOSBox's delivery.
- A loop that waits for packets or keys (a lobby, a chat) yields every
  pass: INT 2Fh AX=1680h, then IPX 0Ah - without 1680h the browser's send
  queue never drained. Keys: INT 16h AH=1 in that same loop; a prompt is a
  state of the loop (a separate INT 21h AH=0Ah loop was deaf in the browser).
- ipx=true with nothing connected: IPX answers, the node stays zero. Every
  address wait needs a time limit, then the game flies solo.

## The ECB and the header

    E_LNK   = 0       ; link dword
    E_ESR   = 4       ; ESR far pointer, 0 = we poll
    E_INUSE = 8       ; non-zero while the driver owns the ECB
    E_CC    = 9       ; completion code, 0 = clean
    E_SOCK  = 10      ; socket; +12 IPX workspace (4), +16 driver's (12)
    E_IMM   = 28      ; immediate address (6): FF x6 to broadcast
    E_FCNT  = 34      ; fragment count: 1
    E_F1OF  = 36      ; the fragment: offset +36, segment +38, length +40
    ECBSZ   = 42

- One fragment covers the 30-byte IPX header and the payload, contiguous;
  length 30 + payload. A .COM patches the fragment segment from CS at start
  (BBS.ASM); an EXE writes the segment's name.
- The header, big-endian words: +0 checksum, +2 length (the driver fills
  it), +5 packet type 4, +6 dest network (4), +10 dest node (6), +16 dest
  socket, +18 src network, +22 src node, +28 src socket. The payload from +30
  is yours: little-endian words, as the 8086 has them.
- Broadcast: dest node and immediate address FF x6, dest network your own
  (from BX=9) or 0.

## Listen buffers and the echo

- OWL FLY posts 4 listens of 64 bytes for positions and 6 of 384 for the
  war. With 2 war listens the host's own echoed 'B' and 'K' filled both and
  a client's 'X' found no ear; with 4, a burst of three in one slow frame
  still lost one. Count: your echoes per frame + everyone else's + spare.
- A packet longer than the listen buffer lands with an error and is gone:
  size listens for the biggest packet, and the send buffer too (a 16-byte
  payload buffer was one short when the ad grew to 17).
- After a stall the line delivers a burst; what finds no free listen is
  dropped by DOSBox.
- Drop the echo by the pid in the payload (NET.INC), or by source node (+22)
  against your own, re-read first (BBS.ASM). A game id (gid) in every packet
  lets two games on one wire pass each other by.

## The address arrives late in the browser

- js-dos answers IPX at boot, but the relay grants the node only when the
  page's networkConnect lands, seconds later; until then BX=9 returns a real
  network NUMBER and six zero node bytes. Naming players from the node made
  every fast starter "pilot 1", each dropping the others as its own echo.
- Fix (NET.INC NETADDR): ask BX=9 once a tick until the NODE bytes (offsets
  4..9) are non-zero - test only those, the network number is there early -
  then mint the id. Cap it (UI.INC WIREWT = 270 ticks, 15 s), then solo.
  Real hardware and desktop DOSBox pass at once, so nobody else waits.
- The wait must move, drawn through the back buffer and the normal blit (a
  line written to A000h was invisible on converted cards and a healthy 17-s
  boot was reported as a hang): one caption for both waits plus a spinner.

## Packets: the OWL FLY set, as a worked example

Byte 0 is the type letter; every packet is a broadcast.
- 'P' position, 17 bytes, once per BIOS tick: +1 pid, +3 gid, +5 x, +7 y,
  +9 z, +11 heading, +13 dying, +14 killer's pid, +16 side.
- 'G' sky ad, 18 bytes, the host every 18 ticks: +1 gid, +3 seed, +5 heads,
  +6 +7 two scores, +8 bots on, +9 name (8 bytes), +17 rubble bits.
- 'H' hit, 8: +1 victim, +3 gid, +5 shooter (0 = a bot's), +7 damage.
  'R' radar down, 6: +1 pid, +3 gid, +5 station.
- 'W', 1 byte, once at start: DOSBox marks it undeliverable (CC non-zero)
  when nobody is at the other end, so the menu can say "wire dark".
- War, socket 5858h: 'B' 344 bytes every 4 ticks (13 + 35 bots x 9 + 1 +
  5 sides x 3); 'K' 206 (6 + 20 x 10) with every other 'B'; 'X' 7 (client
  to host: slot, damage).
- Grow a packet at its END and read the IPX length to tell versions apart:
  a 16-byte 'P' from an older game gets a default side.
- State that must agree is re-sent on a clock: 'R' is the fast path, the
  ad's rubble bits are the truth. A lost 'R' heals within a second, and a
  late joiner arrives right.

## Who hosts what

- Build the world from one 16-bit seed and joining is learning the seed: no
  map transfer. Whatever shapes the world (detail level, options) must be
  equal everywhere or travel in the ad: OWL FLY III's LOW detail builds
  other terrain from the same seed, and its join does not check.
- Join (UI.INC XMENU): listen 36 ticks (2 s, ads come once a second), take
  the first ad heard (gid, seed). None: create - seed = BIOS tick OR 1,
  gid = own pid - and send the ad every 18 ticks. The player presses nothing.
- Player-hosted skies split: two starting together make two that never
  merge; the host leaves and the next arrival makes another. On the site
  the server sends the ad, so everyone meets (below).
- Remote players wear fixed slots (OWL FLY: 4, a fifth is invisible); 90
  ticks (~5 s) of silence frees a slot.
- A player's life is his own to report: others send 'H', the victim's
  machine decides and says "dying" in its own 'P', and the killer scores when
  that 'P' names him.
- Paused in multiplayer: keep sending (OWL FLY's NETPOSF runs every frame,
  paused or not): the jet hangs in the sky and nobody times out.

## The shared war: one machine runs the AI (WAR.INC)

- Host = the LOWEST pid heard in the last 36 ticks (WLIVE). Every machine
  works it out from the 'P' packets it already hears: no election, no server.
- The host sends the bots every 4 ticks, even alone. A client stops
  DECIDING for those slots and flies them on along their heading between
  packets; a move over 2000 units (WJUMP) is a respawn, drawn without trail.
- A client's hit shows at once on its own screen and goes to the host
  ('X'); the host's armour counts. A bot the client downed stays down 36
  ticks (WHOLD) whatever comes.
- No 'B' for 18 ticks (WSTALE): the client fights its own war again from
  where it stands, and the next lowest pid carries on as host. Nothing ever
  freezes.
- Leash the bots to the NEAREST player, not the host's camera, or the whole
  war crowds round the host.
- The host deals the sides in every 'B'. When they go uneven by two, the
  latest joiner (the highest pid) crosses over at his next life, never in
  mid-air. Arrivals watch until the deal names them, or 2 s.
- Far-segment net code that cannot call home sets a flag (`netdead`); one
  main-segment step (NETAPPLY) applies it.
- Decrement and judge in one place: armour counted down on one path and
  judged on another wrapped 0 -> 255 into an immortal bot.

## Desktop DOSBox and the WIRE CITY relay

- Desktop: `[ipx] ipx=true`; one DOSBox runs `ipxnet startserver 213`, the
  others `ipxnet connect HOST 213` (213: a UDP port, not an IPX socket).
- Browser: DOSBox's IPX tunnel, one WebSocket message = one IPX packet; the
  conf has `[ipx] ipx=true` and the page calls
  `ci.networkConnect(0, RELAY + "/ipx/" + ROOM)`. The DOS program cannot tell.
- The site's relay is `wss://lan.owlos.sk/site`; rooms are a-z and 0-9, up
  to 16. The DOS PC connects only the networked games by default; your own
  program: `build A:\MY\TAG\TAG.ASM --net` or `run A:\MY\TAG\TAG.COM --net`
  - the card on the relay for that run, in the room of the program's folder
  (tag; --net=ROOM names another; OWL FLY's rooms are refused). Two DOS PCs
  in one room meet. The step by step, with A:\ENGINE\E_NET.INC: [MULTI].
- Registration, for a test client: send 30 bytes - checksum FFFFh, length
  30, dest and src socket 0002h, addresses zero. The first FFFFh frame back
  carries your node as its dest node (a relay that greeted before this ack
  gave a client node FF x6 and wedged its input).
- Connection n gets node 0A:00:hi:lo:86:lo; OWL FLY's pid is its last two
  bytes as a little-endian word (xx86h), so pids grow with connection order.
- Routing: FF x6 to everyone in the room but the sender, else to that node.
- Limits: 4096 bytes a packet, 16 clients a room, 64 rooms, 30000 packets a
  minute per client (a relay throttled at 120 a minute cut players off 6 s
  after takeoff). OWL FLY sends about 1500 a minute per player.
- Rooms keep games apart, not protocols: OWL FLY II and III are identical on
  the wire and live in rooms owlfly2 and owlfly3. A new game gets its own
  room and socket; two incompatible versions never share a room.
- The server hosts the SKY in OWL FLY's rooms only (owlfly2, owlfly3): once
  a second OWL FLY's own 'G' on 5757h from node 0A:00:FF:FF:00:01, gid
  A000h + generation (never a player's xx86h); the map changes at :00 and
  :30, warned a minute ahead in the DOS window's title, and every game there
  restarts into it together. It never runs the war. Every other room is the
  relay alone: nothing in it but its players.

## Timing and loss

- Send at most once per BIOS tick (keep the tick of the last send, NET.INC
  `sentk`): 18.2 a second. The ad every 18 ticks, bulk war state every 4.
- Measured on the live relay: two players, 90 s, 15.3 position packets a
  second each, longest gap 0.20 s, none lost; 3-4 browser players, 22-25 ms
  each way, p99 under 60 ms, nothing lost in 64000 packets.
- The losses come from elsewhere: a hidden tab stops js-dos (it paces on
  requestAnimationFrame) and the player vanishes at the 5-s sweep - the
  site's `awake` setting (on by default) keeps it at ~1 fps hidden; a browser
  starved of CPU; ~0.5 s stalls on a player's uplink.
- Broadcast state, not lockstep: each machine sends its own state every tick
  and goes quiet when gone. Lockstep stalls for the slowest player, dies
  when one leaves, and turns a 0.5 s stall into a resend avalanche.

## Testing it

- Two pages in one room, or a fake player: a script that opens the relay's
  WebSocket, registers as above, reads the ads and sends your packets - host
  (connect it first: the lower pid) or client against the real game.
- Delay networkConnect while the game boots to reproduce the late address;
  never ci.pause instead - it pauses networkConnect too and deadlocks.
