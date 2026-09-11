# The stories

One folder per story, and inside it the shape the game reads:

```
STORY\NIGHT\
    STORY.INI            title, the folder name, where to start
    S01\  SCENE.INI      the scene: its text, its codes, its sections in order
          CLIP.INF  CLIP.OWV            a VIDEO section's recipe and product
          MUSIC.INF MUSIC.PCM           the scene's track, recipe and product
          PICKUP\  PICKUP.INF  BG.OWV  KEYS.SPR  KEYS.SLT  CASSETTE.SPR ...
    S02\  SCENE.INI  CLIP.INF  CLIP.OWV
    ...
```

The same names, one scene each, in the warehouse outside the repository,
with a folder per kind of material:

```
C:\...\OWLFLY4_RES\NIGHT\
    S01\  VIDEO\   room.mp4  room_take2.mp4
          PICKUP\  empty.jpg  full.jpg  layer-keys.png  layer-cassette.png ...
                   panel.png            the panel's backing, if it has art
          MUSIC\   night.mp3            the scene's track
    S02\  VIDEO\   pump.mp4
    ...
```

**The folders are the data.** Whether a section has its product is never
recorded anywhere; it is asked of the disk. The desk asks it to draw its
marks, and the game will ask it the same way - so a scene that has not been
made yet is not a crash, it is a screen that says `SCENE MISSING` and the
path, and any key moves on. The game can be played at every stage of
production, with the holes visible where they are.

## The files are INI

Not JSON and not a binary: a DOS program reads a line, finds the `=`, and
is done, and a person can read the file in a text editor on the machine the
game runs on. `STORY.INI`:

```
TITLE    = Night Drive
NAME     = NIGHT              the folder name, 8.3 - the game sees it
START    = S01
ORDER    = S01 S02 S03 ...    how the desk lists them; the game does not care
SCREENS  = 640x400 320x200    the editions the story is made in; the game
                              asks the player when there are two
WAREHOUSE = C:\...\OWLFLY4_RES     desk only
```

The 640x400 products sit beside `SCENE.INI` as shown above. Another
screen's sit in a folder named by its width inside the scene - `S01\320\
CLIP.INF CLIP.OWV`, `S01\320\PICKUP\...` - recipes and products alike, so
that each edition is rebuilt from its own recipe. `SCENE.INI` and the
music are shared: the story is the same story. The desk converts every
section for every screen listed, and shows the first.

and one `SCENE.INI` per scene folder:

```
TITLE    = Gas station, night
ENTERS   = 4                  the codes that start this scene
CODE     = 5                  how it ends, when no quiz decides
ENDING   = no
NOTES    = ...                what happens, learn, decide - for the writer
MUSIC    = MUSIC.PCM          the scene's track: looped under the room, mixed under the clips
MUSICSOURCE = MUSIC\night.mp3 where it came from - desk only

[VIDEO]
FILE     = CLIP.OWV
SOURCE   = VIDEO\pump.mp4     relative to the scene's warehouse folder

[PICKUP]
FOLDER   = PICKUP
PANEL    = 64                 rows below the room for the panel of slots; 0 = none
NEED     = KEYS CASSETTE      what must be taken for the scene to go on; empty = all
ITEM KEYS     = 610,222 layer-keys.png         where it sits in the SOURCE picture
ITEM CASSETTE = 377,574 layer-cassette.png
TEXT KEYS     = Her keys. Warm from her pocket.   a line over the room for a moment when it is taken

[QUIZ]
TEXT     = You'll come with me?
OPTION 1 = Yes                the number is the code the scene ends with
OPTION 2 = No
```

**Sections** are the stages of a scene and play in the order written: a
VIDEO is a clip; a PICKUP is a still with things in it, clicked away until
NEED is met; a QUIZ is a question with numbered answers. Any order, any
number, any of them absent - a scene can be one video and nothing else, or
a pickup that is also the finale.

**Codes, not names.** A scene ends with a number: the answer chosen in its
quiz, or its own `CODE` line. The scene that plays next is whichever scene
declares that number in `ENTERS`. The ending scene does not know its
successors by name - and the desk checks, at build time, that every code a
scene can end with is entered by exactly one scene. A quiz answer with
nowhere to go is a red line in "What is missing", not a black screen in
the game.

## The game reads it

[`ENGINE\STORY.COM`](../ENGINE/README.md) plays a story from these files
in DOS: the clips through the workbench decoder, a pickup with the mouse,
a quiz with the number keys, the codes followed from scene to scene. It
runs at every stage of production and says MISSING where a product is not
there yet.

