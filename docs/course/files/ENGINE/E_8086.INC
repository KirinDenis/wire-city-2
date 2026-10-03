; ============================================================================
;  E_8086.INC - keep FASM inside the 8086 instruction set.
;
;  WHAT GOES WRONG WITHOUT IT. A conditional jump on the 8086 reaches 127
;  bytes and no further. The 386 added a long form - 0F 8x, four bytes - and
;  FASM will reach for it the moment a target is out of range, silently,
;  because FASM has no directive that says which processor you are writing
;  for. TASM has one, .8086, and under it TASM does the only thing an 8086
;  can: jumps the OTHER way over an unconditional near jump.
;
;      jle far_away        ->      jg  over        ; 2 bytes
;                                  jmp far_away    ; 3 bytes, near, unconditional
;                          over:
;
;  Translating a .8086 source to FASM therefore loses the restriction, and
;  nothing complains. WIRE CITY's first FASM build carried ten 0F 8x jumps
;  into a program whose own header says "8086 only" - it would have run on
;  every emulator and died on the machine it was written for. BinAccount
;  found them by comparing the two builds instruction by instruction.
;
;  WHAT THIS DOES. It redefines the sixteen conditional jumps as macros that
;  measure the distance themselves: the short form where it reaches, the
;  jump-over-a-jump where it does not. Nothing else changes, and the file is
;  the whole of the fix - include it and the source is 8086 again.
;
;      include '..\ENGINE\E_8086.INC'      ; right after org 100h
;
;  Assembling code that is meant to use 386 instructions? Do not include it.
;  It restricts nothing but the jumps, but those it restricts absolutely.
;
;  HOW THE DISTANCE IS MEASURED. A jump displacement counts from the END of
;  the jump, so a two-byte short jump measures from here+2 and the five-byte
;  form from here+5.
;
;  `here` has to be captured before anything is emitted. $ moves as the bytes
;  go out - inside `db cc, expr` it has already passed the opcode by the time
;  expr is evaluated - so writing $ in the displacement puts every backward
;  jump one byte short of its target, silently, in the middle of an
;  instruction. That was the first version of this file, and it took a
;  byte-for-byte comparison against the TASM build to see it.
;
;  FASM resolves forward references by passing over the source again, so a
;  target defined later is unknown on the first pass and known on the next.
;  The choice settles because shortening a jump can only bring other targets
;  closer, never push them away.
; ============================================================================

; The worker. cc is the short opcode, ncc its opposite - the pair that lets
; the long case jump over an unconditional near jump.
macro __cc8086 cc, ncc, target
{
    local here
    here = $
    if (target - (here + 2)) >= -128 & (target - (here + 2)) <= 127
        db cc, (target - (here + 2)) and 0FFh
    else
        db ncc, 3                       ; skip the three bytes below
        db 0E9h                         ; JMP near
        dw target - (here + 5)
    end if
}

; LOOP and JCXZ reach 127 bytes and no further either, and unlike the
; conditional jumps they have no long form on ANY processor - not even the
; 386 added one. So there is no encoding to fall back to, only the same trick
; one step longer: take the short jump to a near jump, and step over that near
; jump when the condition does not hold.
;
;     loop  far_away      ->      loop  L1        ; 2, taken when cx <> 0
;                                 jmp   short L2  ; 2, the fall-through
;                             L1: jmp   far_away  ; 3, near
;                             L2:
;
macro __cx8086 cc, target
{
    local here
    here = $
    if (target - (here + 2)) >= -128 & (target - (here + 2)) <= 127
        db cc, (target - (here + 2)) and 0FFh
    else
        db cc, 2                        ; condition holds -> the near jump
        db 0EBh, 3                      ; it does not -> step over it
        db 0E9h                         ; JMP near
        dw target - (here + 7)
    end if
}

macro loop   t { __cx8086 0E2h, t }
macro loope  t { __cx8086 0E1h, t }
macro loopz  t { __cx8086 0E1h, t }
macro loopne t { __cx8086 0E0h, t }
macro loopnz t { __cx8086 0E0h, t }
macro jcxz   t { __cx8086 0E3h, t }

macro jo   t { __cc8086 070h, 071h, t }
macro jno  t { __cc8086 071h, 070h, t }

macro jb   t { __cc8086 072h, 073h, t }
macro jc   t { __cc8086 072h, 073h, t }
macro jnae t { __cc8086 072h, 073h, t }
macro jnb  t { __cc8086 073h, 072h, t }
macro jnc  t { __cc8086 073h, 072h, t }
macro jae  t { __cc8086 073h, 072h, t }

macro je   t { __cc8086 074h, 075h, t }
macro jz   t { __cc8086 074h, 075h, t }
macro jne  t { __cc8086 075h, 074h, t }
macro jnz  t { __cc8086 075h, 074h, t }

macro jbe  t { __cc8086 076h, 077h, t }
macro jna  t { __cc8086 076h, 077h, t }
macro ja   t { __cc8086 077h, 076h, t }
macro jnbe t { __cc8086 077h, 076h, t }

macro js   t { __cc8086 078h, 079h, t }
macro jns  t { __cc8086 079h, 078h, t }

macro jp   t { __cc8086 07Ah, 07Bh, t }
macro jpe  t { __cc8086 07Ah, 07Bh, t }
macro jnp  t { __cc8086 07Bh, 07Ah, t }
macro jpo  t { __cc8086 07Bh, 07Ah, t }

macro jl   t { __cc8086 07Ch, 07Dh, t }
macro jnge t { __cc8086 07Ch, 07Dh, t }
macro jge  t { __cc8086 07Dh, 07Ch, t }
macro jnl  t { __cc8086 07Dh, 07Ch, t }

macro jle  t { __cc8086 07Eh, 07Fh, t }
macro jng  t { __cc8086 07Eh, 07Fh, t }
macro jg   t { __cc8086 07Fh, 07Eh, t }
macro jnle t { __cc8086 07Fh, 07Eh, t }
