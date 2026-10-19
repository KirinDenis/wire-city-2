# GAMEPLAY - design rules that make a small DOS game play well

The rules behind the OWL FLY flight sims that any new game can reuse: what
controls and switches may do, how bots decide, damage, the HUD, rounds,
teams and the shared war, difficulty, the first minute. Each rule names
where it is built in A:\GAMES\OWLFLY3\SRC, as its worked example.

## Rules you must not break

- Consequences, not guardrails. Nothing is locked out; misuse costs what it
  would really cost: gear down at speed is drag, gear up on the ground is a
  wreck, a belly or fast arrival is a crash (UI.INC GNDSCH, LANDF). Keep
  the sting and make its cause visible; never add a mercy rule ("the first
  hit never disables what you fly with").
- Every control changes how the game plays. A lamp or switch that only
  reports is decoration: if nobody can say what the player does with it and
  what changes when it is off, replace it. Worked example, DATA.INC "the
  avionics that are SWITCHES": G ground comms (friendly flak shoots what you
  locked, not what is nearest), U air comms (friendly bots launch at your
  designation), I IFF (off, and your own flak engages you), R emissions
  (off, nobody sees you - and your own scope goes dark).
- A switch changes what OTHERS do, never what the player may do. Pointing
  and locking are his own: Enter locks the nearest target inside 24 px of
  the ring, jets, radar stations and flak alike (FLIGHT.INC, RSLOCKF,
  SHKLOCKF). A mode may set a priority, never a filter: gating the lock by
  A-A/A-G read as the game breaking.
- One lever per question: the airbrake lever is the wheel brake on the
  ground ("take speed off"), so no new key and no new plate. The gear's drag
  follows the LEVER, not the legs: you pay the moment you ask.
- Detail levels skip work; they never change the rules. LOW and MEDIUM draw
  less, physics, war, radar and instruments are identical. If a level
  changes world generation (LOW flattens the map), net players must use the
  same level: check it at the join.
- Be honest about what is missing: an unlit plate says "not yet"; a menu
  shows what the machine lacks as "- NOT IN THIS MACHINE" and refuses it.
  Never ship a flagship feature quietly switched off: a build with its net
  cut met real players as "NET 0" (the fix was a relay room of its own).

## The first minute

- Design for "ten free minutes: fly in, shoot, leave". Yardstick for every
  instrument: does it tell a stranger where he is, where the enemy is and
  which way to go? Hence a map with zoom, and radar contacts drawn as
  aircraft pointing their real heading, not squares.
- Arrive watching: the bot war (20 v 20) is already running, a spectator
  camera orbits whoever is fighting, Enter takes a jet (SYM.INC SPECTUPF).
- Start on the ground, ready: stopped on your own strip, gear down, flaps
  set, brakes on, engine at idle (UI.INC AFSPAWN). A dead jet gives a
  newcomer nothing to push against; one that creeps when the brakes come
  off invites the next input. Every life after a death starts there too:
  nothing changes what dying costs more.
- Point the start at the action: runways run north-south and each side's
  jet faces the war, so the takeoff needs no navigation. Several players
  line up ALONG the strip (AFSTART 240, AFSPACE 420), never abreast.
- Keys: pitch is a yoke (Down climbs) - say so in the help. In a long game
  Esc pauses (players quit whole sorties by accident) and quit is a chord,
  Alt+Q; a small program keeps the house rule, Esc quits to DOS. Debug
  toggles on Ctrl+letter, never a bare letter. Give every vital action a
  digit-row door: the seat change answers Tab, F8 and 0, because browser
  key maps swallowed Tab, Esc and F8 while digits always arrived.
- Pause stops the world, not the glass: views, radar and map still answer,
  and a red P says time is stopped.
- The manual is one page, under the game.

## Resources

- Finite, never regenerating: 4 missiles, 250 rounds, 12000 fuel (1 a tick,
  ~11 min; the burner drinks 8 a tick, ~80 s in all). The burner is spent,
  not left on.
- Size a budget by the trip: the tank was doubled from 5.5 min because a
  sortie ended before the pilot could cross the front and come back.
- Gate on the resource, never on a timer: "one missile in flight" made the
  second launch wait up to 15 s, always the 15 s you needed. Four rails,
  four in the air (SYM.INC MSLFREEF).
- Landing on the enemy's strip is allowed but gives no fuel or rearm: it is
  a raid, so it needs things there worth shooting and a garrison that fires.

## Bots and their decisions

- The AI may roll dice; the player never does. Bot guns: every ~0.8 s a
  random jet with an enemy within 2500 fires a 4-round burst, and 1 burst
  in 4 connects (PLANES.INC AIGUN); AI flak 1 in 2 (DATA.INC SHKHITC). The
  player's rounds, and a crewed gun's, are real tracers judged in the
  shared tracer pool.
- Character comes from limits, not accuracy. The flak vehicle slews 4/256 a
  tick (~7 s a turn: you can out-turn it), cannot reach above ~78 degrees,
  reaches 3200 (a high pass is safe), fires only within 5 compass units of
  the mark, bursts every 8 ticks, crawls 3 units a tick, patrols within
  1400 of its post (DATA.INC, the SHK block). Its dish turns 3 a tick; 7
  read as frantic.
- Eyes are a target: each side's radar station is its sight. Yours down,
  your scope fills with snow and NO RADAR; theirs down, their missile range
  drops from 10000 to 2500 (UI.INC RSNOISE, PLANES.INC airng). Symmetric,
  and no friendly-fire guard.
