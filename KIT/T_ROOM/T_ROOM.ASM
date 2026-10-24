; ============================================================================
;@ T_ROOM     a point-and-click game: rooms, things to take, captions - all in ROOM.INI
;  T_ROOM.ASM - two rooms drawn with K_DRAW, things as text-art sprites, a
;  slot panel at the foot, a caption when a thing is taken, the mouse or
;  the keys (arrows move the pointer, Enter or Space clicks). A room is done
;  when every thing it NEEDs is taken; its CODE picks the next room - the
;  first in ORDER whose ENTERS holds it; ENDING = YES ends the game.
;
;  The game is ROOM.INI: rooms, colours, where each thing lies, what the
;  caption says. Edit it and play again - no build. A new kind of thing is
;  a text-art sprite here and a line in THINGS (the name the INI uses).
;  Copy the folder to A:\MY\NAME\, rename, grow it.
;
;  The shape:
;    memory (4Ah/48h) -> mode 13h -> ROOM.INI -> MOU_INIT
;    a room:  ROOMLOAD (its section: colours, ITEM lines, NEED) -> fade up
;             -> ROOMRUN (the loop of R_ROOM.ASM) -> fade down -> its CODE
;             -> SCENENEXT (R_SCENES.ASM) -> the next room, or the end
;  Esc quits at once. /AUTO: the pointer is walked to each wanted thing by
;  the arrow keys and Enter clicks it (the keyboard path, through the hit
;  test), the end is shown briefly, and a PASS line says what was taken.
;  LETTERS: K_FONT's - the title card is R_TITLE's TTLCARD over the first
;  room (TITLE; the words sName sSub sKeys), the room's name FNT_LSUB
;  ringed, THE END FNT_LTITLE. K_UI's captions and boxes stay K_TEXT's.
;  Uses: K_MOUSE K_HOT K_INI K_UI K_DRAW K_TEXT K_SPR K_VGA (VGA_FADE,
;  VGA_PALGET) K_TIME K_FONT, REC\R_TITLE. Build: KIT\MAKEWIN T_ROOM T_ROOM; on the site:
;  build A:\MY\NAME\NAME.ASM (ROOM.INI beside it)
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

MAXTH   = 6                     ; the most things a room holds
INISZ   = 4096                  ; the most ROOM.INI can be
PANELY  = 160                   ; the panel starts here: the room is above
AUTOCAP = 9                     ; /AUTO: a caption's ticks (else ui_caphold)

start:  cld
        call GETAUTO
        call OWNPATH            ; inipath = our folder + ROOM.INI
        ; memory: keep our 64K, ask DOS for the back buffer
        mov  ah,4Ah
        mov  bx,1000h           ; 64K in paragraphs
        int  21h                ; ES = our PSP already (a .COM starts so)
        mov  ah,48h
        mov  bx,0FA0h           ; 64000 bytes
        int  21h
        jnc  .mem
        mov  dx,sNoMem
        jmp  failtxt
.mem:   mov  [buf],ax
        ; the game's text
        mov  dx,inipath
        mov  di,inibuf
        mov  cx,INISZ
        call INI_READ
        jnc  .ini
        mov  dx,ininame         ; not beside us: the current folder
        mov  di,inibuf
        call INI_READ
        jnc  .ini
        mov  dx,sNoIni
        jmp  failtxt
.ini:   ; the sprites, compiled once
        mov  si,THINGS
        mov  di,sprbuf
.cmp:   cmp  word [si],0
        je   .cmpd
        mov  [si+4],di          ; where its compiled form goes
        push si
        mov  si,[si+2]          ; the text art
        call SPR_COMPILE        ; DI past it
        pop  si
        add  si,6               ; the next kind
        jmp  .cmp
