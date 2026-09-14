# OWV — the OWL FLY 4 video format

A draft, for reading before anything is written. Numbers are little-endian.
Nothing here is settled until the player has actually played a file.

The format exists to be **decoded**, not to compress well. `h264` beats it
and always will; `h264` also cannot be unpacked by a 486 at twelve frames a
second, and every decision below is that trade taken deliberately.

## The shape of a file

```
    header          fixed, 800 bytes
    chunk
    chunk
    chunk           ... in playback order, interleaved
    END
```

There is no frame index. A cutscene is played from the beginning to the end
and never seeks, and an index would be 4 bytes per frame of nothing. If
seeking is ever wanted, the header has a spare field for the offset of one.

Chunks are read in order and acted on immediately. **Audio chunks come
before the video chunk they belong with**, so that the ring buffer is always
being filled ahead of the picture rather than behind it.

## Header — 800 bytes

| offset | size | field | |
|---|---|---|---|
| 0 | 4 | magic | `'OWV1'` |
| 4 | 2 | width | 640 |
| 6 | 2 | height | 400 |
| 8 | 1 | fps | 12 |
| 9 | 1 | flags | bit 0: has audio. bit 1: samples are signed 16-bit (else unsigned 8-bit). bits 2-7 zero |
| 10 | 2 | frames | total video frames |
| 12 | 2 | audio rate | Hz, 0 if no audio |
| 14 | 2 | max chunk | largest chunk in the file, in bytes |
| 16 | 4 | index offset | 0 — reserved for a keyframe index |
| 20 | 12 | reserved | zero |
| 32 | 768 | palette | 256 entries, 3 bytes each, 6-bit VGA values |

`max chunk` is there so the player can allocate one buffer at startup and
never think about memory again. Writing it costs the converter one extra
pass and saves the player an entire class of problem.

The palette is 6-bit because that is what the VGA DAC takes. The converter
stores what will be written, not what was in the source; converting on the
way in means the player never divides anything.

## Chunks

```
    +0  byte    type
    +1  byte    zero
    +2  dword   length of the payload, not counting these six bytes
    +6  ...     payload
```

| type | name | |
|---|---|---|
| 0x01 | KEY | a whole frame, RLE |
| 0x02 | DELTA | a frame as changes against the one before |
| 0x03 | AUDIO | PCM samples |
| 0x04 | PALETTE | replace a run of palette entries |
| 0xFF | END | end of stream; no payload |

### AUDIO

PCM, mono, at the header's rate: **signed 16-bit little-endian** when flags
bit 1 is set, unsigned 8-bit when it is not. The payload length is explicit
and is **not** constant: 22050 Hz at 12 fps is 1837.5 samples a frame, so
chunks alternate 1837 and 1838 samples (3674 and 3676 bytes at 16 bits) and
the rate stays exact. A format that insisted on a round number would drift,
and drift in the clock is the one error this player cannot survive. A chunk
never ends in the middle of a sample.

Sixteen bits is the default. Eight-bit sound hisses, and measurement put the
blame on the bits themselves rather than anything in the chain: after the
compressor the quiet passages sit at about -49 dBFS with or without dither,
because one step of an 8-bit DAC is -42 dB. The Sound Blaster 16 plays
16-bit samples through its high DMA channel, DOSBox emulates one by default,
and the cost is 44 KB/s of audio next to a megabyte a second of picture. A
16-bit file still plays on an 8-bit card: the player takes the high byte of
each sample.

## OWS — a sprite, for the point-and-click scenes

A thing that sits on a still and can be clicked away. It is made together
with the still it belongs to (`BG.OWV`, one frame), scaled and cropped by
the same numbers and quantised to the same palette, so the game draws it
with one loop and no arithmetic: index 255 is skipped, every other index
goes straight to the screen at the position in the header.

```
    +0   'OWS1'
    +4   word   width           +6   word   height
    +8   int16  x on screen     +10  int16  y on screen   (may be negative: cropped)
    +12  byte   the transparent index, 255
    +13  3 bytes zero
    +16  width*height palette indices, row by row
```