- Keep bots where the humans are: the leash holds each near the NEAREST
  pilot, not the host's camera (WAR.INC WLEASHF). A leashed bot re-enters
  on the horizon (9500..11547 out, 800..1311 up), never on your nose, and a
  lock on it is dropped.
- A target nobody attacks is scenery: the bots never strike the ground, so
  in a bots-only sky your station dies only by your own guns. Give some
  bots a ground mission before calling a defence feature done.
- Make a vehicle's controls DEMANDS (bearing, elevation, speed, trigger)
  that the AI or the player's hands fill; the mover never knows which
  (UI.INC SHKAI, SHKMOVE). Taking over a unit is then free: park the demands
  on its present state so it does not twitch, roll the guns level (arriving
  at the zenith you cannot find the war). The unit left behind flies
  hands-off with honest physics and enemy fire. Leaving a seat is always
  allowed; entering is gated (not falling, paused or watching).

## Damage

- Today a count: five hits bring the player down, the FIRE lamp lights at
  four ("the next one is the last"). A radar station soaks 8 shells, a
  missile is worth 4; a flak vehicle takes 4 shells or one missile.
- The honest model, planned: named systems knocked out by where the hit
  came from and with what, so the aircraft grows steadily weaker.
- A hit is sensed three ways off one rising edge of the hit counter (phit):
  heard (a thump), felt (a jolt into the view sway: the world jumps, the
  cockpit does not), seen (every Nth row flooded red/yellow, stride 2, 3, 4,
  ~1/6 s; longer and it stops being an impact). SYM.INC HITFLSHF.
- A kill reads as a BANG, not "sixteen frames": a fireball (hot core in a
  cooler shell, cooling to smoke grey), three cook-offs on three different
  pieces, then 29 s of flame and 50 s of smoke - smoke outlasting fire is a
  landmark (SYM.INC BLASTF, PLANES.INC WRECKDRAW). Hang every effect on the
  wreck pool: jets, buildings, stations and vehicles get it from one call.
- A ruin stays on the map in grey: the ruin is information.
- Decrement and act in the same place: flak counting armour down without
  destroying at zero made an immortal bot (WAR.INC WSHKGF).
- On the wire the VICTIM's machine decides his death; others only report
  hits. A bot's round on a human is nobody's kill.

## The HUD

- It must show the way to the enemy, the lock and whether it is a friend,
  what is about to kill you, and the link. OWL FLY III's lamps: DMG any
  damage, FIRE at 4 of 5 hits, FUEL under 1200, GND under 300 units above
  the ground, MSTR lit by any; NET n counts remote PILOTS (a socket flag
  still said "connected" after the other man had left).
- One colour, one meaning: red and yellow are attention (the lock, the
  enemy); ours green, theirs red. The hit flare reuses exactly those two.
- Weight goes on what moves: the boldest mark must be the one that changes
  when the thing happens; a big static mark reads as decoration.
- A bar growing toward you reads as worse (damage fills down from the top);
  damage you carry flashes. A caption that must be noticed blinks - steady,
  it is furniture by the second look - and shows only in its own cockpit.
- Ground things must not look like aircraft: no velocity stub, no blink. On
  a green phosphor scope sides are told by birth: a hostile echo flashes
  white, a friend is born green.
- Room at 320x200: a centre MFD ~56x50 px holds 14 characters by 7 lines of
  a 4x6 font; an annunciator, five letters. Clamp before printing (2000
  came out "D00").
- A side view has no HUD: it is bolted to the front glass.
- A wait must move (a spinner); two waits in a row keep one caption, since
  one that changes halfway reads as "something went wrong".

## Rounds, teams and the war

- Rounds on the clock: the site's server changes each room's map at :00
  and :30, warns a minute ahead (the DOS window title counts down) and
  restarts every game in the room together, so nobody is left in the old
  sky. Destroyed stations stay rubble until the room empties. To fly alone,
  switch the network card off.
- Teams: every human who joins is the enemy; arrivals fill the side with
  fewer humans; when a leaver makes it uneven by two, the latest joiner
  crosses at his next life, never in mid-air. Enter waits for the host's
  deal (up to SPWAIT 36 ticks), or the first life flies for the wrong side.
- One war per sky: the lowest pilot id heard runs every bot; clients fly
  the bots on along their heading between packets; a client's hit shows at
  once on its own screen and goes to the host, whose armour count is the
  truth; host silent 18 ticks, the client fights its own war - nothing
  ever freezes (WAR.INC). The host sends the war even alone.
- Pause is allowed online: your jet hangs and keeps broadcasting.
- Beyond NRMT = 4 remote humans, pilots are invisible: size slots for the
  room.

## Difficulty, and fun on a small machine

- Tune the opposition (lag, reach, dice, eyes), never the player's armour.
- Honest physics is difficulty: dry with flaps she rotates and then
  decays, so the takeoff is a burner job, and the failure states its own
  cause (see PHYSICS.MD).
- Cutting for a slow machine, cut decoration and keep what feeds systems:
  the 8088 build dropped smoke, clouds, traffic and fireballs but kept the
  radar stations, because they are the radar picture and the AI's eyes.
  Delete the cut, and measure before and after.
- One 16-bit seed makes the world: a new island every run, and a join
  needs only the seed.
- Light can cost nothing: engine glow is one DAC entry rewritten a frame.
- Keep scripted demo flights gentle: a 700 ms full pull stalls and crashes.
