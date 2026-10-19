# FASM - the assembler, kept inside the 8086

How to write flat-assembler source an 8086 can run: what FASM emits without
asking, the syntax that differs from MASM/TASM, MUL and DIV, signed and
unsigned jumps, includes and macros, building, and what the errors mean.
Segments, far calls and buffers: MEMORY.

## The rule you must not break: FASM knows no CPU

- FASM has no `.8086` and no CPU directive: in 16-bit code it assembles
  every x86 instruction it knows, silently. A conditional jump whose target
  is past -128..+127 becomes the 386 form `0F 8x`; `shl ax,3` (C1),
  `push 5` (6A), `imul ax,bx,3` (6B), `pusha` (60), `movzx` (0F B6), a
  32-bit register (66h) or `[ecx]` (67h) all assemble without a word and
  all run in DOSBox. An 8086 has no invalid-opcode trap: it runs those
  bytes as other instructions (0F is POP CS there) and goes wild.
- Include A:\ENGINE\E_8086.INC in every 8086 program. It redefines the 16
  conditional jumps (and their aliases) plus LOOP/LOOPE/LOOPZ/LOOPNE/
  LOOPNZ/JCXZ as macros: the short form where it reaches, else the inverted
  short jump over a near JMP (5 bytes; LOOP and JCXZ 7). A .COM includes it
  on the line after `org 100h`, an MZ before its first `segment`. From
  A:\MY\HELI\HELI.ASM: `include '..\..\ENGINE\E_8086.INC'`. Leave it out of
  code meant to be 386.
- It guards jumps only; the rest is yours. Shift by 1 or by CL (`mov cl,7`
  / `sar ax,cl`); push registers or memory, never an immediate; IMUL has
  only its one-operand form; no PUSHA, MOVZX, ENTER; address only through
  BX or BP plus SI or DI plus a displacement.
- Under the guard never write `short` or `near` after a Jcc: `jz short x`
  fails inside the macro with "invalid expression". `jmp short` is fine.
- A byte scan of the binary for `0F 8x` proves nothing: data bytes and
  displacements (0FD0h before an opcode) match it. Trust the include, and
  a listing where in doubt.
- In a jump macro of your own, take `here = $` before emitting: inside
  `db cc, expr` the `$` has already moved past the opcode.

## Syntax that differs from MASM/TASM

- Brackets mean memory: `mov ax,[x]` reads x, `mov ax,x` loads its offset
  (there is no OFFSET). Overrides go inside: `[es:di]`, `[cs:tbl+bx]`.
- A label made by a data directive has a size (`x dw 0`); a colon label
  (`x:`) or a register address has none. `mov [bx],1` is "operand size not
  specified": write `mov byte [bx],1`. `mov ax,[b]` on `b db 0` is
  "operand sizes do not match"; `word [b]` reads two bytes.
- A far pointer is a dword: `lds dx,[oldk]` needs `oldk dd 0`, or write
  `lds dx,dword [oldk]`. The same for LES and the far indirect call
  `call dword [ipxep]`.
- `xlatb`, not `xlat`. Hex begins with a digit: `0A000h`.
- `.name` belongs to the last global label above it: a global label in the
  middle of a routine cuts its locals off ("undefined symbol 'A.x'").
  Symbols are case-sensitive (TASM folds case).