The position is where the thing stands on the 640×400 screen, not in the
source picture; `SCENE.INI` keeps the source position for the desk, and the
converter turns one into the other once.

The same file with the extension `.SLT` is the thing at **slot size** - at
most 72×48, aspect kept - placed in its slot on the panel below the room
(the position in the header is the slot's, worked out by the converter: a
cell of up to 88 pixels a thing, the row of cells centred in the band). The
game draws it two ways: as an outline in the palette's grey while the thing
is still in the room - every opaque pixel with a transparent neighbour or an
edge of the picture - and as itself once the thing is taken. The panel's
own backing is not a file of its own: the converter lays it into the bottom
`PANEL` rows of `BG.OWV`, dark or from `panel.png`.

## OWA — a track, for the scenes

Sixteen-bit mono samples for the scene's music, looped by the engine:
poured into the same queue the clips use while the room is on the screen,
mixed under a clip's own sound while a clip plays. Raw PCM with no rate
written down is a trap, and a WAV header is forty-four bytes of chunk
parsing the engine has no reason to learn, so:

```
    +0   'OWA1'
    +4   word   rate, Hz        +6   byte   bits per sample, 16
    +7   byte   zero            +8   dword  samples
    +12  dword  zero
    +16  the samples, signed little-endian words
```

The rate must be the clips' rate for the mixing to happen (22050); the
converter writes both the same.

### What the encoder decides, and the player never sees

Three keys in a recipe change the bytes written without changing a line of
this format or of the player. They are worth knowing because they are the
difference between a megabyte a second and half of it.

| key | what it lets the encoder do |
|---|---|
| `TOLERANCE` | how far one pixel may move and still count as unchanged |
| `GRAIN` | how many of a block's 64 pixels may be past that and the block still be skipped |
| `SNAP` | how far a pixel may be moved onto the one before it, to make a run |

`GRAIN` is the one that matters most, and counting is the point of it. The
first version of this rule averaged the error over the block instead, and
that wrecks motion: eight pixels of a moving edge badly wrong average out
against fifty-six right ones, the block is skipped, and the ghost stays
until the next keyframe — which is exactly what the pictures showed. Grain
is a FEW pixels anywhere; motion is MANY. Counting says that, an average
does not.

`SNAP` exists because ordered dithering guarantees the RLE coder finds
nothing: the pattern alternates between two indices a shade apart, pixel
by pixel, so no two neighbours are ever equal and every coded block costs
its full 64 literal bytes. Moving a pixel onto its neighbour when it is
already that close puts the runs back.

Measured on one sixteen-second clip, 640×400:

| TOLERANCE / GRAIN / SNAP | bytes | |
|---|---|---|
| 2 / 0 / 0 | 12,368,454 | as it was |
| 2 / 12 / 2 | 5,522,605 | the same picture, looked at frame by frame |
| 2 / 16 / 3 | 4,698,987 | banding starts to show in the dark |

The error cannot run away: every comparison is against what the PLAYER
holds, so what is measured is the whole accumulated error since the last
keyframe, and a block that keeps being nearly-right eventually drifts past
the count and is recoded.

### PALETTE

```
    +0  byte    first entry
    +1  byte    count - 1
    +2  ...     3 bytes per entry, 6-bit
```

Fades and rotating neon are this chunk and nothing else — no pixels are
touched. It is the cheapest motion in the format and the aesthetic asks for
exactly it, so it is in from the start rather than bolted on.

### KEY

The whole frame, in raster order, byte-oriented RLE over palette indices:

| lead byte | meaning |
|---|---|
| 0x00-0x7F | the next `n+1` bytes are literal |
| 0x80-0xFF | repeat the following byte `257-n` times (1..128) |

A keyframe every 4 seconds, and at any cut. Cuts matter more than the
interval: a delta frame across a scene change is every block literal, which
is worse than a keyframe *and* looks worse while it arrives.

### DELTA

```
    +0  byte    global dx  (signed, pixels)
    +1  byte    global dy  (signed, pixels)
    +2  ...     block opcodes, raster order, 8x8 blocks
```

