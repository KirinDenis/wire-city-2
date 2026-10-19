# TIME - the BIOS tick, the PIT, the retrace, frame pacing, measuring

What a DOS game keeps time by, and how: physics stepped by the BIOS tick
with a clamped catch-up, frames drawn as fast as they go, the retrace for
small programs, the sound card for video. Working code:
A:\GAMES\OWLFLY3\SRC\OWLFLY3.ASM (GAMELOOP), PLANES.INC (LERPSET/LERPRST).
The flight model on top of the step: PHYSICS.

## Rules you must not break

- Never time by CPU speed: no delay loops, no "so many instructions a
  frame". One program meets many speeds here: `build` runs it at fixed
  30000 cycles/ms, a game started from C: at `max` (113 million cycles a
  second measured, and host-dependent), the course page at `auto` (about
  3000/ms in real mode: OWL FLY III at a frame a second). A 4.77 MHz XT is
  roughly 300, an 8 MHz 8086 roughly 900. A delay loop is instant on one
  and a minute long on another.
- Keep time by a clock that runs in real time: the BIOS tick (games), the
  vertical retrace (small programs that always finish a frame in time),
  the sound card's DMA position (pictures with sound).
- Do not reprogram the PIT or hook INT 8: both hung in the emulator the
  games target, and both must be undone on every exit. Read the stock
  tick: nothing to install, nothing to restore.