## Recipe and product

Each product sits beside the `.INF` that made it. The `.INF` is the recipe
and is **tracked**; the `.OWV` and `.SPR` are products and are **ignored**
until the codec is frozen - the reason is in `.gitignore`, and it is churn,
not size. Anyone with the warehouse can rebuild everything from the recipes.

The recipe is written first and the product last, so a product **older than
its `.INF`** was made from an earlier recipe: that run failed and the old
file stayed. The desk shows such a file as STALE and does not count it as
converted; `⟳ convert` makes it again. What the converter said is kept
beside the recipe in `CLIP.LOG` / `PICKUP.LOG`, ignored like the product.

A PICKUP's products are `BG.OWV` - the empty room, one frame, with the
panel's backing in the `PANEL` rows below it (dark, or `panel.png` from the
warehouse folder laid in) - and, per thing, a `.SPR`: the cut-out scaled and
cropped exactly as the room was, in the room's palette, index 255 meaning
"not there", and **where it stands on screen** in the header, so the game
never scales anything; and a `.SLT`: the same thing at slot size, placed in
its slot on the panel. The game draws a slot as the thing's **outline**
while it is still in the room and as the thing itself once it is taken, and
shows its `TEXT` line over the room for a moment at the taking. The formats
are in [VIDEO/FORMAT.md](../VIDEO/FORMAT.md).

A scene's music is `MUSIC.PCM` beside `SCENE.INI`, made by the same
converter from `MUSIC.INF` (`MODE = MUSIC`): sixteen-bit mono samples with a
sixteen-byte header, meant to loop. The game plays it on its own while the
room (or a quiz) is on the screen and mixes it under a clip's own sound at
half level; a clip carries only its own sounds.

## The desk

`DESK.BAT` opens [SceneDesk](../../../TOOLS/SceneDesk). Three columns, read
left to right the way the work goes:

1. **Warehouse** - every scene's `VIDEO\` and `PICKUP\` folders, `●` if
   some section uses a file. **The folder is the scene**: footage assigned
   from any other folder is moved into the scene's `VIDEO\` (copied, if
   another scene still uses it), so what sits under `S04\` is S04's by
   position alone. Nothing is matched by file name. A picture shows on
   click; a button opens the selected file in whatever player the machine
   has.
2. **Story** - the scenes as a tree that follows the codes, and under each
   one its sections: `▶` video, `■` pickup, `?` quiz, and `→ 5` or `⑂ 9 10
   11` for how it ends. Green is every section made, yellow some, red none.
3. **Scene** - the sections in play order, the one selected edited below
   it, then the text; and at the bottom the picture.

Double-click footage in the warehouse and it becomes the selected scene's
next VIDEO section, converted in the background, the `.INF` written on the
way. Put `empty.jpg`, `full.jpg` and `layer-*.png` into the scene's
`PICKUP\` folder and press `+ pickup`: every layer is an item. **Place by
matching** finds each layer in `full.jpg` and puts it there when it matches
exactly - a layer cut from the picture does; one drawn separately does not,
and is left for you to drag, because a wrong guess would look like a fact.
On `show empty` the things sit on the empty room the way the game draws
them, with the edges the game crops dimmed, and the panel below it as the
game draws that too - the slots as the `.SLT` products once the pickup is
converted, as the layers scaled by the desk until then. Clicking a thing
takes it: it goes from the room and its slot turns to colour. Under the
buttons, one row a thing: the `NEED` tick, where it stands, and its `TEXT`
line. Drop an `.mp3` or `.wav` on a scene, or double-click one in the
warehouse, and it becomes the scene's music - moved into its `MUSIC\`
folder, converted, and named in `SCENE.INI`; `× music` takes it away.

**Nothing plays by itself.** Selecting a video section shows its first frame
and stops. Play, or a double-click on it in the tree, plays it once with
sound. The picture is drawn by **our own decoder**, a C# port of the DOS
player: what you see is what the game draws, palette, dither and all.

The story is written after every change, at the same moment as the `.INF`
beside the product, so the files and the folders cannot disagree.

## The shape of the story

A line, not a tree. The road is the same for everyone - room, pickup,
serpentine, gas station, motel, overlook, airport - and the choices change
what you carry rather than where you go. The one real fork is at the end,
where what you carried decides which of three endings plays. That is how the
interactive films of the CD era were built, for a reason that has not gone
away: every fork in the road is another drive to shoot, and forks multiply.