**The global vector is the whole point of this format.** A slow pan over a
still image — which is most of what this game's scenes are — moves every
pixel by the same amount. Shift the previous frame by `(dx, dy)` first, and
what is left to code is the strip that scrolled in at the edge. Such a frame
costs about thirty bytes. Without it the same frame is four thousand changed
blocks and the codec is pointless.

At 640x400 the frame is 80 by 50 blocks: 4000 of them, in raster order.

| opcode | payload | meaning |
|---|---|---|
| 0x00-0x7F | — | skip the next `n+1` blocks (1..128) — already correct after the global shift |
| 0x80 | 1 byte | FILL: the whole block is this colour |
| 0x81 | 64 bytes | LITERAL: the block, raw |
| 0x82 | 2 signed bytes | COPY: take this block from the previous frame at `(dx, dy)` pixels from here |
| 0x83 | RLE | the block, run-length coded with the KEY scheme |
| 0xFF | — | end of frame; every remaining block is a skip |

FILL earns its place on this material specifically: night scenes are mostly
one dark colour, and a block that is 64 identical bytes costs two.

`0xFF` rather than counting to 4000 means a frame that changes only at the
top costs nothing for the rest of the screen.

## Two decoders, kept in step by hand

`PLAYER.ASM` in this folder is the one that ships. `TOOLS/SceneDesk/OwvPlayer.cs`
is a line-for-line port of its decoding, in C#, so the production desk can
show a converted file without an emulator - and without Windows Media
Player, which WPF's own video control quietly depends on and a machine may
not have. It was checked frame for frame against DOSBox before it was
trusted. Change the format in one and change it in the other, the same day.

## What the player does with it

Decode is a `rep movsd` machine. A skip is a pointer advance; FILL is
`rep stosd` after smearing the byte across a dword; LITERAL and COPY are
sixteen dwords each, eight rows of two.

The global shift is the one part that is not free — it moves 256000 bytes
before any block is looked at. That is the price of the trick that makes
pans cheap, and it is worth measuring early rather than assuming: on a
486DX2/66 a straight 256 KB move is a few milliseconds, comfortably inside
83, but the margin is not so large that it can be ignored.

**Audio is the clock.** The Sound Blaster runs a ring buffer in auto-init
DMA and interrupts on each half. Frames are pulled to the audio position —
drop one when behind, hold one when ahead. Nothing is timed from the PIT.

**The mode is VESA 100h, 640x400x256, through the extender's linear
framebuffer.** Banked VBE 1.2 would mean a window switch in the middle of a
frame, twice per frame, forever.

## The converter

`TOOLS/Vid2Owv`, C#, like every other converter here.

It does not quantise. `ffmpeg` does that, once per clip:

```
ffmpeg -i src\test1.mp4 -vf "fps=12,scale=640:400:flags=lanczos,palettegen=stats_mode=full" pal.png
ffmpeg -i src\test1.mp4 -i pal.png -lavfi "fps=12,scale=640:400:flags=lanczos,paletteuse=dither=bayer:bayer_scale=3" -pix_fmt pal8 frames\%%05d.png
```

`stats_mode=full` reads the whole clip and returns one palette for it.
`dither=bayer` is not a preference: ordered dithering is deterministic, so
an unchanged pixel stays an unchanged index, and every skip and COPY in the
delta frames depends on that. Error diffusion would make the format useless
while still producing a correct-looking still.

The converter reads those indexed frames, finds the global vector, chooses a
block opcode for each block, interleaves the audio and writes the file. Its
per-scene settings — fps, crop, keyframe interval, whether audio is present —
come from a manifest that is tracked; the frames and the output are not.

## Open, and to be settled by measurement

- **Block size.** 8x8 is the assumption. 16x16 halves the opcode count and
  coarsens what can be skipped; 4x4 does the opposite. It costs one run of
  the converter to know, and the answer will differ between a pan and a cut.
- **How the global vector is found.** Whole-frame search is slow but this is
  a build-time tool and it runs once.
- **Whether COPY earns its place at all.** If nearly every non-skipped block
  turns out to be LITERAL or FILL, COPY is complexity for nothing, and the
  decoder gets simpler and faster without it.
