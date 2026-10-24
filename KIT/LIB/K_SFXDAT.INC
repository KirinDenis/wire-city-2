; K_SFXDAT.INC - recorded sounds: a bank of 8-bit samples played into K_SB's ring
; ============================================================================
;  A game can carry real recordings - a gun, a door, a voice - as one file,
;  SFX.DAT, cut from WAV files by TOOLS\Snd2Dat (C#):
;        Snd2Dat -o <outdir> -src <incdir> GUN=gun.wav,1.0,1.0 BOOM=...
;  It writes SFX.DAT and SFXIDX.INC (SFX_GUN equ 0, ...: the numbers).
;
;  THE FILE (one 64K segment at most):
;        db 'SF'                    the mark
;        dw count                   how many sounds
;        count x  dw offset, length where each starts in the file, samples
;        then the samples: SIGNED 8-bit, mono, 11025 a second
;  Signed, because the ring holds unsigned bytes around 80h and a sound is
;  ADDED into it: load, sign-extend, add - nothing to undo per sample.
;  Every sound must be shorter than the ring (Snd2Dat checks it).
;
;  Program pattern:
;        mov  dx,sfxname        ; db 'SFX.DAT',0
;        call SFD_LOAD          ; CF=1: no file - the sounds are just silent
;        ...  mov ax,(1 shl 8) + SFX_GUN / call SFD_PLAY   ; at half loudness
;  QUIT: call SFD_FREE          ; and SB_DONE
;
;  MEMORY: SFD_LOAD takes 64K from DOS (INT 21h 48h): a .COM must shrink
;  itself first (INT 21h 4Ah, see K_SB.INC's header) - and leave room for
;  K_SB's ring too: 128K above the program in all.
;
;  needs: K_SB.INC included as well (SFD_PLAY mixes into its ring; with no
;         card SFD_PLAY does nothing, SFD_LOAD still loads). 8086.
;  from: GAMES\OWLFLY3\SRC\SOUND.INC:115-233 (SFXPLAY, proven there) and
;        SYM.INC:932-993 (SFXLOADF); TOOLS\Snd2Dat\Program.cs (the format);
;        allocation by INT 21h 48h and the guards are new.
; ============================================================================

sfd_seg dw 0                    ; the bank's segment, 0 = no bank
sfd_n   dw 0                    ; how many sounds in it

; ----------------------------------------------------------------------
;@ SFD_LOAD   load a sound bank (SFX.DAT from Snd2Dat) into 64K of its own
;  in:  DX -> the file's name, ASCIIZ
;  out: CF=0 loaded ([sfd_seg], [sfd_n]); CF=1 no file, not a bank or no
;       memory - SFD_PLAY then stays silent
;  needs: a .COM shrunk with INT 21h 4Ah first
;  from: GAMES\OWLFLY3\SRC\SYM.INC:932-993 (SFXLOADF)
; ----------------------------------------------------------------------
if used SFD_LOAD
SFD_LOAD:
        push ax
        push bx
        push cx
        push dx
        push ds
        push es
        call SFD_FREE           ; a bank before: given back first
        mov  ah,48h
        mov  bx,1000h           ; 64K
        int  21h
        jc   .no
        mov  [sfd_seg],ax
        mov  es,ax
        mov  ax,3D00h           ; open, read only (DS:DX = the name)
        int  21h
        jc   .bad
        mov  bx,ax
        push ds
        mov  ds,[sfd_seg]
        xor  dx,dx
        mov  cx,0FFF0h          ; all of it, as much as a segment holds
        mov  ah,3Fh
        int  21h                ; AX = bytes read
        pop  ds
        pushf
        push ax
        mov  ah,3Eh             ; close
        int  21h
        pop  cx
        popf
        jc   .bad
        cmp  cx,4
        jb   .bad               ; too short to be a bank
        cmp  word [es:0],4653h  ; 'SF', little-endian
        jne  .bad
        mov  ax,[es:2]
        mov  [sfd_n],ax
        clc
        jmp  .x
.bad:   call SFD_FREE
.no:    mov  word [sfd_n],0
        stc
.x:     pop  es
        pop  ds
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ SFD_FREE   give the sound bank's 64K back to DOS
;  in:  -  (harmless with no bank)
;  out: -
;  needs: nothing
;  from: new
; ----------------------------------------------------------------------
if used SFD_FREE
SFD_FREE:
        cmp  word [sfd_seg],0
        je   .r
        push ax
        push es
        mov  es,[sfd_seg]
        mov  ah,49h
        int  21h
        mov  word [sfd_seg],0
        mov  word [sfd_n],0
        pop  es
        pop  ax
.r:     ret
end if

; ----------------------------------------------------------------------
;@ SFD_PLAY   mix recorded sound AL into K_SB's ring at volume shift AH
;  in:  AL = the sound's number (SFX_... from SFXIDX.INC), AH = loudness as
;       a right shift: 0 full, 1 half, 2 a quarter, 3 an eighth
;  out: -
;  needs: SFD_LOAD, K_SB's SB_INIT (no card or no bank: nothing happens)
;  from: GAMES\OWLFLY3\SRC\SOUND.INC:178-233 (SFXPLAY)
; ----------------------------------------------------------------------
if used SFD_PLAY
SFD_PLAY:
        cmp  byte [sb_ok],0
        je   .r
        cmp  byte [sb_vol],0
        je   .r                 ; turned all the way down
        cmp  word [sfd_seg],0
        je   .r                 ; no bank: silence, the game runs on
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push ds
        push es
        mov  bl,ah              ; the shift
        and  bl,7
        xor  ah,ah
        cmp  ax,[sfd_n]
        jae  .x                 ; not in the bank
        mov  si,ax
        add  si,si
        add  si,si              ; 4 bytes an entry
        add  si,4               ; past 'SF' and the count
        push bx
        call SB_POS             ; BX = where the ring plays now
        lea  di,[bx+700]        ; 60 ms ahead of it
        and  di,SB_N-1
        pop  bx
        mov  ax,[sb_seg]        ; READ BOTH SEGMENTS FIRST - the moment DS
        mov  dx,[sfd_seg]       ;  moves, no variable of ours is reachable
        mov  es,ax
        mov  ds,dx
        mov  cx,[si+2]          ; how long this one is...
        mov  si,[si]            ; ...and where it starts
        cmp  cx,SB_N-1000
        jbe  .len
        mov  cx,SB_N-1000       ; never round the ring onto its own tail
.len:   mov  ax,si
        add  ax,cx              ; its end must be inside the segment
        jc   .x
        jcxz .x
        mov  bp,cx              ; the count rides BP: CL is the shift
.m:     lodsb                   ; DS:SI = the bank
        cbw                     ; signed 8-bit -> 16
        mov  cl,bl
        sar  ax,cl              ; quieter by the shift
        mov  dx,ax
        mov  al,[es:di]
        xor  ah,ah
        add  ax,dx              ; added to what is in the ring...
        jns  .p
        xor  ax,ax
.p:     cmp  ax,255             ; ...kept inside a byte
        jle  .q
        mov  ax,255
.q:     mov  [es:di],al
        inc  di
        and  di,SB_N-1          ; round the ring
        dec  bp
        jnz  .m
.x:     pop  es
        pop  ds
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
.r:     ret
end if