- `X = 5` is a number and may be used above its line. Defined twice, each
  line sees the latest value above it, and a use above the first is
  "symbol 'X' out of scope" - define once. `X equ 5` is text substitution
  and must precede every use (engine headers that say "FOCAL before this
  include" mean `equ`).
- Reserved, so never names: every x86 register (di, rcx, spl, fs, dr1),
  the data directives db dw du dd dp df dq dt rb rw rd rp rf rq rt, the
  operators byte word dword near far short ptr at, and later mnemonics
  (pause). `rh`, `pa`, `pb` are free.
- Reserved data at the END of the output is not written to the file (`rb`
  or `dup(?)` after the last real byte, .COM and MZ alike) and arrives as
  whatever memory held: clear it before use. Reserves in the middle are
  stored as zeros.
- FASM picks the shortest encoding: `add di,1` is 83 C7 01, `add di,320`
  is 81 C7 40 01. Code that patches its own immediate must force the size
  (`add di,word 0`) or the patch lands on the next instruction.
- Count bytes by real encodings: `cmp byte [m],5` is 5, a short Jcc 2
  (5 when the guard makes it long), a far call 5.

## Porting from TASM

- `entry SEG:LABEL` goes BEFORE the `segment` it names, or FASM stops at
  the segment line with "invalid argument" and writes nothing.
- `ORG X` inside a segment becomes `rb X - $`: FASM's org moves the counter
  but emits nothing, and every later segment slides down.
- PROC FAR: `retf` inside, `call SEG:LABEL` (9A, 5 bytes) outside. `call
  far ptr X` assembles as FF 1E - an indirect call through the dword at
  DS:X.
- No ASSUME: write `cs:` for the far segment's own data; another segment's
  symbol through this CS is `[cs:SYM+(THERE-HERE)*16+bx]`. Same-named
  segments are not merged: an include that continues one goes right after
  it.
- ASSUME, PROC, %OUT, .ERR: "illegal instruction". A TASM variable named
  `di` was the register all along. The port comes out smaller (TASM pads
  JUMPS with NOPs): prove it byte by byte (the repository's
  TOOLS\BinAccount), not by checksum.

## MUL, IMUL, DIV, IDIV

    mul  r/m8      AX    = AL * src            imul: the same, signed
    mul  r/m16     DX:AX = AX * src
    div  r/m8      AL = AX / src,    AH = remainder    idiv: signed
    div  r/m16     AX = DX:AX / src, DX = remainder

- Only AX, DX and the flags change; BX, CX, SI, DI, BP survive. A value
  parked in DX across four multiplies came back as the last product's sign
  word, and every radar echo landed on one row. RND16 pushes DX for that
  reason (A:\ENGINE\E_MATH.INC); say in each routine's banner what it
  clobbers.
- Set up the dividend: `cbw` before a byte IDIV, `cwd` before a word IDIV,
  `xor ah,ah` or `xor dx,dx` before DIV. IDIV truncates toward zero; the
  remainder takes the dividend's sign.
- INT 0 fires on a zero divisor AND when the quotient does not fit AL (byte
  divide) or AX (word divide), and under DOSBox it repeats for ever. Clamp,
  shift, use a reciprocal table (A:\LESSONS\L15\RECIP.INC) or an INT 0 that
  never returns (A:\EXAMPLES\RELIEF.ASM TRAP0).
- Byte operands of IMUL and IDIV are SIGNED: a depth of 163 divides as -93
  and folds a cube into a pyramid; `dcon db 135` multiplies as -121. Keep
  them in -128..127 (halve both legs) or widen with `cbw` and `imul word`.
- IMUL never traps: an overflowed product is a wrong-signed low word with
  CF = OF = 1 (18*vel past 1820 steered a nose wheel the wrong way). Clamp
  the input or test `jo`.
- Shift before you multiply: `(vel>>5)*sin/256` has eight times the
  headroom of `vel*sin/32`, whose quotient overflowed at vel 4096 and froze
  a full-burner dive.
- Divide by 256 with no divide: after `imul`, the middle bytes of DX:AX
  are the answer, `mov al,ah` / `mov ah,dl` - 4 clocks against 40 for
  `sar ax,cl` with CL = 8 and 165+ for IDIV. Exact only when the result fits
  16 bits (DH is dropped silently); it rounds down where IDIV rounds toward
  zero (A:\ENGINE\E_M3D.INC ROTXZ). Times 320: (y shl 8) + (y shl 6).

## Flags, and signed or unsigned jumps

- After `cmp a,b`: unsigned JA JAE JB JBE (JC = JB, JNC = JAE); signed JG
  JGE JL JLE; JS/JNS read the sign alone. Unsigned for addresses, sizes,
  counts, colours; signed for coordinates, speeds and any difference that
  can go negative.
- A sync wait did `SBPOS - SBORIGIN` then `jb`: before the queued sound
  had played the difference was negative, read unsigned as "hours late",
  and the decoder ran free. One letter, `jl`, fixed it.
- Timers: compare the elapsed difference `(now - start)` with the
  interval, never `now` with a stored deadline - that `jb` ends early when
  the tick word wraps.
- MOV, LEA, XCHG, PUSH, POP, CBW, CWD set no flags: after `mov ax,di`
  write `or ax,ax` before `jns`. INC and DEC leave CF alone.
- LOOP and JCXZ have no long form on any CPU: without the guard FASM
  refuses ("relative jump out of range" - the good case); by hand,
  `dec cx` / `jnz .top`.

## Includes, macros, conditional assembly

- `include 'path'` is looked up in the directory of the file that includes
  it, then the INCLUDE variable's directories, then the main source's
  directory; `\` and `/` both work. DOS clamps `..` at the root, so a wrong
  depth finds another real place (C:\WORK + `..\..\ENGINE` = C:\ENGINE).
- The engine modules are code: include them after your last instruction,
  where execution cannot fall in. Each header lists its CONTRACT, the
  symbols you define (E_MATH: rseed; E_M3D: FOCAL, SINT, the attitude
  words; E_RAST: NEARZ, COLOR, ES = the buffer; E_SND: SNDN); A:\EXAMPLES
  shows the minimal set (JET.ASM for E_RAST).
- Optional engine code sits in `if defined X` ... `end if`: a program that
  declares X (fastp, linereg, clipx0..clipy1, qual) gets it, all others
  assemble byte-identical.
- Guards: `if COND` / `display 'why',13,10` / `err` / `end if` stops the
  build; `assert COND` in one line. The games' TASM-era `%OUT`/`.ERR`
  lines stop it only as an "illegal instruction". Guard derived constants
  too (`SHKLK = RSLK - NSHILK*2` refuses to overlap its neighbour).
- Report free space with a loop-free `if` / `else if` ladder of `display`
  lines: a `while` macro printing a size spun FASM at 100% for five
  minutes inside DOSBox.
- Tables at assemble time, no tool: `repeat 256` / `db f(%-1)` / `end
  repeat` (`%` counts from 1). Macros: `macro NAME a,b { ... }`, with
  `local` for their labels. Data files assemble too: a source of `db`
  lines and no code (A:\GAMES\OWLFLY3\SRC\RESDAT.ASM -> CITY.DAT).

## Building

- On the site, `build A:\MY\HELI\HELI.ASM` runs `A:\TOOLS\CWSDPMI\
  CWSDPMI.EXE`, then `A:\TOOLS\FASM\FASM.EXE -m 4096 HELI.ASM HELI.COM >
  BUILD.TXT`, then the program at fixed 30000 cycles (DOSBOX); only A:
  builds. The output is always named .COM; DOS loads by the MZ signature,
  not the name, so an MZ source still runs as an EXE.
- `FASM SRC [OUT] [-m KB] [-p passes] [-d name=value] [-s X.FAS]`. FASM.EXE
  is a 32-bit DPMI program and DOSBox has no DPMI host: run CWSDPMI.EXE
  first (no arguments: resident for one program; `-p` keeps it).
- `-m` caps FASM's extended memory. In js-dos use 4096: with none it takes
  CWSDPMI's whole virtual memory (about 145968 KB) and the emulator dies;
  16384 died before the banner; 8192 died on a 188 KB source. Too small
  says "out of memory". FASM there also needs `core=normal`: the dynamic
  core dies on the first macro (`RuntimeError: unreachable`).
- A build happened only after three checks: errorlevel (FASM sets it),
  existence (DOS's "Illegal command" sets none) and size (a lock left by a
  killed DOSBox gives a zero-byte file). Delete the old output first.
- FASM has no disassembler. `-s X.FAS` then the repository's TOOLS\LISTING
  (`LISTING X.FAS X.LST`, `-a` for an MZ) shows what each line became; run
  it at once, nothing moved in between. LISTING is not on the site's A:.
- Same source, same bytes (A:\LESSONS\L05\TURN.ASM is 771 everywhere);
  a comment-only edit must leave the binary byte-identical.

## Error messages

- `illegal instruction` - unknown mnemonic, or a MASM/TASM directive.
- `operand size not specified` - memory operand with no size: byte/word.
- `operand sizes do not match` - register and memory of other sizes;
  LDS/LES on a word.
- `reserved word used as symbol` - a name that is a register or directive,
  or a non-address register in brackets (`[cx]`, `[ax]`).
- `invalid operand`, `invalid size of operand` - reserved names as jump
  targets (near, fs, spl); an immediate into a segment register (go
  through AX); memory to memory.
- `invalid expression` - `[si+bx+di]`; `jz short x` under the guard.
- `undefined symbol 'A.x'` - a local label under another global label, an
  `equ` used above its line, or a typo. `symbol already defined` - one
  name twice. `symbol 'X' out of scope` - a twice-defined `=` used early.
- `relative jump out of range` - LOOP, JCXZ or `jmp short` past 127 bytes.
  `value out of range` - `mov al,300`, `db 256`.
- `invalid argument` at a `segment` line - its `entry` comes after it.
- `file not found` - an include path (search order above).
- `error directive encountered in source file` - an `err` guard fired; the
  `display` line above it says which. `out of memory` - `-m` too small.
