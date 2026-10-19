# SOUND - the PC speaker, the Sound Blaster, music and effects, silence

Sound in a DOS game: the speaker's one square wave, a Sound Blaster ring
that mixes effects with no mixer, 16-bit streaming for music and speech,
silence for tests, and the browser. Working code:
A:\GAMES\OWLFLY3\SRC\SOUND.INC (both devices), A:\ENGINE\E_SND.INC (SBWR,
SFXRAW, SFXMB), A:\EXAMPLES\RING.ASM (the ring mixer in about 2 KB).

## Rules you must not break

- The player chooses (Blaster, speaker, none), and a device not chosen
  gets not one OUT: a machine whose 220h is some other card is left in
  peace. Offer the Blaster only if its DSP answered; with no DSP, start the
  choice on the speaker - an old machine gets a voice, not silence.
- Give the hardware back on every exit: speaker gate shut, or the tone
  plays on at the DOS prompt; DSP reset (stops the DMA loop); the IRQ mask
  bit and any hooked IRQ vector as you found them.
- Port 61h is read-modify-write, never a constant: its other bits run the
  keyboard interface (XT) and the parity checks (AT).
- A DMA buffer must not cross a 64 KB physical page (128 KB for the 16-bit
  channel): the 8237's address counter has 16 bits and the page register
  is apart, so a straddling buffer wraps to its page start and plays
  garbage. Use a 64K-aligned segment, `(CS+4FFFh) AND 0F000h`, or allocate
  twice the size and take a straight stretch inside it.
- Never let sound block the picture: a feeder that finds its queue full
  drops, and every feeding loop is bounded per call. "Fill until half
  full" never ended when a browser's emulated card drained faster than
  the loop filled, and the program stopped dead.

## The PC speaker

- PIT channel 2 makes a square wave of 1193182/divisor Hz; bits 0-1 of
  port 61h gate it to the speaker:

```
SPKOUT: mov  bx,ax              ; AX = divisor (1355 = 880 Hz)
        mov  al,0B6h            ; channel 2, low then high, square wave
        out  43h,al
        mov  al,bl
        out  42h,al
        mov  al,bh
        out  42h,al
        in   al,61h
        or   al,3               ; gate and speaker on
        out  61h,al
        ret
SPKOFF: in   al,61h
        and  al,0FCh
        out  61h,al
        ret
```

- Bend the divisor once a frame or tick, nothing per sample: it costs the
  8086 nothing, which matters because the machines that need the speaker
  are the ones counting cycles.
- One voice, ranked: an effect borrows the wave and a background drone
  takes it back. The effect's id is its priority; an equal or higher id
  takes the wave, a lower one is not heard.
- Effects as table rows: length, start divisor, slide per step, noise
  mask. Noise is an LCG (x*25173+13849) ANDed with the mask and added to
  the divisor; an alarm warbles by adding 340 on alternate step pairs; an
  engine drone is 21500 - n2*32 (idle about 55 Hz) chasing the throttle.
- Count effect lengths in ticks, not frames. OWL FLY steps them per frame,
  so its 30-step rumble lasts 0.4 s at 70 fps and 15 s at 2 fps.
- One volume: drop what the Blaster would only whisper (OWL FLY plays no
  distant blast under loudness 32 on the speaker).

## The Sound Blaster: find it, talk to it

- `BLASTER=A220 I7 D1 H5 T6` in the environment names the port, IRQ,
  8-bit DMA and (SB16) 16-bit DMA; DOSBox sets it. Read it rather than
  guess, and probe only the port it names.
- Reset and probe: 1 to base+6 (226h), wait over 3 us (port reads cost an
  ISA cycle whatever the CPU), 0 to it; then poll base+0Eh bit 7 and read
  base+0Ah until it says 0AAh, a few thousand tries at most.
- Write a DSP byte: wait while base+0Ch bit 7 is set (bounded), then out.
  Read one: wait for base+0Eh bit 7, in from base+0Ah. E1h returns the
  version, major then minor; 4.xx is an SB16, the first with 16 bits.
- The site's DOS PC offers sb16 (the default), sbpro2, sb2 or none, and
  the speaker on or off: every path must fail soft.

## The 8-bit ring: an engine loop plus effects, no interrupt

- A 32K ring of unsigned 8-bit samples (silence 80h) loops for ever on
  8-bit auto-init DMA, channel 1. The 8237: 5 to 0Ah (mask), 0 to 0Ch
  (flip-flop), 59h to 0Bh (58h + channel: single, auto-init, read),
  address low and high to 02h, page to 83h, length-1 low and high to 03h,
  1 to 0Ah (unmask). The DSP: D1h (speaker on), 40h + time constant, 48h +
  block length-1 (low, high), 1Ch (8-bit auto-init). The card's IRQ may
  stay masked at the PIC (mask the one BLASTER names): the loop needs no
  servicing.
- Time constant = 256 - 1000000/rate: 11025 Hz gives 165, which really
  plays 10989 Hz. Bending it bends the pitch: an engine loop spools with
  the throttle by one byte (OWL FLY: TC = 90 + n2/4).
- Where the beam is (SFXRAW): 0 to 0Ch, two `in al,03h` (low, high) =
  samples left; played = (length-1) - left, masked to the ring. Read the
  pair under CLI. A small step backwards is a read caught mid-update: hold
  the last value and count only a big drop as a wrap (counting the dips
  ran a video clock 1.6 times fast).
