# MULTI - a multiplayer game on the WIRE CITY site, step by step

How a small DOS game gets players on other machines through the site's
server: IPX inside DOS, the server's relay outside, no server code to
write. The calls are A:\ENGINE\E_NET.INC; the working example is
A:\EXAMPLES\NETSQ.ASM (a square each, 1.7 KB). The IPX detail: NET.

## What you get

- Everyone who runs your program with `--net` on the site meets in one
  room of the relay: `build A:\MY\TAG\TAG.ASM --net` (or `run ... --net`)
  puts the DOS PC's IPX card on the line for that run, in the room named
  after the program's folder - tag. `--net=ROOM` names another; OWL FLY's
  rooms are refused. The person's own settings stay as they were.
- A broadcast goes to everyone in the room - and comes back to you too.
- The room has nothing in it but your players: no server state, no clock.
  If the game needs a shared world, one of the machines keeps it (below).
- In desktop DOSBox the same program works over ipxnet [NET].

## The five steps

1. A socket of your own: a palindrome, so its byte order cannot bite
   (4E4Eh). Never 5757h or 5858h - OWL FLY's.
2. The includes and three constants, before E_NET:

```
NETSOCK = 4E4Eh                 ; the socket
NETLEN  = 5                     ; every packet's payload, bytes (1..482)
NETRX   = 6                     ; listen buffers: our own echo takes one
        org  100h
        include '..\..\ENGINE\E_8086.INC'
        ...                     ; the program, its main loop, its way out
        include '..\..\ENGINE\E_NET.INC'  ; after the way out: never run into
```

3. At the start `call NETOPEN` (CF=1: no IPX - let the game go on alone).
   In the main loop, every frame:
   - until named: `call NETPID`, AX=0 means "not yet" - in the browser
     the address arrives seconds after the start. Send nothing before:
     until then your own echo cannot be told from a stranger's.
   - `call NETRECV` until CF=1: DI -> NETIN (the payload), AX = who
     sent it. Copy what you need before the next call.
   - `mov si,packet` / `call NETSEND` when your state changed, and on a
     heartbeat (NETSQ: every 9 ticks, twice a second), so a newcomer sees
     everyone at once.
   - forget a player not heard for 3 s (55 ticks): that is how leaving
     looks.
4. On the way out, every way: `call NETCLOSE`, then mode 3.
5. Build it with `--net`; a second player runs the same program the same
   way - a second browser tab (the same browser sees the same A:), or a
   friend on the site with your ZIP on their A:.

## Testing it: two windows, both in sight

- A hidden or covered tab's DOS PC nearly stops (js-dos paces on the
  page's animation frames): it sends now and then, and draws and reads
  almost nothing. Two tabs in one window look broken - the one behind
  never shows the other's moves. Put two browser windows side by side, or
  bring each to the front before you judge it.
- Look at both screens: each must show its own square AND the other's;
  move one, the other screen must follow.

## The packet

- State, not events: where I am, how I look, what I hold - every packet
  whole, so a lost one costs nothing and a newcomer is up to date with
  the next. Events (a hit, a pickup) only when they cannot be a state, and
  then sent again until the other side's state shows it.
- Small: NETSQ sends 5 bytes; OWL FLY's position is 17. Keep the payload
  at most 482 (512 with the header is what an old relay passes).
- The sender's name is AX from NETRECV (its node's last two bytes). On the
  relay the LOW byte is 86h for everyone and the high byte numbers the
  players: to tell them apart (a colour, a starting place) use both, as
  NETSQ does (`xor al,ah`, then `and 7`) - the low byte alone gives every
  player the same colour.
- Clamp what comes in: a packet is someone else's word. A coordinate past
  the screen draws over your code's data otherwise.
- At most one send per BIOS tick (18.2 a second); OWL FLY sends about 18,
  the relay allows 500 a second per client.

## A world they share

- Each player owns what is his - his square, his jet - and only he sends
  it. Nobody argues over it.
- What nobody owns (bots, the score, a ball) one machine keeps: the one
  with the LOWEST name among those heard. It sends that state; the others
  draw it and send their requests ("I hit it") to it. When its packets
  stop for a second or two, the next lowest carries on from what it last
  drew - nothing freezes. OWL FLY's shared war is the worked example
  (A:\GAMES\OWLFLY3\SRC\WAR.INC, its header) [NET].
- Sides and teams: the host deals them in its state packet, and each player
  takes his at his next life - never in the middle of one.

## Limits

- 16 players a room, 64 rooms, 4096 bytes a packet on the relay.
- The site is anonymous: a name is the connection's, a reload is a new
  player. Nothing is kept when the room empties.