- Never wait on the tick with interrupts off: the tick IS an interrupt,
  and with IF=0 it stops and every wait loop starves. Some drivers return
  with IF off (IPX's INT 7Ah): `sti` after them.

## The BIOS tick

- 0040:006C is a dword counted by INT 8 at 1193182/65536 = 18.2065 Hz,
  54.9 ms a tick: 18 ticks ~ 1 s, 27 = 1.5 s, 91 = 5 s. Read the low word;
  one MOV is atomic against INT 8.

```
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,[es:6Ch]        ; now
        pop  es
        mov  bx,ax
        sub  bx,[lasttk]        ; elapsed, mod 65536
        mov  [lasttk],ax
        cmp  bx,MAXSTEP         ; UNSIGNED compare: jbe, never jle
        jbe  .ok
        mov  bx,MAXSTEP
.ok:
```

- Work in differences, never in absolute ticks. The low word wraps every
  hour; `now - last` as an unsigned word stays right through it. At
  midnight the BIOS resets the dword from 1800B0h to 0: the difference
  turns huge, and an unsigned clamp makes it one capped burst, where a
  signed test (`jle`) makes it negative and a step loop runs ~65000 times.
- A deadline `t = tick + 91; wait while tick < t (jb)` ends at once when
  the sum wraps. Wait on the elapsed time instead: `sub ax,start` /
  `cmp ax,91` / `jb .wait`. When a difference can legitimately be negative
  (a frame due in the future), test it SIGNED: one `jb` there made a video
  player believe it was hours late; it ran free, flooded its queue and
  dropped its own sound. One letter, `jl`, fixed it.
- Ticks per frame at f frames a second, in 16.16 fixed point, is exactly
  1193182/f: no rounded 18.2 anywhere.
- Seed a random generator from the tick, OR 1 so it is never 0.

## The PIT

- The 8253/8254 counts at 1193182 Hz. Channel 0 (port 40h) drives IRQ 0 /
  INT 8 with divisor 65536: the tick above. Channel 2 (port 42h) drives
  the speaker (SOUND). Port 43h takes the mode byte.
- The BIOS runs channel 0 in mode 3 (square wave): the count runs down
  twice per tick, so a latched count says where you are in a half-tick,
  not which half. For finer measurement sum ticks over many frames
  (below) instead.

## The fixed step

- Each frame: read the tick, run one physics step per elapsed tick, then
  render once, as fast as the machine allows. Real-world speed is then
  the same at 2 fps and at 70. Write the physics in per-tick units.
- Clamp the catch-up: at most MAXSTEP = 6 steps a frame. Unclamped, a slow
  frame runs many steps, which makes the next frame slower still, and the
  game spirals; a stall (a disk load, a paused emulator) would
  fast-forward the world. The price: under about 3 fps the world runs
  slower than real time (a 0.7 s frame is 13 ticks, 6 are run: half
  speed). The flight school clamps at 4.
- Finer than 18 Hz without touching the PIT: sub-step inside the tick
  (OWL FLY's traffic clock runs 12 sub-steps a tick, TKSUB). A speed knob:
  accumulate ticks*speed in 8.8 and run one step per whole 256
  (A:\EXAMPLES\SMOKE.ASM).
- Smooth pictures between ticks: keep the state from before the burst and
  draw old + (new-old)*fcnt/fprev, where fcnt counts frames since the
  burst and fprev is how many frames the last interval took (capped at
  8). Angles take the short way round: difference AND 255, and 128 or
  more minus 256. Put the true state back right after the render
  (LERPRST): physics must never see a lerped value. Costs half a tick of
  latency.
- Everything the render borrows (camera, angles, AND the trig the physics
  flies on) is given back before the next step. OWL FLY calls SETTRIG
  unconditionally after the render: the conditional restores missed
  ordinary flight and the jet flew off along the pilot's line of sight.
- Simpler: one step per frame in which the tick changed
  (A:\EXAMPLES\FLIGHT.ASM). Fine while frames beat 18 Hz; below, the world
  slows down.

## Pause, and every other clock

- Pause without a lurch: while paused force the elapsed count to 0 but
  keep updating lasttk, so resuming runs no catch-up burst; pin fcnt past
  fprev (OWL FLY: fcnt = 8) so the frame shows the true state.
- Every other clock driven from the tick keeps running unless gated too:
  OWL FLY's traffic lights and the wrecks' burn timer drove on through a
  pause until their call was gated on [paused].
- Keys that only change the view are read once per frame, so they work
  while paused; keys that change the world belong to the step (INPUT).

## Tie things to time, not to frames

- Animation, decay, blinking and effect lengths count ticks. A radar
  phosphor that faded per frame would burn out faster on a fast machine;
  when the tick has not moved, change no state, only repaint.
- Do not gate visibility on a tick bit (`test lasttk,2`): it puts the
  thing out every other pair of ticks and it blinks. Give each element its
  own phase.
- Fire an event on an EDGE: compare a countdown with its value at the last
  tick (phit against phitp). "It equals 9 now" is true on different ticks
  depending on which code set it.
- Rates in ticks: at most one network packet a tick (store the tick it
  went out), an advert every 18, a host stale after 18, a pilot gone after
  36. A wait counted in ticks shows something moving on screen.
- One master clock. A picture timed by the tick and sound poured after it
  drift apart within a minute; with sound playing the DMA position rules.

## The retrace as a clock

- Port 3DAh bit 3; the wait and where it goes: VIDEO. Mode 13h refreshes
  at 70 Hz. Hercules has no 3DAh: skip the wait there.
- Pacing by retrace (a fixed move per frame, one wait per frame) is the
  lessons' and WIRE CITY's way: deterministic and simple, but the speed
  follows the refresh and drops to 35 or 23 fps whenever a frame misses
  its retrace. Right for a program that always fits in 1/70 s at the
  speed it runs (the site's `build` pins 30000); a game for slow machines
  needs the tick.

## The sound card as the clock

- The 8237's current-count register says how many samples have played:
  exact to the sample, independent of interrupt latency. A frame is due
  when the samples before it have played; behind, drop a frame; ahead,
  hold one. Measured: a 30-s clip in 544 ticks against 546 expected. With
  no card, fall back to the tick.
- Use the rate the card really runs: an 8-bit card takes a time constant,
  so 11025 Hz becomes 1000000/(256-165) = 10989 Hz, and arithmetic on the
  rate asked for leaves a minute of video adrift. Reading the count: SOUND.

## Measuring inside a program

- Measure from inside. A DOSBox batch started from `-c` swallows the
  `-c exit` after it, so a stopwatch on the run times an idle emulator. A
  hidden browser tab pauses js-dos and throttles its timers: timings taken
  there mean nothing (the site's `awake` keeps a background tab running).
- Frame counter: count frames; when 18 ticks have passed publish the count
  and reset (A:\LESSONS\L19\CLIP.ASM). Show it on request (OWL FLY:
  Ctrl+D, two digits, capped at 99): a number, not an adjective.
- Stage profile: at each stage boundary add the ticks since the previous
  boundary into that stage's slot; show the sums every 16 frames, where
  one unit is 54.9/16 = 3.4 ms a frame. The first mark after switching it
  on must restart the stopwatch, or one slot is charged the whole time it
  was off (it read 1383).
- Time the renderer without the retrace wait: with it, CLIP.COM read 10
  ticks per 20 frames, two retraces a frame - the beam, not the code.
- Compare in frames, same seed, same spot: every detail level at every
  speed (three by three, nine numbers), plus real-iron readings of the
  on-screen counter.
- For an 8088 target the emulator at max says nothing: measure on an
  emulated IBM 5160 XT (PCjs) with the program's own profiler. It charges
  by execution time and hardly by length, so it understates what shorter
  code saves on a real 8088 (4 clocks per byte fetched).
- Write measurements to a log file from inside: one such run answers what
  rounds of watching the screen cannot.