- The ring IS the mixer: add a one-shot whole into the ring about 700
  samples (60 ms) ahead of the beam, clamped to 0..255 (SFXMB); the beam
  plays it once. Behind the beam (beam - 64) heal the ring from a pristine
  copy kept in the top half of the same 64K segment (SNDHEAL; at most 4096
  bytes per call after a stall). Overlapping effects sum; no voice pool.
- Store effects as SIGNED 8-bit deltas at the ring's own rate: mixing is
  `lodsb / cbw / sar ax,cl / add / clamp`, volume is that shift (four
  steps). An IMUL per sample over a 14000-sample sound costs more than
  the frame it plays in.
- A sound must be shorter than the ring or the beam laps its own tail.
  The converter (Snd2Dat) enforces it, trims both ends at -42 dB of the
  sound's own peak (library files carried 1.2-1.5 s of padding), fades the
  cut over 6 ms (an abrupt end is a click louder than the sound) and
  measures the peak on what ships.
- A loop bed made at run time: cross-fade its seam over 512 samples.
- Loudness with range: 92 - (Manhattan distance / 64); under 14, not
  played; the rest cut onto the four steps. Alarms play a step down,
  because they repeat.
- A periodic fault names itself: a click every 2.97 s is 32768/11025, the
  ring's wrap (one byte of the pristine copy was never written).
- Keep the entry points when the insides change (SFXPOP, SFXHISS, SFXBOOM
  with AH = loudness, SFXBEEP): recordings replaced synthesis, and the
  speaker joined as a second device by a branch at the top of each, with
  not one call site touched.

## Muting, pausing, stopping

- D3h (speaker off) is not a sure mute: an SB16 (DSP 4.xx) may ignore it.
  To be certain, fill the ring with 80h and stop healing, or halt the DMA
  (D0h; D4h resumes an 8-bit transfer).
- Pause (OWL FLY): going in, D3h and the speaker gate shut; coming out,
  D1h unless the player had chosen silence. The drone holds while paused
  so nothing reopens the gate.
- Stop on silence, never mid-wave: fade over about eight ticks, drain,
  then halt (8-bit: D0h, DAh to leave auto-init; 16-bit: D5h, D9h), D3h,
  mask the DMA channel. A halt mid-sample leaves the DAC at its last level:
  a click, and the end of the sentence missing.
- Optional sound files fail soft (no bank: every effect a no-op), so one
  can go missing unseen: a browser bundle shipped without its effects bank
  for weeks. Say when it is absent, and build file lists from manifests.

## 16 bits, streaming, music

- Eight bits hiss: once compression lifts quiet passages, the
  quantisation floor sits about 48 dB under full scale. An SB16 plays 16
  bits on its high DMA channel (BLASTER's H, 5..7) and the floor drops by
  48 dB more. Use it only with DSP 4+ and an H; otherwise play 8 bits (a
  16-bit stream's high bytes, XOR 80h).
- The second 8237 (channels 4..7): address port 0C0h+n*4, count 0C2h+n*4
  (n = channel-4), mask 0D4h, mode 0D6h, flip-flop 0D8h. It counts WORDS,
  takes the byte address /2, and its page register bits 16..23 (pages:
  ch1 83h, ch5 8Bh, ch6 89h, ch7 8Ah).
- The DSP for 16 bits: 41h + rate in Hz, high byte first (no time constant
  to round); B6h (16-bit, auto-init, FIFO); 10h (mono, signed); length-1
  in samples, low then high.
- Size the ring in SAMPLES: the 8-bit channel counts bytes, the 16-bit one
  words, a sample either way. Only byte counts and silence (80h against
  0000h) then differ between cards.
- Streaming: the card interrupts at each half of the ring; refill the half
  that just finished. Acknowledge with an IN from base+0Eh (8-bit) or
  base+0Fh (16-bit) - the wrong one holds the line and no interrupt comes
  again - then EOI to 20h (and A0h for IRQ 8+). IRQ n is INT 08h+n, or
  70h+n-8. A late refill repeats old audio: a click, the better failure.
- The queue between file and card: a power of two (the wrap is a mask);
  32 KB is 0.75 s of 16-bit 22 kHz. Keep background music only HALF
  filling it, or a clip's first chunks find no room and are dropped.
- Music across cuts: start the card once per scene and keep it running; a
  clip of the same format rides it - queued behind the music, its clock
  origin set to the position now plus what is queued, the music mixed
  into its chunks at the music's level, saturated. Stopping and
  restarting cost about 0.7 s of silence each time. Leave headroom: music
  about 0.5-0.6 under speech.
- The ring starts empty, which costs a fifth of a second of silence:
  front-load audio at the head of the file rather than special-casing the
  player.
- With sound playing, the DMA position is the picture's clock (TIME).

## Silence for tests

- Desktop DOSBox: `-set "mixer nosound=true" -set "speaker
  pcspeaker=false"`. A page or rig: sbtype=none, pcspeaker=false,
  gus=false, for the test only. And pick the program's own NO SOUND.
- On the site `dosbox sbtype=none pcspeaker=false` is saved into the
  visitor's settings: put them back afterwards.
- A test window that closed early may have been closed by a person tired
  of the noise, not crashed.

## In the browser

- No sound before a click: the page's AudioContext stays suspended until
  a user gesture, the emulator's audio backs up, and the machine stops
  dead at the first sound. Start js-dos behind a real click
  (`?autostart` without one froze at the first note).
- A hidden tab pauses the machine and its sound, unless the site's
  `awake` setting is on.