.cmpd:  ; the screen
        mov  ax,0013h
        int  10h
        xor  al,al
        mov  cx,256
        mov  di,pal
        call VGA_PALGET         ; the BIOS palette: the fades' full level
        mov  si,pal
        xor  al,al
        call VGA_FADE           ; black until a room comes up
        mov  byte [ui_lvl],0
        call MOU_INIT           ; no driver: the keys still work
        mov  word [hot_maxy],PANELY
        mov  word [ui_show],SHOW
        mov  word [ui_capy],PANELY-14
        mov  word [ui_sloty],PANELY+6
        mov  word [ui_slotw],32
        mov  word [ui_sloth],30
        mov  byte [ui_grey],7
        mov  byte [txt_style],1 ; letters with a shadow
        cmp  byte [auto],1
        jne  .first
        mov  word [ui_caphold],AUTOCAP
        mov  word [mou_step],6  ; quicker steps (a +-3 window takes up to 7)
        mov  byte [ui_fstep],16 ; quicker fades
        ; the first room: [GAME] START
.first: mov  si,sGame
        mov  di,sStart
        xor  bx,bx
        call INI_FIND           ; SI = the value, CX = its length
        jc   .noroom
        mov  di,cur
        mov  bx,16
        call INI_WORD
        jnc  room
.noroom:
        mov  dx,sNoStart
        jmp  failgfx

room:   call ROOMLOAD           ; the things, the colours, NEED
        jc   .bad
        cmp  byte [titled],0    ; the first room: the title card over it
        jne  .play
        call TITLE              ; until Enter; CF = Esc
        jc   quit
.play:  mov  es,[buf]
        call DRAWALL
        call SHOW
        mov  si,pal
        call UI_FADEUP
        call ROOMRUN            ; until all is taken; CF = Esc
        jc   quit
        call RESULT             ; "room HALL: 3 taken, code 1" for the end
        mov  si,pal
        call UI_FADEDN
        ; ENDING = YES?
        mov  si,cur
        mov  di,sEnding
        xor  bx,bx
        call INI_FIND
        jc   .next
        jcxz .next
        mov  al,[si]
        and  al,0DFh            ; capital
        cmp  al,'Y'
        je   theend
.next:  mov  si,cur
        mov  di,sCode
        xor  bx,bx
        call INI_FIND
        jc   theend             ; no CODE: nothing follows
        mov  [ini_val],si
        mov  [ini_vlen],cx
        call INI_NUM            ; AX = the code
        call SCENENEXT          ; cur = the room it enters
        jnc  room
        jmp  theend
.bad:   mov  dx,sNoRoom
        jmp  failgfx

theend: mov  byte [ended],1
        mov  es,[buf]
        xor  al,al
        call FILLBUF
        mov  si,pal
        mov  al,64
        call VGA_FADE
        mov  byte [ui_lvl],64
        mov  si,sGame
        mov  di,sEndT
        xor  bx,bx
        call INI_FIND           ; [GAME] END = the last words
        mov  di,msg
        jnc  .e1
        mov  si,sTheEnd
        call TXT_LEN
.e1:    mov  bx,60
        call INI_COPY
        mov  al,FNT_LTITLE      ; THE END over the box: K_FONT's 8x8 x4,
        call FNT_LOOK           ;  the gold ramp, ring 2 + shadow
        mov  si,sEndBig
        mov  bx,160
        mov  dx,30
        call FNT_CENTER         ; into ES = the buffer; the box shows it
        mov  si,msg
        xor  dx,dx
        mov  ax,36              ; /AUTO: two seconds
        cmp  byte [auto],1
        je   .e2
        xor  ax,ax              ; a person: until a key
.e2:    call UI_MSGBOX

quit:   mov  ax,0003h
        int  10h                ; text mode 3, on every way out
        mov  ax,[buf]
        test ax,ax
        jz   .rep
        mov  es,ax
        mov  ah,49h
        int  21h                ; the buffer back to DOS
.rep:   push cs
        pop  es
        mov  si,outbuf
        call TXT_DOSZ           ; what each room gave
        cmp  byte [auto],1
        jne  .x
        mov  dx,sPass
        cmp  byte [ended],1
        jne  .f
        cmp  word [misses],0
        jne  .f
        cmp  word [rooms],2
        jae  .p
