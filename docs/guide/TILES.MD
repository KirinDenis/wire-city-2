# TILES - a grid game, the way MULTIPLAY SOKO II is made

The rules behind MULTIPLAY SOKO II - Sokoban for up to eight players in a
castle - that any grid game can reuse: a puzzle, a board, a maze, a
farm. The grid and its bits, the view that always shows all of it, the
points and prizes a player feels, the mercy that keeps a co-op game
honest, the phases of a level, and the network where one machine keeps
the world. Each rule names where it is built in A:\GAMES\MULTSOK2, its
worked example (README.md there says what is where). The picture is
SCENE, the pictures ART.

## Rules you must not break

- The grid is the truth: a byte a cell, a bit for each thing on it
  (MULTSOK2.ASM: G_WALL 1, G_GOAL 2, G_BOX 4, G_FLOOR 8, G_MAN 16, G_SEEN
  32 for a search, G_CANDY 64). A grid 32 wide, so a cell is `row*32 +
  col` - shifts, never a multiply - with a zero row before it and after
  it, so the neighbours of an edge cell read 0 and need no bounds test
  (LOADLEV, gridpad). The picture, the sound and the packets are made
  from the grid and a few clocks; nothing on the screen holds state.
- The whole level is always on the screen. Pick the largest cell of a
  short list that fits - 16, 12, 10, 8, 6 pixels - and centre it (SCENE.INC
  VIEWSET). A close-up that follows the player is a key (Z), never the
  default: the first players hated a scrolling view that hid the level.
- Turning the view turns the arrows with it: up is always up the screen.
  Store the turn (0..3) and subtract it from the key's direction, mod 4
  (KEYS .dir). Q and E turn; V is an isometric view.
- One key, one step - then empty the BIOS key buffer (FLUSHKB: head made
  tail). A held key repeats faster than a step goes to the host and back;
  a pile of them walks the man on after the key is up ("sticking keys").
- Levels live in a file, one read at each level change (LEVELS.DAT,
  LEVREAD): 60 levels were 17 KB of a 64 KB .COM. The level count comes
  from the same include in a `virtual` block, so the two never disagree.
- Every phase change, every score, every new thing must be audible or
  visible to every player at once, from what changed (below) - never from
  a message about it.

## Points a player feels

- Every point shows where it is made: a gain of 5 or more rises over the
  man who made it, gold, for two seconds; a loss rises red (SCENE.INC
  POPS). A first player's complaint was "a crate home - no points": the +10
  was there, in a list of small letters under the floor.
- Points by rule, both ways, so they are honest: a crate onto a mark +10,
  off one -10 (STEP). A crate slid from mark to mark earns 0, and says so
  by showing nothing.
- Small treats everywhere, eaten once: a candy on every free floor cell,
  +1..+3 by a hash of the cell (PUTCANDY, CANDYV) - Pac-Man's, and a reason
  to walk the whole level.
- A rare prize that comes and goes: a diamond grows out of the floor 20 to
  27 s apart, lies 15 s, +25 (GEMSPAWN). A prize must never block a move:
  a crate rolled onto it takes it for the man who pushed it.
- A living thing to catch: an owl lands on a wall beside the floor half a
  minute or so apart and sits a quarter of a minute; walk into its wall,
  +10 (CATCH, OWLSPAWN). A catch is not a step: nothing to take back.
- The end of a level is an event, in phases: every crate home, the gate
  rises (1.5 s), the drawbridge comes down, the men walk out (+50, the
  first +75) - then the one who did most stands on a podium, WINNER, his
  name and his points, 8 s (SOLVE, EXITMAN, ENDLEV, SCENE.INC WINNER).
  A level with no wall between floor and outside is won at once.

## Mercy that keeps the game honest

