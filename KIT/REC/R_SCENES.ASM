; ============================================================================
;  R_SCENES.ASM - recipe: scenes (rooms, levels) chained by exit codes, in
;  one INI file a person or a model writes.
;
;  OWL NIGHT's story: a scene ends with a number - the quiz's answer, else
;  its CODE line - and the next scene is the first in ORDER whose ENTERS
;  holds that number; ENDING = YES ends the story. There every scene was a
;  folder with its own SCENE.INI; here every scene is a [SECTION] of one
;  file, so one read holds the game:
;
;        [GAME]
;        START = HALL
;        ORDER = HALL ATTIC CELLAR
;        [HALL]
;        CODE   = 1
;        [ATTIC]
;        ENTERS = 1 7 12
;        ENDING = YES
;
;        mov  si,sGame
;        mov  di,sStart
;        xor  bx,bx
;        call INI_FIND           ; SI,CX = START's value
;        mov  di,cur
;        mov  bx,16
;        call INI_WORD           ; cur = the first scene
;  .scene:
;        mov  si,cur
;        call SCENESECT          ; the scan on the scene's first line
;        ...play it (INI_NEXT its lines until AL = 1) -> AX = its code...
;        call SCENENEXT          ; cur = the next; CF = 1 none: the end
;        jnc  .scene
;
;  (A value runs to the end of its line: no comment after it.)
;
;  copy: SCENESECT, SCENENEXT and their words (cand, scode).
;  define before: cur db 16 dup(0); sGame db 'GAME',0; sOrder db 'ORDER',0;
;        sEnters db 'ENTERS',0 (any section and key names you like)
;  calls: K_INI (INI_REWIND INI_NEXT INI_EQ INI_FIND INI_WORD INI_NUMAT)
;  needs: INI_READ (or INI_TEXT) of the file first
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:2441-2505 FINDNEXT (ORDER, ENTERS,
;        the code); the sections in one file new; proven by
;        KIT\T_ROOM\T_ROOM.ASM (HALL -> code 1 -> ATTIC -> ENDING)
; ============================================================================

; ----------------------------------------------------------------------
;@ SCENESECT  SI = a section's name: the INI scan stands on the line after its [NAME]
;  in:  SI = the name (0-ended), the INI read
;  out: CF = 1 no such section; else [ini_pos] is past its header, so
;       INI_NEXT reads its lines (and returns AL = 1 at the next section)
; ----------------------------------------------------------------------
SCENESECT:
        push ax
        push di
        call INI_REWIND
.l:     call INI_NEXT
        jc   .no                ; the end: not there
        cmp  al,1
        jne  .l
        mov  di,ini_key
        call INI_EQ             ; this section?
        jc   .l
.no:    pop  di
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ SCENENEXT  AX = a scene's exit code: cur = the first in ORDER whose ENTERS holds it
;  in:  AX = the code, [GAME] ORDER = names, each [NAME] ENTERS = numbers
;  out: CF = 0 cur = the next scene; CF = 1 none enters with that code
;       (cur kept: the story ends there). AX BX CX SI DI changed
; ----------------------------------------------------------------------
SCENENEXT:
        mov  [scode],ax
        mov  si,sGame
        mov  di,sOrder
        xor  bx,bx
        call INI_FIND           ; SI,CX = the ORDER list
        jc   .no
.w:     mov  di,cand
        mov  bx,16
        call INI_WORD           ; the next scene of ORDER
        jc   .no                ; the list is over
        push si
        push cx
        mov  si,cand
        mov  di,sEnters
        xor  bx,bx
        call INI_FIND           ; its ENTERS
        jc   .nx
.n:     call INI_NUMAT          ; each number of the list
        jc   .nx
        cmp  ax,[scode]
        jne  .n
        pop  cx                 ; found
        pop  si
        mov  si,cand
        mov  di,cur
        mov  cx,16
.c:     mov  al,[si]
        mov  [di],al            ; cur = cand (DS to DS: ES may be a buffer)
        inc  si                 ; the next letter
        inc  di                 ; ...
        loop .c
        clc
        ret
.nx:    pop  cx
        pop  si
        jmp  .w
.no:    stc
        ret

scode   dw 0                    ; SCENENEXT: the code looked for
cand    db 16 dup(0)            ;  the scene being looked at