.f:     mov  dx,sFail
.p:     call TXT_DOS
        mov  ax,[rooms]
        call TXT_DOSNUM
        mov  dx,sPass2
        call TXT_DOS
        mov  ax,[total]
        call TXT_DOSNUM
        mov  dx,sPass3
        call TXT_DOS
        mov  ax,[misses]
        call TXT_DOSNUM
        call TXT_DOSCR
.x:     mov  ax,4C00h
        int  21h

failgfx:
        push dx
        mov  ax,0003h
        int  10h
        pop  dx
failtxt:
        call TXT_DOS
        mov  ax,4C01h
        int  21h

; ---------------------------------------------------------------------------
;  ROOMLOAD - the room named in cur: its colours and title, its things
;  (ITEM NAME = x,y with NAME in THINGS), which are needed. CF = no room.
; ---------------------------------------------------------------------------
ROOMLOAD:
        mov  word [nth],0
        mov  byte [title],0
        mov  word [taken],0
        mov  byte [wallc],6
        mov  byte [floorc],8
        mov  si,cur
        call SCENESECT          ; the scan stands after [cur]
        jc   .out
.l:     call INI_NEXT
        jc   .need
        cmp  al,1
        je   .need              ; the next room's section: done
        mov  di,ini_key
        mov  si,sWall
        call INI_EQ
        jc   .l1
        call INI_NUM
        mov  [wallc],al
        jmp  .l
.l1:    mov  si,sFloor
        call INI_EQ
        jc   .l2
        call INI_NUM
        mov  [floorc],al
        jmp  .l
.l2:    mov  si,sTitle
        call INI_EQ
        jc   .l3
        mov  si,[ini_val]
        mov  cx,[ini_vlen]
        mov  di,title
        mov  bx,40
        call INI_COPY
        jmp  .l
.l3:    mov  si,sItem
        call INI_EQ
        jc   .l
        mov  si,ini_sub
        call THINGFIND          ; BX = the kind, DI = its THINGS entry
        jc   .l                 ; a name we have no picture for
        cmp  word [nth],MAXTH
        jae  .l
        mov  [kind],bx
        mov  si,[ini_val]
        mov  cx,[ini_vlen]
        call INI_NUMAT          ; x
        mov  bx,ax
        call INI_NUMAT          ; y
        mov  dx,ax
        mov  si,[di+4]          ; its compiled sprite
        push bx
        mov  bx,[nth]
        push si
        mov  si,things
        call HOT_ENTRY          ; DI = thing nth
        pop  si
        pop  bx
        call HOT_PUT
        mov  al,byte [kind]
        mov  [di+HOT_USER],al   ; which kind it is (its name, its caption)
        inc  word [nth]         ; one thing more
        jmp  .l
.need:  ; NEED = names: those; none or empty: all of them
        mov  si,cur
        mov  di,sNeed
        xor  bx,bx
        call INI_FIND
        jc   .all
        jcxz .all
.w:     mov  di,word1
        mov  bx,16
        call INI_WORD           ; the next name of the list
        jc   .done
        push si
        push cx
        xor  bx,bx              ; every thing of that name: needed
.t:     cmp  bx,[nth]
        jae  .tn
        push di
        mov  si,things
        call HOT_ENTRY
        mov  al,[di+HOT_USER]
        pop  di
        call KINDNAME           ; SI = the name of kind AL
        call INI_EQ             ; the same as the word at DI?
        jc   .t1
        push di
        mov  si,things
        call HOT_ENTRY
        or   byte [di+HOT_FLAGS],HOT_NEEDED
        pop  di
.t1:    inc  bx                 ; the next thing
        jmp  .t
.tn:    pop  cx
        pop  si
        jmp  .w
.all:   mov  si,things
        mov  cx,[nth]
        call HOT_NEEDALL
.done:  inc  word [rooms]       ; one room more played
        clc
.out:   ret

