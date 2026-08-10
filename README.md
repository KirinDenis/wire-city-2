# WIRE CITY 86 — the DOS arcade

### ▶ Play: https://kirindenis.github.io/wire-city-2/
### 💬 Community: [facebook.com/groups/OWLOS](https://www.facebook.com/groups/OWLOS)

Real games in real **8086 assembly** (TASM 3.2, VGA mode 13h, integer math,
no libraries), running in the browser through DOSBox-WASM — and readable to
the last byte. Built by the team behind **[Owlos](https://owlos.sk/)**:
keeping legacy systems alive is our day job; writing new software for
MS-DOS is how we relax.

## Why this exists

**Then.** In 1986 a game fit in five kilobytes because it had to. The
machine offered one stretch of memory worth caring about, no libraries, no
framework — and the programmer knew the price of every byte and every
instruction, because the bill arrived instantly: the program either fit and
ran at full speed, or it did not exist. Software was written *against* the
machine, with the whole machine held in one head.

**Now.** That way of working is being forgotten. The people who wrote like
this are retiring, while the systems they built still run banks, factories
and railways — and the skill to look after them is leaving the industry
faster than the systems are. This is **[Owlos](https://owlos.sk/)**'s day
job: we know how these systems were written, and we modernise them so they
can be supported for the years ahead — and when the job calls for it, we
can still write the way they were written.

**So.** This repository is the proof, kept in public:

- **Part museum.** The 1986 original ships untouched beside its successors.
  Play the lineage in order — a wireframe night-flight, then a flight
  simulator, then a multiplayer air war — and watch forty years happen to
  one idea, on the same 8086, every byte still readable.
- **Part working method.** When the job calls for writing the old way, we
  still can — and these games are the demonstration, built exactly as it
  was done then: arithmetic you can prove on paper, memory budgets you read
  as a number before you build, the hardware itself used as the library it
  always was. And where the old meets today's tools, today serves
  yesterday — modern converters prepare the art and the sounds, but the
  8086 is the runtime, never the toolchain.
- **Part lesson.** Every routine in ~30,000 lines of assembly carries its
  reasoning, not just its mechanics — what this is for, why the constant,
  what broke the last time someone touched it. The code teaches the way it
  was taught: by being read.

What the method buys — then and now — is the advantage of this repository:
nothing hidden behind a framework, the cost of everything visible, and
programs small enough that one person can hold the whole machine in their
head. That is not nostalgia. It is an engineering standard, and this is
what it looks like applied.

## The games

| Game | Size | What it is | |
|---|---|---|---|
| ![owlfly2](res/owlfly2.png) **[OWL FLY II](GAMES/OWLFLY2/)** | 105 KB code + 162 KB data | **The multiplayer successor**: one shared sky over IPX-through-WebSocket, and no menu — you arrive as a spectator over the bot war, an orbit camera on whoever has a missile on his tail, and **Enter takes a jet**, stopped on your own runway with the brakes set. An F-15 SE II cockpit with NATO-shape radar symbology, three MFD pages (MAP / SIT / TGT), a ground school (rotation speed, wheel brakes, nose-wheel steering), a recorded sound bank mixed through one DMA ring, and an afterburner worth four dry engines. The data is the painted cockpit (63 KB front, 47 KB side views) and the sounds (52 KB). | [▶ play](https://kirindenis.github.io/wire-city-2/owlfly2.html) |
| ![owlfly](res/owlfly.png) **[OWL FLY](GAMES/OWLFLY/)** | 40 KB | The combat flight simulator: procedural island, destructible city, two air forces of five aircraft types, missiles, a photo cockpit with a working radar, a real jet engine in one Sound Blaster channel. *Fly, owl!* | [▶ play](https://kirindenis.github.io/wire-city-2/owlfly.html) |
| ![wirecity](res/wirecity.png) **[WIRE CITY](GAMES/WIRECITY/)** | 5.5 KB | The 1986-style original that named the arcade: a wireframe night-flight over a procedural megacity, one source file. The ancestor. | [▶ play](https://kirindenis.github.io/wire-city-2/play.html?g=wirecity) |

## The teaching machines

Standalone `.COM`s a few KB each, built on the same [ENGINE/](ENGINE/)
modules the games use — see [EXAMPLES/](EXAMPLES/README.md):
[the hangar](https://kirindenis.github.io/wire-city-2/play.html?g=jet) ·
[the island factory](https://kirindenis.github.io/wire-city-2/play.html?g=terra) ·
[the avionics](https://kirindenis.github.io/wire-city-2/play.html?g=avio) ·
the ring mixer (build it) · the 1986 network chat (in the workshop).

## Reading

[ARCHITECTURE.md](GAMES/OWLFLY/ARCHITECTURE.md) — the 64K one-segment discipline and the
whole machine · [3D graphics](docs/GRAPHICS.md) (and
[the beginner version](docs/GRAPHICS-101.md)) ·
[avionics](docs/AVIONICS-101.md) · [LESSONS](docs/LESSONS.md) — what
40 kilobytes taught us · [llms.txt](llms.txt) for your AI assistant.

## Repository layout

```
GAMES/OWLFLY2/    OWL FLY II, the multiplayer successor (EXE, far segments)
GAMES/OWLFLY/     the flight simulator: SRC/, res/, INSTALL/, its README
GAMES/WIRECITY/   the 1986 original: one CITY.ASM, its README
ENGINE/           engine modules with documented contracts (shared by all)
EXAMPLES/         the teaching machines (each states its contract)
LAB/              the workbench: one city block that holds still, and a
                  camera to walk round it (HOUSE.COM) - not shipped
docs/             the arcade site: gallery, players, bundles, deep dives
MAKE.BAT          builds everything: converters + headless DOSBox + TASM
```

Build: `MAKE.BAT` from the repo root (needs Python+Pillow and paths in a
gitignored `LOCAL.BAT`; see [GAMES/OWLFLY/README.md](GAMES/OWLFLY/README.md)
for details). The site deploys from `docs/` via GitHub Pages;
`PUBLISH.BAT` packs a fresh game bundle (filename-versioned — js-dos caches
by path).

## What is in the workshop

Multiplayer over IPX tunneled through WebSocket is **live in OWL FLY II**
(browser pilots meet through the relay; native DOSBoxes over `ipxnet`).
Still cooking: in-game chat riding the same wire, real callsigns, relay
bots keeping the skies alive, a NOW-PLAYING API — and, one day, the
emulator streamed to an ESP32 screen.

## License

Game code MIT (see LICENSE). DOSBox / js-dos (GPL) are the runtime that
plays the games, not part of their source.
