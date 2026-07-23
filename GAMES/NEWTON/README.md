# NEWTON — the aeroplane flown by force

The honest branch of the flight model. Everything that moves here moves
because a force acted on a mass: lift is `k·v²·α`, the wheels leave the
ground when it beats `m·g`, the turbine chases its lever, and the turn
is the tilted lift vector — nothing anywhere rotates at a rate we chose
because it looked good.

That rule is what separates NEWTON from its sibling. `GAMES\TRAINER`
flies the other way — attitude angles at picked rates, ported from OWL
FLY — and it flies loops and rolls today. NEWTON starts lower and earns
each axis. **The two models are not meant to meet**; if a number is
copied between them, it is a bug.

## Where it came from

Forked from `EXAMPLES\SOLO.ASM` on 2026-07-22, the day its landing
model was trusted. The first build was byte-identical to `SOLO.COM` —
the move was proven by an MD5 before anything was allowed to change.

## The road

1. **done** — SOLO moved house unchanged
2. **done** — the world tilts: the line horizon, ailerons banking the
   view, blue-noise grain riding the bank
3. **done** — the slab as a world object (`PROJH` + `POLY4`), stripes
   and thresholds surviving any attitude
4. **done, 2026-07-22 — THE WORLD.** Position is `(px, posm)` on a
   65 km x 65 km torus; heading is real; the ailerons turn the jet the
   Newton way — `omega = L·sin(phi)/(m·v)`, measured in flight against
   the formula — and `L·cos(phi)` is all the weight keeps, so an
   unpulled bank sinks. Terrain renders from a 25x25 node cache rotated
   about the camera (`TERRPREP`), drawn farthest-first through a
   build-time `TORD`; runways stand in the world on flat aprons stamped
   into the map after `DSGEN`; the HUD compass tape is live (labels at
   the 45-degree points, cyan mark = runway axis), the DME counts the
   sideways miles (max + min/2), the altimeter reads ASL, and the
   ground under the jet is `HBIL`'s bilinear surface. The AGL coupling
   was verified by instrument: the correction subtracts exactly the
   terrain's rise, tick by tick. On the wheels the arrows steer the
   nosewheel; in the air they are ailerons.
5. **done, same day — the fighter's tax and the fighter's levers.**
   Induced drag (`~ L²/v²`, saturating integer form) killed the
   marshmallow: a clean jet at idle now bleeds, mushes DOWN, and the
   world ends the flight with a card — the sink acceptance test that
   used to time out reads OFF THE CONCRETE. Pull hard and the speed
   melts; that is what a turn costs now. The afterburner is on `A`
   (lever to 25000, the spool chases, amber AB light, +17 m/s in four
   seconds measured); `Shift +/-` slams the lever to the military stop
   or to idle; `Z`/`C` are a flat rudder nudge (~1.6 deg/s) — the REAL
   sideslip, with weathervane and crossed controls, is still owed.
6. **done, same day — THE VERTICAL.** The flight path angle gamma is a
   full-circle state: `v·dgamma = L·cos(phi) − mg·cos(gamma)` — the
   same Newton that turns the heading, stood on its side. Pull and the
   path curves up; over the top `cos(gamma)` goes negative and gravity
   helps you around. A loop is not a manoeuvre, it is that line running
   six hundred times — flown and logged: gamma swept the whole circle,
   speed bled 620→480 km/h going up and the dive refunded it to the
   redline, 4.2 G over the top with the world hung upside down and the
   compass reading 180 (the display frame flips heading and roll
   together past the vertical — one flag, no gimbal code). Sink is
   DERIVED (`vs = v·sin(gamma)`) instead of integrated; the old
   relative-wind alpha correction and the sink integrator are deleted —
   the honest model is SMALLER. Gravity rides the path (`mg·sin`), so
   a zoom trades speed for height at par, both directions.
   Two traps paid for it: the l8v cap must stay under 32768 (45000
   turned negative in every IMUL — the signed family's eighth member),
   and hands-off flight with a frozen alpha phugoids into a tumble in
   ~30 s — real physics, no damping; a pilot's hands are the damper.
7. real sideslip (beta), crosswind, negative alpha for pushovers and
   sustained inverted flight, and a landing your own hands fly — the
   scripted approach overflies in ground effect; the approach is
   PILOTING now, which is the point of the whole machine

## The island

`ENGINE\E_TERR.INC` runs unmodified: Diamond-Square on a 64x64 torus,
histogram-stretched, seeded from the BIOS clock — **every launch grows
a different world** (SPACE restarts keep it; relaunch to reroll).
`WORLDH` maps raw heights the OWL FLY way: sea pinned to zero, land x5,
peaks to 1110 m.

The numbers conspire: one node is 1024 m, so 64 nodes = 65 536 m = one
full lap of a 16-bit coordinate — in BOTH axes now. The torus seam, the
world wrap and the integer overflow are the same event; `RWGAP` is
16 384 so the runway cycle divides the lap; every `jnc/add PWRAP` fixup
vanished. Crossing the seam was flight-tested: the DME wraps mid-count
and never notices.

Colour IS altitude (the user's call, and the right one): a 13-step
ramp, dark lowland green through olive and browns to white peaks, one
solid shade per quad by mean corner height — the per-tick remixing of
the dither was the shimmer, and the land no longer shimmers. The sea is
one deep blue. The sky keeps its dithered ramp and its clouds — it was
always the pretty half. The valley floor fills with solid distance
bands for the same reason.

## Building and flying it

    MAKE.BAT              (or: MAKE.BAT NEWTON from the repo root)

Debugging is the same rig the rest of the project uses — the umbilical
is `SRC\N_DEBUG.INC`, COM1 bridged to TCP:

    Debug\RUNNEWT.BAT                      launch in DOSBox
    Debug\FlyDbg.exe Debug\scenarios\world.txt

Telemetry: `hdg` is the real heading, `apx` east metres, `apz` north
metres, `rol` the bank. Pokes reach px, hdg, roll, h6, posm, alpha,
v16, Tt4. Every new axis gets a column and a scenario the same day it
gets a key — an axis that cannot be flown from a scenario cannot be
debugged.

## Keys

    arrows   stick; left/right = ailerons in the air,
             nosewheel steering on the ground
    + -      throttle (Shift+ = military stop, Shift- = idle)
    A        afterburner              Z C   rudder
    L gear   F flaps   B brakes
    SPACE    start / again              ESC quit

The keyboard is ours (INT 9): a key is a **state**, not an event; the
controls move once per tick from that state, and the local handler and
the umbilical write the same KEYS table — a scenario and a pair of
hands fly through identical code.

## The dither's dead ends (kept for the next fool, likely us)

1. An integer map rotating the Bayer index must be **unimodular** —
   `(x+y, y−x)` has determinant 2, half the matrix goes unsampled,
   whole rows come out flat: interference stripes.
2. Even a correct integer map is pointless: it preserves the pixel
   lattice, so the tile stays screen-aligned and the grain reads
   horizontal anyway.
3. What works is fractional world coordinates per pixel over **blue
   noise** (void-and-cluster, sigma 1.9, frozen as `BNOISE`) — no
   directional order to lose. The sky still uses it. The land left
   dithering altogether for the altitude ramp.

Perf, measured at the 100000-cycle DOSBox setting (the early-Pentium
target machine): 54.8–55.3 ms/tick against a 55 ms heartbeat — level,
banked, inverted, every heading, over the mountains. At the old
30000-cycle (386-class) setting the banked passes miss the tick; that
machine is not the target.
