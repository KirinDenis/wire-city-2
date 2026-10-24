; ============================================================================
;  K_MEM.INC - KIT: DOS memory for a .COM. Keep the program's own 64K, ask
;  DOS for the rest (a back buffer, a level, a sound ring), give it back.
;
;  A .COM is born owning ALL free memory. Taking a segment "above CS"
;  without asking works only when nothing is loaded above the program; the
;  DOS way is to shrink first (INT 21h 4Ah), then allocate (48h). So:
;        call MEM_INIT           ; FIRST, before anything allocates
;        mov  bx,0FA0h           ; 64000 bytes in paragraphs
;        call MEM_ALLOC          ; AX = the segment, CF = no memory
;  Blocks DOS gave are freed by DOS when the program exits; MEM_FREE gives
;  one back earlier (before an EXEC, for instance).
;  The guide's topic MEMORY ("Loading low, DOS memory, EXEC") says why.
; ============================================================================

; ----------------------------------------------------------------------
;@ MEM_INIT   shrink the .COM to its own 64K so DOS can hand out the rest
;  in:  - (call it first, before any MEM_ALLOC / VGA_ON)
;  out: CF = 1 if DOS refused (the program then has no memory to give)
;  needs: -
;  from: new (guide rule 7, docs\guide\MEMORY.MD "the DOS way")
; ----------------------------------------------------------------------
if used MEM_INIT
MEM_INIT:
        push ax
        push bx
        push es
        push cs
        pop  es                 ; ES = CS = the PSP: a .COM's own block
        mov  bx,1000h           ; BX = 1000h paragraphs = 64K, all a .COM has
        mov  ah,4Ah             ; DOS: resize the block at ES to BX paragraphs
        int  21h                ; CF = refused
        pop  es
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ MEM_ALLOC  ask DOS for BX paragraphs (16 bytes each) -> AX = segment
;  in:  BX = paragraphs (0FA0h = 64000 bytes, 1000h = 64K)
;  out: AX = the block's segment; CF = 1 no memory, then AX = the largest
;       block DOS has (in paragraphs)
;  needs: MEM_INIT first (without it DOS has nothing to give: CF)
;  from: new (guide rule 7, docs\guide\MEMORY.MD)
; ----------------------------------------------------------------------
if used MEM_ALLOC
MEM_ALLOC:
        push bx
        mov  ah,48h             ; DOS: allocate BX paragraphs
        int  21h                ; AX = segment, or CF and BX = the largest
        jnc  .ok
        mov  ax,bx              ; AX = the largest block there is
        stc                     ; CF stays the answer
.ok:    pop  bx                 ; (POP keeps the flags)
        ret
end if

; ----------------------------------------------------------------------
;@ MEM_FREE   give a block from MEM_ALLOC back to DOS
;  in:  AX = the block's segment (0 = nothing, ignored)
;  out: -
;  needs: MEM_ALLOC
;  from: new (INT 21h 49h)
; ----------------------------------------------------------------------
if used MEM_FREE
MEM_FREE:
        or   ax,ax              ; nothing to give?
        jz   .no
        push ax
        push es
        mov  es,ax              ; ES = the block
        mov  ah,49h             ; DOS: free the block at ES
        int  21h
        pop  es
        pop  ax
.no:    ret
end if

; ----------------------------------------------------------------------
;@ MEM_CLEAR  fill CX bytes of segment AX with the byte BL (from offset 0)
;  in:  AX = segment, CX = bytes (0 = none), BL = the fill byte
;  out: -
;  needs: -
;  from: new (REP STOSW, as the games clear their buffers)
; ----------------------------------------------------------------------
if used MEM_CLEAR
MEM_CLEAR:
        push ax
        push cx
        push di
        push es
        mov  es,ax              ; ES = the segment
        xor  di,di              ; DI = 0, its first byte
        mov  al,bl              ; AL = the byte
        mov  ah,bl              ; AX = the byte twice: a word at a time
        cld                     ; forwards
        shr  cx,1               ; CX = words, CF = an odd byte left
        rep  stosw              ; the words
        jnc  .even
        stosb                   ; and the odd one
.even:  pop  es
        pop  di
        pop  cx
        pop  ax
        ret
end if