- A step back: Backspace (a Mac's delete) or U takes your own last step
  back, and the crate you pushed with it - 32 steps a man, kept by the
  host; only while nobody has moved into the way since; the crate's points
  go back by the same rule as any push, candies stay eaten (MULTSOK2.ASM
  HREC records, UNSTEP replays). In a co-op game without it, one stuck
  crate restarts the level for everybody.
- Say when the level can no longer be won, and the way out (STUCK): a
  crate not on a mark that sits where no push can ever bring it home, or
  in a 2x2 square that is all crates and walls (none of the four can move
  again). Cross it in red at the pulse; the top line says "BACKSPACE STEPS
  BACK, R R ANEW". Where a crate can still go home is computed once a
  level (LIVEGEN): from every goal, pull a crate back - the cell it comes
  to and the cell the man then stands on must both be floor - a search
  over the walls only. Everything it never reaches is dead.
- R R (the level anew), N N, P P (the next, the previous): the first press
  only asks, in the top line; the second does it; a few seconds and it
  forgets (KEYS .q1).
- Mines are the game's sting: one a man, 5 s, then the nine cells round it
  stand still 15 s, whoever laid it; the next a minute later (PLACEMINE,
  BLAST). Consequences, not guardrails [GAMEPLAY].

## Phases and clocks

- Phase 0 play, 1 the gate rising, 2 up (walk out), 3 the winner; the
  next level after it. Steps are refused in phase 3; undo and the stuck
  check only in phase 0.
- The clocks run on BIOS ticks since the last frame, capped at 2 s after
  a stall (TICKER): each man's standing still and his wait for a mine, the
  fuses, the gate, the diamond, the owl. While any runs, the world goes out
  twice a second.
- A new level resets every man's stun, points for the level, out-of-gate
  mark and history (NEWLEV) - nothing carries over but the score.

## The network: one machine keeps the world

The calls are A:\ENGINE\E_NET.INC and the room comes from `build ...
--net` [MULTI]; this is how a grid game uses them.

- The lowest name on the wire hosts. It keeps the level, the phase, the
  crates, the candies, the clocks, the men, the scores and every man's
  history, and sends the whole world - 'W', 414 bytes: a bit for every
  floor cell that still has a candy, the crates' cells, the men, the
  mines, the owl - twice a second and after every change (WSEND).
- The others send only their steps and orders ('M': 0..3 a step, 4 anew,
  5 next, 6 previous, 7 a mine, 8 a step back) and their name ('H'), and
  draw what comes back (WAPPLY). Two men can never push one crate two
  ways: only the host moves crates.
- Everything off the wire is checked before it is believed: a cell inside
  the grid and on the floor, a clock in range, a name printable (CHECKMAN,
  WAPPLY). A world that is not this game's is dropped.
- A newcomer listens 2 s for a world; hearing none, it hosts. A man not
  heard for 3 s leaves the floor; a host not heard for 2 s is replaced by
  the lowest name still heard, from the world it last drew (NEXTHOST) -
  and a new host clears every history: it kept none.
- Sounds and popups are never sent. Each machine compares the world it
  draws now with the one it drew before and plays what changed: more
  crates home - the home chime; a candy fewer - a pop; the owl-catch
  counter up - the catch (MULTSOK2.ASM SNDDIFF, SCENE.INC POPS). One
  source of truth, and every machine hears the same.
- A protocol number in every packet; raise it whenever the world's layout
  changes (3 to 4 when the owl joined): two versions never read each other.
- Test it with a fake player - a small script that speaks the protocol to
  a test relay, once as a client (its man must move, eat, step back, be
  dropped when quiet) and once as the host (the game must join it, then
  take the castle over when it goes quiet) [TOOLS].

## Testing a grid game without a person

- A test build has keys the real one has not (`FASM -d TESTKEYS=1`, an
  `if defined TESTKEYS` block in KEYS): every crate home at once (F10),
  a diamond beside you (F9), the owl on a wall beside you (F6), the
  winner's music (F7), the sound ring dumped to a file (F8). Ship the
  build without it - and check the shipped .COM does not contain the dump
  file's name.
- Find a level where a crate is a few pushes from a mark (level 3 here)
  for the scoring tests; push one into a corner for the stuck message.
- Count what the screen says (moves, crates, candies, the score) before
  and after each key - the HUD is the test's readout.
- When a pixel cannot be found in a screenshot, make the picture answer:
  a throwaway build that draws every creature as a red square shows where
  they all are; then take it out.
