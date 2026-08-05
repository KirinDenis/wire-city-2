# THE MOMENT OF DESTRUCTION - built 2026-08-05

The pilot: make the breakup a seven-second thing instead of sixteen frames.
Asked which breakup, he picked **the explosion itself** - every kill, jets
and buildings alike - rather than a death cinema for his own crash.

## What was actually missing

Reading the wreck pool first was worth it, because it turned out the thing
was not short at all. A wreck already carries:

- **eight pieces** of the model, flung apart with random velocities, falling
  under gravity and coming to rest on the slope;
- **fourteen glass shards** fanning out on even angles for the first 45
  ticks, arcing up and falling back, lit white and amber;
- **six tongues of flame** on every one of those eight pieces, each with its
  own flicker phase, white-hot at the root through amber to red at the tip,
  burning for 520 ticks - nearly half a minute;
- **four smoke puffs** per piece riding a 400-unit column with a vortex
  sway, out to 900 ticks, near fifty seconds.

So the fire was never the problem. What the pool has never had is the
**bang**. A hit went straight from an intact aeroplane to a burning one:
the single instant the player actually aimed at had no picture at all. That
is what reads as sixteen frames.

## What shipped

`BLASTF` in SYMSEG, laid OVER the burn rather than replacing any of it:

- **0.0 - 1.4 s, the fireball.** A ball at the breakup point, radius
  40 + age·14 world units to a cap, rising as it goes, cooling through the
  panel's own fire ramp - white-hot 94, amber 97, red 19, then the grey of
  smoke. Two discs, hot core inside cool shell, so it has depth rather than
  being a flat blob.
- **1.4 - 6.0 s, the cook-off.** Three smaller blasts at 26, 58 and 96
  ticks, each on a **different piece** of the wreck - so each one goes off
  wherever that piece has tumbled to by then. That is the detail that makes
  it read as a wreck cooking off rather than as one explosion stuttering.

It rides the wreck pool, so it covers everything the pool covers: jets,
buildings, radar stations, Shilkas. **One call site, four bytes of the main
segment**, and every kill in the game gets it.

`BLDISC` fills the circle row by row with `half = isqrt(r² − dy²)` - no
table and no trig, because a fireball drawn as a diamond reads as a
diamond. The square root is the schoolboy one, subtracting successive odd
numbers; at radius 60 that is sixty iterations a row, once a frame, for
something that is on screen for four seconds.

## Verified

- Builds clean. Main segment 110 bytes free (BSSMARK FD80), SYMSEG 3250 of
  8176 used.
- **The rasteriser cannot scribble outside the back buffer.** BLDISC's exact
  integer steps were re-run in C# over **230680 discs** - every centre from
  400 px off the left to 380 off the right, 300 above to 300 below, every
  radius 1..60 - counting writes outside the 64000 bytes. **Zero.** That was
  worth doing on its own: a stray `rep stosb` there is memory corruption,
  not a graphical glitch.
- The shape was rendered out and looked at: round, and correctly cut at all
  four screen edges.

## NOT verified

- **How it looks in the air.** Not flown.
- **The frame cost when several go off at once.** The radius is capped at 60
  pixels, which is only reached very close in, and there are two discs per
  ball with up to four wrecks alive. Four close kills at the same instant is
  the worst case and could show as a hitch. If it does, the lever is the 60
  in `BLBALL`, not the stages.