; THINGFIND - SI = a name: BX = its kind (0..), DI = its THINGS entry; CF none
THINGFIND:
        push si
        mov  di,THINGS
        xor  bx,bx
.l:     cmp  word [di],0
        je   .no
        push di
        mov  di,[di]            ; the kind's name
        call INI_EQ
        pop  di
        jnc  .yes
        add  di,6               ; the next kind
        inc  bx                 ; its number
        jmp  .l
.no:    stc
.yes:   pop  si
        ret

; KINDNAME - AL = a kind: SI = its name
KINDNAME:
        push ax
        push bx
        xor  ah,ah
        mov  bx,ax
        shl  bx,1               ; kind * 2
        add  bx,ax              ; kind * 3
        shl  bx,1               ; kind * 6: an entry
        mov  si,[THINGS+bx]
        pop  bx
        pop  ax
        ret

; ---------------------------------------------------------------------------
;  DRAWALL - the room into the buffer (ES): walls, floor, door, window,
;  title, the things still there, the panel. The picture between two takes.
; ---------------------------------------------------------------------------
DRAWALL:
        mov  al,[wallc]
        mov  [drw_col],al
        xor  ax,ax
        xor  bx,bx
        mov  cx,320
        mov  dx,110
        call DRW_RECT           ; the wall
        mov  al,[floorc]
        mov  [drw_col],al
        xor  ax,ax              ; from the left edge
        mov  bx,110
        mov  dx,PANELY-110
        call DRW_RECT           ; the floor
        mov  byte [drw_col],0
        mov  cx,320
        call DRW_HLINE          ; the skirting
        mov  byte [drw_col],6
        mov  ax,24
        mov  bx,36
        mov  cx,44
        mov  dx,74
        call DRW_RECT           ; the door
        mov  byte [drw_col],0
        call DRW_FRAME
        mov  byte [drw_col],14
        mov  ax,58
        mov  bx,76
        mov  cx,3
        mov  dx,3
        call DRW_RECT           ; its handle
        mov  byte [drw_col],1
        mov  ax,226
        mov  bx,22
        mov  cx,64
        mov  dx,44
        call DRW_RECT           ; the window: the night
        mov  byte [drw_col],15
        call DRW_FRAME
        mov  ax,258
        mov  bx,22
        mov  cx,44
        call DRW_VLINE          ; its bars
        mov  ax,226
        mov  bx,44
        mov  cx,64
        call DRW_HLINE
        mov  byte [drw_col],0
        xor  ax,ax
        mov  bx,PANELY
        mov  cx,320
        mov  dx,200-PANELY
        call DRW_RECT           ; the panel's ground
        cmp  byte [intitle],0   ; under the title card: no name (the
        jne  .nn                ;  card's own is there)
        mov  al,FNT_LSUB        ; the room's name: K_FONT 8x8 x2 smooth,
        call FNT_LOOK           ;  ringed black - it reads on any wall
        mov  si,title
        mov  bx,6
        mov  dx,4
        call FNT_PUT
.nn:
        mov  si,things
        mov  cx,[nth]
        call HOT_DRAW
        call UI_PANEL
        ret

; TITLE - R_TITLE's title card over the first room, faded up; until Enter
; or Space (CF = 0) or Esc (CF = 1). /AUTO: 12 ticks.
TITLE:  mov  byte [titled],1
        mov  byte [intitle],1
        mov  word [ttl_name],sName ; our words on the card
        mov  word [ttl_sub],sSub
        mov  word [ttl_keys],sKeys
        mov  es,[buf]
        call DRAWALL
        call TIM_TICK
        call TTLCARD
        call SHOW
        mov  si,pal
        call UI_FADEUP          ; up from black, the card on it
        call TIM_TICK
        mov  [tt0],ax
.f:     mov  es,[buf]
        call DRAWALL            ; the room...
        call TIM_TICK           ; AX = the tick: PRESS ENTER blinks by it
        call TTLCARD            ; ...the card over it
        call SHOW
        cmp  byte [auto],1
        jne  .key
        call TIM_TICK
        sub  ax,[tt0]           ; ticks shown
        cmp  ax,12
        jb   .f
        jmp  .go
.key:   mov  ah,1
        int  16h                ; a key waiting?
        jz   .f
        xor  ah,ah
        int  16h
        cmp  al,27
        je   .esc
        cmp  al,13
        je   .go
        cmp  al,' '
        jne  .f
.go:    mov  byte [intitle],0
        clc
        ret
.esc:   stc
        ret

; FILLBUF - the whole buffer (ES) colour AL
FILLBUF:
        push cx
        push di
        mov  ah,al
        xor  di,di
        mov  cx,32000
        rep  stosw
        pop  di
        pop  cx
        ret

; SHOW - the buffer to the screen after the retrace starts. All kept.
SHOW:   push ax
        push cx
        push dx
        push si
        push di
        push ds
        push es
        mov  dx,3DAh
.w1:    in   al,dx
        test al,8
        jnz  .w1                ; out of a retrace in progress
.w2:    in   al,dx
        test al,8
        jz   .w2                ; the next one begins
        mov  ax,0A000h
        mov  es,ax
        mov  ds,[cs:buf]
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  es
        pop  ds
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  ax
        ret

; RESULT - "room NAME: N taken, code C" + CR LF onto outbuf
RESULT: mov  di,[outp]
        mov  si,sRoom
        call STRCAT
        mov  si,cur
        call STRCAT
        mov  si,sColon
        call STRCAT
        mov  ax,[taken]
        add  [total],ax         ; the game's count
        mov  cl,1
        call TXT_UTOA
        mov  si,sTaken
        call STRCAT
        mov  si,cur
        push di
        mov  di,sCode
        xor  bx,bx
        call INI_FIND
        pop  di
        jc   .nc
        mov  [ini_val],si
        mov  [ini_vlen],cx
        call INI_NUM
        mov  cl,1
        call TXT_UTOA
.nc:    mov  byte [di],13
        mov  byte [di+1],10
        mov  byte [di+2],0
        add  di,2               ; past CR LF: the next line goes here
        mov  [outp],di
        ret

; STRCAT - the 0-ended SI onto DI (DI past it, no 0 written)
STRCAT: lodsb
        test al,al
        jz   .o
        mov  [di],al
        inc  di                 ; the next place
        jmp  STRCAT
.o:     ret

; GETAUTO - [auto] = 1 if the command line holds /A (/AUTO)
GETAUTO:
        mov  si,81h
        mov  cl,[80h]
        xor  ch,ch
        jcxz .no
.l:     lodsb
        cmp  al,'/'
        jne  .n
        mov  al,[si]
        and  al,0DFh            ; capital
        cmp  al,'A'
        jne  .n
        mov  byte [auto],1
.n:     loop .l
.no:    ret

; OWNPATH - inipath = the folder we were started from + ROOM.INI
; (from: KIT\REC\R_LEVELS.ASM FINDDIR - GAMES\MULTSOK2\MULTSOK2.ASM:498-530)
OWNPATH:
        push es
        push ds
        pop  es
        mov  di,inipath
        mov  bx,di              ; where the file name goes
        mov  ax,[2Ch]           ; PSP:2Ch, the environment
        test ax,ax
        jz   .name
        push ds
        mov  ds,ax
        xor  si,si
.scan:  cmp  word [si],0        ; the double zero ends the variables
        je   .end
        inc  si                 ; the next byte
        cmp  si,32000
        jb   .scan
        pop  ds
        jmp  .name
.end:   add  si,4               ; past it and the count: our own path
        mov  cx,100
.copy:  lodsb
        mov  [es:di],al
        inc  di                 ; the next place
        test al,al
        jz   .done
        cmp  al,'\'
        je   .sl
        cmp  al,':'
        jne  .nx
.sl:    mov  bx,di              ; the name goes after the last \ or :
.nx:    loop .copy
.done:  pop  ds
.name:  mov  di,bx
        mov  si,ininame
.c:     lodsb
        stosb
        test al,al
        jnz  .c
        pop  es
        ret

; ===========================================================================
;  R_ROOM.ASM - the room's loop (copied from KIT\REC\R_ROOM.ASM)
; ===========================================================================

; ----------------------------------------------------------------------
;   ROOMRUN    the room's loop: pointer by mouse or keys, clicks take things, until all needed
;  in:  the room drawn in [buf] (DRAWALL), things / nth with NEEDED marks
;  out: CF = 1 Esc was pressed; CF = 0 every needed thing taken (the
;       room's DONE line, if it has one, was shown)
; ----------------------------------------------------------------------
ROOMRUN:
        mov  es,[buf]
        mov  ax,160
        mov  bx,80
        call MOU_SET            ; the pointer in the room's middle
.fl:    mov  ah,1
        int  16h                ; keys typed before the room: thrown away
        jz   .frame
        xor  ah,ah
        int  16h
        jmp  .fl
.frame: mov  ah,1
        int  16h                ; a key?
        jz   .nokey
        xor  ah,ah
        int  16h                ; AH = scan code, AL = character
        cmp  al,27
        je   .esc
        call MOU_KEYS           ; arrows: the pointer; Enter/Space: a click
.nokey: cmp  byte [auto],1
        jne  .mouse
        call AUTOSTEP           ; /AUTO: one arrow or Enter, as a person would
.mouse: call MOU_READ           ; the mouse moves the same pointer
        call MOU_CLICK          ; CF: a click since the last frame, at AX,BX
        jnc  .noclk
        mov  dx,bx
        mov  si,things
        mov  cx,[nth]
        call HOT_HIT            ; BX = the thing clicked
        jnc  .take
        cmp  byte [auto],1      ; /AUTO clicks only where a thing is:
        jne  .noclk             ; a miss is the hit test's fault -
        inc  word [misses]      ; counted, and the thing taken anyway
        call HOT_NEXTWANTED     ; so the run goes on and says why
        jc   .noclk
.take:  call TAKE
.noclk: mov  es,[buf]
        call UI_CAPCHECK        ; a caption whose time is up comes down
        mov  si,things
        mov  cx,[nth]
        call HOT_ALLTAKEN       ; CF: the room is done
        jc   .done
        call PRESENT
        jmp  .frame
.done:  call PRESENT            ; the last caption on the screen
        call UI_CAPWAIT         ; ... gets its time
        call SHOW
        mov  si,cur
        mov  di,sDone
        xor  bx,bx
        call INI_FIND           ; DONE = the room's last words
        jc   .ok
        mov  di,msg
        mov  bx,60
        call INI_COPY
        mov  si,msg
        xor  dx,dx
        xor  ax,ax              ; a person: until a key
        cmp  byte [auto],1
        jne  .box
        mov  ax,AUTOCAP         ; /AUTO: a moment
.box:   call UI_MSGBOX
.ok:    clc
        ret
.esc:   stc
        ret

; ----------------------------------------------------------------------
;   TAKE       thing BX is taken: the room redrawn without it, its slot lit, its caption up
;  in:  BX = the thing, ES = [buf]
;  out: - ([taken] counted)
; ----------------------------------------------------------------------
TAKE:   push bx
        mov  si,things
        call HOT_TAKE
        inc  word [taken]       ; one more taken
        call UI_CAPHIDE         ; the old caption down BEFORE the redraw
        call DRAWALL            ; the thing gone, its slot in colour
        pop  bx
        mov  si,things
        call HOT_ENTRY
        mov  al,[di+HOT_USER]
        call KINDNAME           ; SI = its name
        mov  bx,si
        mov  si,cur
        mov  di,sText
        call INI_FIND           ; TEXT NAME = what it says
        jc   .o
        mov  di,msg
        mov  bx,60
        call INI_COPY
        mov  si,msg
        call UI_CAPTION
.o:     ret

; ----------------------------------------------------------------------
;   PRESENT    the frame: the pointer (a hand over a thing) into the buffer, shown, taken out
;  in:  [buf], [mou_x] [mou_y]
;  out: - (the buffer exactly as before)
; ----------------------------------------------------------------------
PRESENT:
        mov  es,[buf]
        mov  word [mou_shape],MOU_ARROW8
        mov  ax,[mou_x]
        mov  dx,[mou_y]
        mov  si,things
        mov  cx,[nth]
        call HOT_HIT
        jc   .draw
        mov  word [mou_shape],MOU_HAND8 ; over a thing: the hand
.draw:  call MOU_CURDRAW
        call SHOW
        call MOU_CURHIDE
        ret

; ----------------------------------------------------------------------
;   AUTOSTEP   /AUTO: one arrow key toward the next wanted thing, or Enter on it
;  in:  things / nth, [mou_x] [mou_y], [mou_step] (pointer within +-3 of
;       the middle clicks; a step of at most 7 always gets there)
;  out: - (a key fed to MOU_KEYS, exactly as a person's)
; ----------------------------------------------------------------------
AUTOSTEP:
        mov  si,things
        mov  cx,[nth]
        call HOT_NEXTWANTED     ; BX = where to go
        jc   .o
        call HOT_CENTRE         ; AX,DX = its middle
        mov  bx,[mou_x]
        sub  bx,ax              ; pointer - target, across
        cmp  bx,-3
        jge  .x1
        mov  ah,4Dh             ; right
        jmp  .key
.x1:    cmp  bx,3
        jle  .y
        mov  ah,4Bh             ; left
        jmp  .key
.y:     mov  bx,[mou_y]
        sub  bx,dx              ; pointer - target, down
        cmp  bx,-3
        jge  .y1
        mov  ah,50h             ; down
        jmp  .key
.y1:    cmp  bx,3
        jle  .clk
        mov  ah,48h             ; up
        jmp  .key
.clk:   mov  ah,1Ch             ; there: Enter
.key:   call MOU_KEYS
.o:     ret
; ===========================================================================
;  R_SCENES.ASM - rooms chained by codes (copied from KIT\REC\R_SCENES.ASM)
; ===========================================================================

; ----------------------------------------------------------------------
;   SCENESECT  SI = a section's name: the INI scan stands on the line after its [NAME]
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
;   SCENENEXT  AX = a scene's exit code: cur = the first in ORDER whose ENTERS holds it
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

; ---------------------------------------------------------------------------
;  The kinds of things: the name the INI uses, its text art, its compiled
;  sprite (filled in at the start). A new kind: a sprite and a line here.
; ---------------------------------------------------------------------------
THINGS  dw nKey,KEY,0
        dw nLamp,LAMP,0
        dw nBook,BOOK,0
        dw nFeather,FEATHER,0
        dw nCandle,CANDLE,0
        dw 0
nKey    db 'KEY',0
nLamp   db 'LAMP',0
nBook   db 'BOOK',0
nFeather db 'FEATHER',0
nCandle db 'CANDLE',0

KEY     db 14,5
        db '.EEE..........'
        db 'E...E.........'
        db 'E...EEEEEEEEE.'
        db 'E...E....E.EE.'
        db '.EEE.....E..E.'
LAMP    db 10,13
        db '....CC....'
        db '...CEEC...'
        db '....EE....'
        db '...7777...'
        db '..7.FF.7..'
        db '..7.FF.7..'
        db '...7777...'
        db '..666666..'
        db '.66666666.'
        db '.66EEEE66.'
        db '.66666666.'
        db '..666666..'
        db '...6666...'
BOOK    db 14,10
        db '11111111111...'
        db '199999999991..'
        db '1999EE9999911.'
        db '199999999991F1'
        db '199999999991F1'
        db '199999999991F1'
        db '199999999991F1'
        db '11111111111FF1'
        db '.1FFFFFFFFFF11'
        db '..111111111111'
FEATHER db 12,12
        db '.........FF.'
        db '........FFF.'
        db '.......FF7F.'
        db '......FF7F..'
        db '.....FF7F...'
        db '....FF7F....'
        db '...FF7F.....'
        db '..FF7F......'
        db '..F7F.......'
        db '.F7.........'
        db '.7..........'
        db '7...........'
CANDLE  db 6,14
        db '..E...'
        db '.EEE..'
        db '.ECE..'
        db '..0...'
        db '.FFFF.'
        db '.FFF7.'
        db '.FFF7.'
        db '.FFF7.'
        db '.FFF7.'
        db '.FFF7.'
        db '.FFF7.'
        db '666666'
        db '.6666.'
        db '......'

ininame db 'ROOM.INI',0
sGame   db 'GAME',0
sStart  db 'START',0
sOrder  db 'ORDER',0
sEnters db 'ENTERS',0
sEnding db 'ENDING',0
sCode   db 'CODE',0
sNeed   db 'NEED',0
sWall   db 'WALL',0
sFloor  db 'FLOOR',0
sTitle  db 'TITLE',0
sItem   db 'ITEM',0
sText   db 'TEXT',0
sDone   db 'DONE',0
sEndT   db 'END',0
sTheEnd db 'THE END',0
sRoom   db 'room ',0
sColon  db ': ',0
sTaken  db ' taken, code ',0
sNoMem  db 'No memory for the picture.',13,10,'$'
sNoIni  db 'ROOM.INI is not here (beside T_ROOM or in this folder).',13,10,'$'
sNoStart db 'ROOM.INI: [GAME] has no START = room.',13,10,'$'
sNoRoom db 'ROOM.INI: a room named by START or ENTERS has no [section].',13,10,'$'
sPass   db 'PASS T_ROOM: rooms $'
sFail   db 'FAIL T_ROOM: rooms $'
sPass2  db ', things taken by the keyboard path $'
sPass3  db ', clicks that missed $'

auto    db 0
ended   db 0
titled  db 0                    ; the title card has been shown
intitle db 0                    ; 1: it is up now (DRAWALL leaves the name out)
tt0     dw 0                    ; TITLE: the tick it began
sName   db 'Owl House',0        ; the title card's words (R_TITLE TTLCARD)
sSub    db 'point, click, take',0
sKeys   db 'Mouse',0,'point, click',0 ; the key, what it does...
        db 'Arrows',0,'move the hand',0
        db 'Enter',0,'click',0
        db 'Esc',0,'quit',0
        db 0                    ; ...an empty key ends them
sEndBig db 'The End',0
wallc   db 6
floorc  db 8
buf     dw 0
nth     dw 0                    ; things in this room
taken   dw 0                    ; ... taken
total   dw 0                    ; things taken in the game
rooms   dw 0
misses  dw 0                    ; /AUTO clicks the hit test refused
kind    dw 0
outp    dw outbuf
cur     db 16 dup(0)            ; the room playing
title   db 40 dup(0)
word1   db 16 dup(0)
msg     db 64 dup(0)
outbuf  db 400 dup(0)
things  db MAXTH*HOT_SIZE dup(0)

        include '..\..\KIT\LIB\K_MOUSE.INC'
        include '..\..\KIT\LIB\K_HOT.INC'
        include '..\..\KIT\LIB\K_INI.INC'
        include '..\..\KIT\LIB\K_UI.INC'
        include '..\..\KIT\LIB\K_DRAW.INC'
        include '..\..\KIT\LIB\K_TEXT.INC'
        include '..\..\KIT\LIB\K_SPR.INC'
        include '..\..\KIT\LIB\K_VGA.INC'
        include '..\..\KIT\LIB\K_TIME.INC' ; TIM_TICK (the title's blink)
        include '..\..\KIT\LIB\K_FONT.INC' ; the good letters (FNT_*)
        include '..\..\KIT\REC\R_TITLE.ASM' ; TTLCARD, the title card

inipath rb 128
pal     rb 768
sprbuf  rb 1200                 ; the compiled sprites
inibuf  rb INISZ
