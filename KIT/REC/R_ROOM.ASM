; ============================================================================
;  R_ROOM.ASM - recipe: the point-and-click room - the pointer by mouse or
;  keys, a click takes a thing, its slot lights, its caption shows, and the
;  room ends when every needed thing is taken.
;
;  OWL NIGHT's pickup (LAB\OWLFLY4\ENGINE\STORY.ASM RUNPICKUP 541-820) as
;  8086 blocks: the background and the things are drawn into a back
;  buffer; every frame the pointer goes into it (save-under), the buffer to
;  the screen, the pointer out again. A take redraws the picture once (the
;  thing gone, its slot in colour) and raises a caption. The keys always
;  work (an emulator may not have the mouse yet, a phone has none), and
;  /AUTO walks the pointer to each wanted thing BY THE ARROW KEYS and clicks
;  with Enter - through the same hit test a person's click goes through
;  (OWL NIGHT's first /AUTO took things by index and the hit test had
;  never once run when a person clicked and nothing happened).
;
;        call ROOMLOAD           ; yours: things, nth, NEEDED flags
;        mov  es,[buf]
;        call DRAWALL            ; yours
;        call SHOW
;        call ROOMRUN            ; CF = 1 Esc; else all needed are taken
;
;  copy: ROOMRUN, TAKE, PRESENT, AUTOSTEP.
;  define before: buf (the back buffer's segment), things / nth (K_HOT's
;        table and count), cur (the room's INI section name), msg (64
;        bytes), auto (1 = /AUTO), misses / taken (words), sDone db
;        'DONE',0, sText db 'TEXT',0, AUTOCAP (a caption's ticks in
;        /AUTO); DRAWALL (the whole room into ES: background, HOT_DRAW,
;        UI_PANEL), SHOW (the buffer to the screen; also [ui_show]),
;        KINDNAME (AL = a thing's HOT_USER byte -> SI = its name in the INI)
;  calls: K_MOUSE (MOU_KEYS MOU_READ MOU_CLICK MOU_SET MOU_CURDRAW
;        MOU_CURHIDE), K_HOT (HOT_HIT HOT_TAKE HOT_ALLTAKEN HOT_NEXTWANTED
;        HOT_CENTRE HOT_ENTRY), K_UI (UI_CAPTION UI_CAPCHECK UI_CAPWAIT
;        UI_CAPHIDE UI_MSGBOX), K_INI (INI_FIND INI_COPY)
;  needs: MOU_INIT, [hot_maxy] = the panel's top, [ui_show] = SHOW
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:541-820 RUNPICKUP (its loop: keys as
;        a mouse 603-674, /AUTO through HITTEST 685-745, the mouse 747-800,
;        ALLTAKEN + CAPTWAIT 802-807); proven by KIT\T_ROOM\T_ROOM.ASM
; ============================================================================

; ----------------------------------------------------------------------
;@ ROOMRUN    the room's loop: pointer by mouse or keys, clicks take things, until all needed
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
;@ TAKE       thing BX is taken: the room redrawn without it, its slot lit, its caption up
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
;@ PRESENT    the frame: the pointer (a hand over a thing) into the buffer, shown, taken out
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
;@ AUTOSTEP   /AUTO: one arrow key toward the next wanted thing, or Enter on it
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
