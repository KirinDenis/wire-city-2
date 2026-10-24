# KIT - a game glued from proven blocks, not written from nothing

A:\KIT holds the pieces the WIRE CITY games, lessons and examples were
built from, cut out, given a contract and tested: keys, time, video,
drawing, text, sprites, sound, the network, grids, physics, 3D, terrain,
video clips, the mouse, menus, art. Reading the games' sources to find
them costs about a million tokens; the catalog of all of them costs a
few thousand. Start here, write only what makes your game yours.

## The rules - not advice

1. NEVER START FROM AN EMPTY FILE. Copy the template nearest your game to
   your own folder (`cp A:\KIT\T_ARCADE\T_ARCADE.ASM A:\MY\ROCKS\ROCKS.ASM`),
   build it once as it is, and only then change it:

   | your game is... | start from | and add |
   |---|---|---|
   | anything real-time with a ship, a lander, a car, a shooter, asteroids | T_ARCADE | K_PHYS (gravity, thrust), REC\R_ENGINE (engine sound), ART\SHIPS |
   | jumping and running over tiles | T_PLAT | REC\R_PARTIC |
   | a snake, a maze on a timer, anything that steps on a grid by time | T_SNAKE | K_GRID |
   | turn-based tiles, a puzzle, pushing crates, many video cards | T_GRID | REC\R_PUSH, R_UNDO |
   | a ball and a bat, bricks | T_BREAK | |
   | a title screen, a demo effect | T_FX | |
   | a 3D object, ships in space | T_OBJ3D | K_3D |
   | flying or driving over land | T_FLY | K_TERR |
   | point and click, things to take | T_ROOM | K_INI |
   | two or more players | T_NET (its loop into yours) | K_PEER, K_NETX |
   | none of these | T_BLANK | |

2. KEEP THE TEMPLATE'S SKELETON: its main loop, its fixed physics step
   (TIM_STEPS), its back buffer and its way out. Draw only into
   [vga_buf] and show it once a frame with VGA_SHOW - never draw to
   A000h: the picture flickers. Change the rules, the pictures, the
   sounds and the words; keep its /AUTO pilot and make it play YOUR game.
3. BEFORE YOU WRITE A ROUTINE, LOOK IT UP: `read_file A:\KIT\CATALOG.TXT`
   lists every file with every routine in it. If the kit has it, include
   it and call it - read only its header, never its body. A recipe
   (KIT\REC\R_*.ASM) is code to copy and adapt; an ART file says how to
   draw a thing and gives a ready text-art picture.
4. WORDS ON THE SCREEN ARE THE KIT'S FONTS (K_FONT, KIT\ART\FONTS.TXT),
   never bare BIOS letters: the title in a big outlined gradient
   (FNT_LOOK LTITLE), the HUD in ringed letters and bold digits that read
   on any picture (LHUD, LSCORE), menus in the 8x16 (LMENU). The title
   card and the HUD line are ready: KIT\REC\R_TITLE.ASM.
5. Build after every change and fix with edit_file, a line at a time.

| template | what it is |
|---|---|
| T_BLANK  | the smallest real-time shell: a dot moved by arrows |
| T_ARCADE | shooter: title, play, game over, bullets, enemies, score, lives, sound |
| T_PLAT   | platformer: a tile map in text, gravity, jumps, coins, scrolling |
| T_SNAKE  | a grid-timed game: ring-buffer body, food, speed, best score |
| T_BREAK  | breakout: paddle, ball in 8.8, bricks |
| T_GRID   | turn-based tiles on EGA 640/EGA/CGA/Hercules/VGA: push crates |
| T_FX     | a title screen: plasma, palette cycling, sine scroller, a tune |
| T_OBJ3D  | a 3D ship and blocks, chase camera |
| T_FLY    | flying over a generated island, horizon, crash |
| T_NET    | multiplayer: a square each, host, heartbeat, timeout |
| T_ROOM   | point and click: items, slots, captions from an INI |

## FASM names that bite

`wait`, `rb`, `st1`, `k1`..`k7` and any instruction's name (mwait,
lock...) are FASM's own: a label or variable so named fails with
"invalid operand". `mov al,[w]` on a word variable needs `byte`; `lds
dx,[v]` needs `dword`. AX is not an index register on the 8086
(`[occ+ax]` will not assemble): use BX, SI or DI. A routine called inside
`loop` must keep CX.

## The rules every block keeps (KIT\README.TXT says them all)

- 8086, flat FASM, a .COM: `org 100h`, then
  `include '..\..\ENGINE\E_8086.INC'`; the KIT files AFTER your way out:
  `include '..\..\KIT\LIB\K_VGA.INC'` - these paths hold from any
  A:\FOLDER\SUB\PROG.ASM.
- A routine keeps every register except those its header lists under
  `out:`. Drawing goes into the segment in ES, 320 bytes a row.
- Names: a file's routines in CAPITALS with its prefix (VGA_SHOW,
  KEY_HELD), its variables in small letters (vga_buf). Never name your
  own things with a kit prefix. Each routine is `if used`, so you pay
  only for what you call.
- Some files need others: K_VGA needs K_MEM; a header's `needs:` says.
- Sound is never required, a missing card is silence. Esc quits and
  gives everything back - KEY_OFF, SPK_STOP, SB_DONE, NETCLOSE, VGA_OFF;
  KIT\REC\R_MAIN.ASM is the order in and out.

## A multiplayer game

Every player must be in the SAME room. `build A:\MY\TAG\TAG.ASM --net`
puts the program in the room named after its folder (tag); a friend who
runs it from another folder lands in another room and never meets you.
Name the room: `--net=ROOM`, and tell the second player that same name.
The blocks: ENGINE\E_NET.INC (the wire), KIT\LIB\K_PEER.INC (players,
host, heartbeat, timeout), K_NETX.INC (join, send on change, clamp what
comes in), recipes R_NETST, R_NETWLD, R_NETHST, R_NETAD. Read MULTI too.

## Pictures

Sprites are text art in your source - a character a pixel, `.` see
through, 0-9 A-Z a colour - drawn with SPR_TEXT or compiled with
SPR_COMPILE (K_SPR). KIT\ART has 44 things drawn by rule (trees, water,
fountain, walls, torch, owl...) with PALETTE.TXT and RULES.TXT; the
living-scene recipes (R_FLAME, R_WATER, R_LIFE, R_OWLFLY, R_DUSK) make a
picture breathe. A clip or a packed background is an OWV file (K_OWV,
ART\OWV.TXT).
