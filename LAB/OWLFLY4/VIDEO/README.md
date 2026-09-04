# The video workbench

Full-motion video for OWL FLY 4: a converter that turns footage into a packed
file, and a DOS player that reads that file back at 640x400 with sound.

**Nothing is built yet.** This folder holds the decisions so far. The format
specification comes first, then the converter, then the player.

## Why this is the first experiment

It is the piece that de-risks the rest. A player that runs proves the format,
the palette, the dithering, the DMA, the streaming and the audio/video sync
all at once — and every one of those is a place where a wrong choice is only
visible once it is too late to change cheaply.

It is also the only one of them that can be demonstrated on its own.

## The two halves

| | |
|---|---|
| the converter | `TOOLS/Vid2Owv` — C#, run with `dotnet run --project`, where every other converter in this repository lives |
| the player | here — FASM, built by `MAKE` inside DOS like everything else |

They live apart because the split is by language and by who runs them, not by
subject: the C# tools are Windows-side build machinery, and the DOS programs
are the thing being built.

## What is already decided

**One palette per scene, not per frame.** A palette per frame costs 768 bytes
of every frame, has to be written to the DAC inside the vertical blank, and
makes the colours swim. `ffmpeg`'s `palettegen` with `stats_mode=full` reads
the whole clip and produces a single palette for it, so the quantiser does
not have to be written at all — the converter reads indices that are already
decided.

**Ordered dithering only — Bayer, never Floyd-Steinberg.** This is the one
that is easy to get wrong. Error diffusion is not temporally stable: the same
pixel in two consecutive frames lands on a different index because the error
arrived from somewhere else. The picture shimmers, and worse, *no block is
ever unchanged*, so inter-frame compression collapses to nothing. Ordered
dithering is deterministic — same input, same output — so a still background
stays still and compresses like one.

**A block codec, not a scanline one.** Each frame is cut into blocks; on a
delta frame a block is skipped, copied from the previous frame at an offset,
or sent literally. Skips run-length encode, and a keyframe goes in whole
every so often. Slow pans over a still image are then almost entirely
copies — which is exactly the kind of scene the story is made of, and it is
why the codec earns its keep rather than merely working.

**Audio is the clock.** The player must not time frames from the PIT. The
Sound Blaster runs a ring buffer in auto-init DMA and interrupts on each
half; that is the clock. Video is pulled to the audio position — drop a
frame when behind, hold one when ahead. Timed the other way round, the drift
accumulates within the first minute and cannot be fixed afterwards without
rewriting the player.

## Where the footage lives, and for how long

The packed `.OWV` files are ignored **while the format is still moving**, and
tracked once it stops. That is the whole rule, and the reason is churn rather
than size.

Git stores differences, which is why 284 commits of assembly cost this
repository some 79 MB. Video has no differences to store: change one
dithering threshold, repack, and every byte of the file is new, so git keeps
another whole copy — beside the old one, permanently, in every clone. Twenty
repacks of a three-minute scene is over a gigabyte of history to own the last
90 MB of it. And it does not come back out: history is rewritten, not
deleted, and this repository is public and forked.

None of that applies to a file written once. The `.PNG` and `.WAV` assets
already tracked here are binary too and cost nothing, because nothing
rewrites them. So when the codec settles and the repacking stops, the video
becomes an ordinary tracked asset like them, and this rule expires.

Until then what lives here is the recipe — the per-scene manifest, the
`ffmpeg` invocation and the converter — plus `SAMPLE.OWV`, one short clip
tracked from the start so the player can be tested by someone who has none of
the footage.

## The source footage, and an open question

Source clips go in `src/`, beside the work that uses them. That folder is
ignored whole, so nothing in it reaches git.

Which means, plainly: **`src/` is not a backup.** Being inside a repository
looks like safety and is not — an ignored file has no history, no remote and
no second copy. Keep one somewhere else.

Where the footage will eventually be published is still open. It is a
different question from the packed video above, because footage is
write-once: nothing rewrites it, so it carries none of the churn that makes
`.OWV` unwelcome, and it could live under version control today. A second
repository is the obvious home; a release asset is another. Not decided, and
deliberately not pre-empted here.
