; ============================================================================
;  PERSP.ASM - Lesson 0F. Perspective: one divide, and what it costs.
;
;      FASM PERSP.ASM PERSP.COM
;
;      1  flat            lesson 0E's cube, z thrown away - remember this
;      2  the divide      the same cube: the far face is smaller now
;      3  it grows        the cube comes towards you, and for the first
;                         time in this course, it gets BIGGER
;      4  the table       the divide replaced by a lookup - drawn on top of
;                         the divided cube, with every pixel of difference
;                         painted red
;      5  the near plane  the cube comes at you and STOPS: the table has no
;                         row for a depth that close, and the program has
;                         promised never to ask
;      6  no guard        the divide, unprotected. It comes, it grows, and
;                         then the QUOTIENT DOES NOT FIT IN A BYTE. The
;                         machine fires INT 0 - and OUR OWN handler, put in
;                         place at Boot, says so in words and ends the
;                         program. Press ESC at stage 5 to skip it.
;
;  THE ONE FACT THIS LESSON HANDS OVER: perspective is one divide.
;
;      x' = x * d / z
;
;  Two similar triangles - the small one to the screen, the big one to the
;  point - and that is the whole of it. Far things divide by a bigger
;  number and come out smaller. Nothing else changes: the eight corners,
;  the twelve pairs, the two turns are lesson 0E's, byte for byte.
;
;  THE PHYSICAL FACT: THE DIVIDE IS THE MOST EXPENSIVE INSTRUCTION ON THIS
;  CHIP, AND THE ONLY ARITHMETIC THAT CAN STOP THE MACHINE. IDIV takes on
;  the order of a hundred clocks where the IMUL beside it takes eighty -
;  and when its answer does not fit the register, it does not round and it
;  does not saturate: it raises INT 0. Stage 6 does exactly that, on
;  purpose - and it is caught by a handler of our own, because the one
;  DOS hands you is not safe to demonstrate with. On an 8086 the return
;  address INT 0 pushes is the instruction AFTER the divide; on every chip
;  since, and in the emulators, it is the divide ITSELF. A handler that
;  merely returns re-runs the fault for ever, and the first dry run of this
;  program hung the emulator exactly so. Ours never returns.
;
;  SO WE DO IT TWICE, the way this course does everything it argues for.
;  Once with IDIV, because that is the formula and you should see it. Then
;  again with a TABLE of d/z - the sine table's trick, aimed at division -
;  and the two are drawn on top of each other so you can count the pixels
;  they disagree by. The table costs a lookup, a multiply and a shift, and
;  it cannot trap. Its two ends are the two clipping planes: row zero holds
;  nothing, and row 255 is the last depth that has an address.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

VGA     = 0A000h                ; the graphics screen: 320x200, no depth
W       = 320
H       = 200

CX0     = 160                   ; where the eye's axis meets the glass
CY0     = 100

NV      = 8                     ; eight corners, twelve joins: lesson 0E's
NE      = 12                    ;  model, unchanged

DEYE    = 270                   ; the eye to the screen, in model units:
                                ;  the SHORT leg of the small triangle -
                                ;  AND THE FIELD OF VIEW. 270 across a
                                ;  screen 160 wide each side is about
                                ;  sixty degrees, which is roughly where a
                                ;  viewer's own eye sits. The first build
                                ;  used 100 - a hundred and sixteen
                                ;  degrees, a fisheye - and the pilot's eye
                                ;  read the cube as a tapered box, because
                                ;  the picture was drawn for an eye almost
                                ;  touching the glass. d is where YOU are.
ZNEAR   = 95                    ; the near plane: no corner may be closer.
                                ;  Below it, x*D/z outruns a byte.
TZMIN   = 139                   ; ...so the cube's CENTRE stops here: the
                                ;  near plane plus the cube's own reach (44)
TZFAR   = 210                   ; and starts here, small in the distance -
                                ;  and no further, because a corner's depth
                                ;  must still fit the table's 255 rows
TZHOME  = 175                   ; where the still stages stand

EDGEC   = 15                    ; an edge is white
DIVC    = 8                     ; the divided cube, in stage 4: dark grey
DIFFC   = 12                    ; a pixel the two methods disagree on: red
ORGC    = 14                    ; the eye's axis on the glass: yellow

        jmp  Boot

; ============================================================================
;  Rot2 - lesson 12's matrix, exactly as lesson 0E used it. A turn about an
;  axis is a flat turn of the pair perpendicular to it. Nothing new here.
; ============================================================================
Rot2:   push ax
        mov  bx, SINTAB
        xlatb
        mov  [tsin], al
        pop  ax
        add  al, 64
        xlatb
        mov  [tcos], al
        mov  al, [tcos]
        imul byte [pa]
        mov  dx, ax
        mov  al, [tsin]
        imul byte [pb]
        sub  dx, ax
        mov  cl, 7
        sar  dx, cl
        mov  [t1], dl
        mov  al, [tsin]
        imul byte [pa]
        mov  dx, ax
        mov  al, [tcos]
        imul byte [pb]
        add  dx, ax
        sar  dx, cl
        mov  [pb], dl
        mov  al, [t1]
        mov  [pa], al
        ret

TurnY:  mov  al, [vx3]
        mov  [pa], al
        mov  al, [vz3]
        mov  [pb], al
        mov  al, [angy]
        call Rot2
        mov  al, [pa]
        mov  [vx3], al
        mov  al, [pb]
        mov  [vz3], al
        ret

TurnX:  mov  al, [vy3]
        mov  [pa], al
        mov  al, [vz3]
        mov  [pb], al
        mov  al, [angx]
        call Rot2
        mov  al, [pa]
        mov  [vy3], al
        mov  al, [pb]
        mov  [vz3], al
        ret

; ============================================================================
;  ProjDiv - PERSPECTIVE, THE HONEST WAY: one divide per coordinate.
;
;      x' = x * D / z         y' = y * D / z
;
;  in:  [vx3],[vy3] the corner, [depb] its depth from the eye, as a byte
;  out: [px],[py]   where it lands, relative to the eye's axis
;
;  IMUL byte [dcon] makes AX = x times FIFTY. Then IDIV byte [deph] divides
;  AX by HALF the depth, and leaves the quotient in AL, the remainder in AH.
;  Half and half, because IDIV reads its divisor as a SIGNED byte and a
;  depth of one hundred and sixty three is minus ninety three to it - the
;  far corners would divide by a negative number and land on the wrong
;  side of the axis. So both legs of the triangle are halved: x*50/(z/2)
;  is x*100/z to within a pixel, and the divisor never leaves 0..127.
;  IDIV and not DIV, because x is signed and a corner left of the axis
;  must land left of it.
;
;  AND READ THE TRAP, because stage 6 walks into it on purpose. IDIV's
;  quotient has to fit in AL: minus one hundred and twenty eight to plus
;  one hundred and twenty seven. Bring a corner close enough that x*D/z is
;  bigger than that, and the instruction does not round it and does not
;  clip it. It raises INT 0. On this chip that is the same interrupt as
;  dividing by zero, and Trap - our handler, below - answers it by ending
;  the program in words. The near plane exists so that this line is never
;  reached with such a number.
; ============================================================================
ProjDiv:
        mov  al, [vx3]
        imul byte [dcon]        ; AX = x * D, sign kept
        idiv byte [deph]        ; AL = x*D/z. AH = the remainder, unused.
        cbw                     ;  THIS is the instruction that can trap.
        mov  [px], ax
        mov  al, [vy3]
        imul byte [dcon]
        idiv byte [deph]
        cbw
        mov  [py], ax
        ret

; ============================================================================
;  ProjTab - PERSPECTIVE WITHOUT A DIVIDE: the table of d/z.
;
;      x' = x * RECIP[z] / 256
;
;  RECIP holds d/z in 8.8 fixed point, one WORD per depth, minted by
;  TOOLS\RecipTab. The divide becomes a lookup, one multiply and a shift:
;  the sine table's three moves, aimed at division. It cannot trap. What
;  it can do instead is LIE - rows below the near plane hold zero, and a
;  corner that reads one collapses to the middle of the screen. The near
;  plane is the promise never to read there.
;
;  IMUL WORD is new: multiply AX by a word, and the product is TWO words -
;  it lands in DX:AX, high half in DX. Ours never grows past AX (forty
;  three times seven hundred and twenty eight, the table's biggest row, is
;  thirty one thousand and change - under thirty two thousand seven
;  hundred, just), so DX is only the sign, and SAR AX by eight is the whole
;  of "/256". Read the product's size before you trust that shortcut in a
;  program of your own: raise d or lower the near plane and it breaks.
; ============================================================================
ProjTab:
        mov  bl, [depb]
        xor  bh, bh
        add  bx, bx             ; a word per row
        mov  ax, [RECIP+bx]     ; d/z, in 256ths
        mov  [rcp], ax
        mov  al, [vx3]
        cbw
        imul word [rcp]         ; DX:AX = x * d/z * 256
        mov  cl, 8
        sar  ax, cl             ; /256: the integer part, sign kept
        mov  [px], ax
        mov  al, [vy3]
        cbw
        imul word [rcp]
        sar  ax, cl
        mov  [py], ax
        ret

; ============================================================================
;  Xform - the pipeline of lesson 0E, with the projection swapped out.
;  Turn about Y, turn about X, push the cube out along Z by [tz] - and then
;  project by whichever method [pmode] names:
;
;      0  flat      x' = x           lesson 0E: z thrown away
;      1  divide    ProjDiv          the honest formula
;      2  table     ProjTab          the honest formula, without the DIV
;      3  both      ProjDiv into sxd/syd, ProjTab into sx/sy - for stage 4,
;                   which draws them on top of each other and counts
; ============================================================================
Xform:  mov  si, VERTS
        xor  di, di
        mov  cx, NV
.v:     push cx
        mov  al, [si]
        mov  [vx3], al
        mov  al, [si+1]
        mov  [vy3], al
        mov  al, [si+2]
        mov  [vz3], al
        push si
        push di
        call TurnY
        call TurnX
        pop  di
        pop  si

        mov  al, [vz3]          ; the DEPTH: this corner's distance from
        cbw                     ;  the eye along its axis. The cube's
        add  ax, [tz]           ;  centre is [tz] out; the corner is a
        mov  [depb], al         ;  little nearer or further. As a BYTE:
        shr  ax, 1              ;  the table has a row per depth, 0..255 -
        mov  [deph], al         ;  and the divide gets HALF of it, so that
                                ;  a signed byte can still hold it.
        mov  al, [pmode]
        cmp  al, 1
        je   .div
        cmp  al, 2
        je   .tab
        cmp  al, 3
        je   .both
        mov  al, [vx3]          ; ---- flat: the deleted coordinate ----
        cbw
        mov  [px], ax
        mov  al, [vy3]
        cbw
        mov  [py], ax
        jmp  .land
.div:   push si
        push di
        call ProjDiv
        pop  di
        pop  si
        jmp  .land
.both:  push si
        push di
        call ProjDiv            ; the divided answer, parked aside...
        pop  di
        pop  si
        mov  ax, [px]
        add  ax, CX0
        mov  [sxd+di], ax
        mov  ax, CY0
        sub  ax, [py]
        mov  [syd+di], ax
.tab:   push si
        push di
        call ProjTab            ; ...and the table's, which is what is drawn
        pop  di
        pop  si
.land:  mov  ax, [px]
        add  ax, CX0
        mov  [sx+di], ax
        mov  ax, CY0
        sub  ax, [py]           ; THE MINUS: paper y up, the beam draws down
        mov  [sy+di], ax
        add  si, 3
        add  di, 2
        pop  cx
        dec  cx                 ; LOOP reaches one signed byte backwards and
        jz   .done              ;  this body is longer than that. So: count
        jmp  .v                 ;  by hand, and let a JMP do the reaching.
.done:  ret                     ;  The assembler refusing was the good case.

; ============================================================================
;  Trap - OUR OWN INT 0, and it never returns.
;
;  The processor arrives here the instant IDIV cannot fit its quotient in
;  AL. What it pushed on the stack is a return address - and on an 8086
;  that address is the instruction after the divide, while on every chip
;  since (and in every emulator) it is the divide itself. Return, and the
;  divide runs again, and traps again, for ever: the first dry run of this
;  program did exactly that and hung the machine. So this handler does the
;  one thing that is safe on all of them - it does not go back. Text mode,
;  a sentence, and INT 21h function 4C. The program ends here, and it ends
;  saying what killed it.
;
;  Installed by Boot through INT 21h function 25h: AL the vector, DS:DX the
;  handler. In a COM file DS is CS, so DX alone names it.
; ============================================================================
Trap:   mov  ax, cs             ; the interrupt brings whatever DS it finds;
        mov  ds, ax             ;  ours is CS, and the string is in it
        mov  ax, 0003h          ; a text screen, so the words can be read
        int  10h
        mov  dx, t_trap
        mov  ah, 9
        int  21h
        mov  ax, 4C01h          ; and out, with a non-zero exit code
        int  21h

t_trap  db 'INT 0: the quotient did not fit in a byte.',13,10
        db 'A corner came closer than the near plane, and x*d/z outran AL.',13,10
        db 'The near plane was the promise never to ask the divide this.',13,10,'$'

; ---- the eye's axis, where it meets the glass: a small yellow cross ------
Axis:   mov  word [p0x], CX0-5
        mov  word [p1x], CX0+5
        mov  word [p0y], CY0
        mov  word [p1y], CY0
        mov  byte [col], ORGC
        call Line
        mov  word [p0x], CX0
        mov  word [p1x], CX0
        mov  word [p0y], CY0-5
        mov  word [p1y], CY0+5
        mov  byte [col], ORGC
        call Line
        ret

; ---- the edges, from whichever corner table [esrc] points at -------------
;  Lesson 0E's routine, with one change: it reads the corners through a
;  pointer, so stage 4 can draw the divided cube and the table's cube with
;  the same twelve lines.
Edges:  mov  si, EDGES
        mov  cx, NE
.e:     push cx
        mov  bx, [esrc]
        mov  al, [si]
        xor  ah, ah
        add  ax, ax
        add  bx, ax
        mov  ax, [bx]
        mov  [p0x], ax
        mov  ax, [bx+16]        ; the y table sits sixteen bytes after x
        mov  [p0y], ax
        mov  bx, [esrc]
        mov  al, [si+1]
        xor  ah, ah
        add  ax, ax
        add  bx, ax
        mov  ax, [bx]
        mov  [p1x], ax
        mov  ax, [bx+16]
        mov  [p1y], ax
        mov  al, [ecol]
        mov  [col], al
        push si
        call Line
        pop  si
        add  si, 2
        pop  cx
        loop .e
        ret

; ---- Differ: a red dot on every corner the two methods disagree about ----
;  "Disagree" means further apart than ONE pixel. A table in 256ths and a
;  divide that truncates will not land on the same pixel every time, and
;  painting those red would only teach that rounding exists. Two pixels
;  apart would be a wrong table. Count the red dots: there are none.
Differ: xor  di, di
        mov  cx, NV
.d:     push cx
        mov  ax, [sx+di]
        sub  ax, [sxd+di]
        cmp  ax, 1
        jg   .red
        cmp  ax, -1
        jl   .red
        mov  ax, [sy+di]
        sub  ax, [syd+di]
        cmp  ax, 1
        jg   .red
        cmp  ax, -1
        jge  .ok
.red:   mov  byte [dcol], DIFFC
        mov  ax, [sx+di]
        mov  bx, [sy+di]
        push di
        call Dot
        pop  di
.ok:    add  di, 2
        pop  cx
        loop .d
        ret

; ---- one whole picture ---------------------------------------------------
Frame:  call Vsync
        call GClear
        call Xform
        call Axis
        cmp  byte [pmode], 3
        jne  .one
        mov  word [esrc], sxd   ; stage 4: the divided cube underneath...
        mov  byte [ecol], DIVC
        call Edges
.one:   mov  word [esrc], sx    ; ...and the drawn one on top
        mov  byte [ecol], EDGEC
        call Edges
        cmp  byte [pmode], 3
        jne  .out
        call Differ             ; and the red dots, if there are any
.out:   ret

; ---- Spin: turn until a key --------------------------------------------
Spin:   call Frame
        mov  al, [stepy]
        add  [angy], al
        mov  al, [stepx]
        add  [angx], al
        call KeyChk
        or   al, al
        jz   Spin
        ret

; ---- Walk: slide along Z until a key ------------------------------------
;  Every [hold] frames, tz moves by [wdz]. At TZFAR it turns back. At TZMIN
;  it does what [guard] says: 1 bounce, 2 stop dead, 0 KEEP GOING - and
;  keeping going is stage 6, which does not come back.
Walk:   call Frame
        dec  byte [hcnt]
        jnz  .k
        mov  al, [hold]
        mov  [hcnt], al
        mov  al, [wdz]
        cbw
        add  [tz], ax
        cmp  word [tz], TZFAR
        jl   .n1
        neg  byte [wdz]
.n1:    cmp  word [tz], TZMIN
        jge  .k
        cmp  byte [guard], 0
        je   .k                 ; no guard: on towards the trap
        mov  word [tz], TZMIN   ; the NEAR PLANE: this far and no further
        cmp  byte [guard], 2
        je   .stop
        neg  byte [wdz]         ; bounce
        jmp  .k
.stop:  mov  byte [wdz], 0
.k:     call KeyChk
        or   al, al
        jz   Walk
        ret

; ============================================================================
;  THE MODEL - lesson 0E's, with the corners at twenty five instead of
;  forty so that the cube can come close before its edges outrun the
;  screen. Same eight corners from the same centre; same twelve pairs.
; ============================================================================
VERTS   db -25,-25,-25
        db  25,-25,-25
        db  25, 25,-25
        db -25, 25,-25
        db -25,-25, 25
        db  25,-25, 25
        db  25, 25, 25
        db -25, 25, 25

EDGES   db 0,1, 1,2, 2,3, 3,0
        db 4,5, 5,6, 6,7, 7,4
        db 0,4, 1,5, 2,6, 3,7

; ---- state ---------------------------------------------------------------
sx      dw NV dup (0)           ; the corners on the glass - what is drawn
sy      dw NV dup (0)
sxd     dw NV dup (0)           ; the DIVIDED corners, kept aside in stage 4
syd     dw NV dup (0)
esrc    dw sx                   ; which pair of tables Edges reads
ecol    db EDGEC

vx3     db 0
vy3     db 0
vz3     db 0
depb    db 0                    ; this corner's depth, as a byte...
deph    db 0                    ; ...and halved, for the signed divide
px      dw 0                    ; where it lands, relative to the axis
py      dw 0
pa      db 0
pb      db 0
t1      db 0
tsin    db 0
tcos    db 0
dcon    db DEYE/2              ; HALF the eye-to-screen distance - see ProjDiv
rcp     dw 0                    ; one row of RECIP, for IMUL WORD

angy    db 24
angx    db 20
stepy   db 0
stepx   db 0
tz      dw TZHOME               ; how far out the cube's centre sits
wdz     db 0
hold    db 1                    ; frames per step of the walk
hcnt    db 1
guard   db 1                    ; what happens at the near plane
pmode   db 0                    ; 0 flat, 1 divide, 2 table, 3 both
lastk   db 0                    ; the key that ended the last stage

include 'SINTAB.INC'
include 'RECIP.INC'
include 'DRAW15.INC'

; ============================================================================
Boot:   cld
        mov  ax, 2500h          ; INT 21h fn 25h: set interrupt vector AL
        mov  dx, Trap           ;  = 0, the divide fault, to DS:DX = Trap.
        int  21h                ;  From here on, an overflowing IDIV lands
                                ;  in our handler and not in DOS's, which
                                ;  would loop on the fault for ever.
        mov  ax, 0013h
        int  10h
        mov  ax, VGA
        mov  es, ax

; ---- 1. flat: lesson 0E's cube, z thrown away ----------------------------
        mov  byte [pmode], 0
        mov  word [tz], TZHOME
        call Frame
        call Key

; ---- 2. the divide: the same cube, and the far face is smaller -----------
        mov  byte [pmode], 1
        call Frame
        call Key

; ---- 3. it grows: the cube comes towards you, and back ------------------
        mov  word [tz], TZFAR
        mov  byte [wdz], -1
        mov  byte [hold], 2
        mov  byte [guard], 1    ; bounce off the near plane
        call Walk

; ---- 4. the table, drawn on the divide - count the red dots --------------
        mov  byte [pmode], 3
        mov  word [tz], TZHOME
        mov  byte [stepy], 1
        mov  byte [stepx], 0
        call Spin

; ---- 5. the near plane: it comes, and it STOPS ---------------------------
        mov  byte [pmode], 2
        mov  byte [stepy], 0
        mov  word [tz], TZFAR
        mov  byte [wdz], -1
        mov  byte [hold], 2
        mov  byte [guard], 2    ; stop dead at the plane
        call Walk
        mov  al, [lastk]
        cmp  al, 27             ; ESC here leaves cleanly. Anything else...
        je   Bye

; ---- 6. no guard: the divide, unprotected. This stage does not return. ---
;      The cube is at the near plane. Take the plane away and keep coming.
;      Within a few steps a corner's x*D/z will not fit in AL, IDIV raises
;      INT 0, and Trap ends the program with three lines of text. That is
;      not this program failing. That is the machine telling you what the
;      near plane was for, in the only voice it has.
        mov  byte [pmode], 1
        mov  word [tz], TZFAR   ; from the far end, all the way in: about
        mov  byte [wdz], -1     ;  five seconds of approach before the
        mov  byte [hold], 3     ;  quotient outruns the byte. From the
        mov  byte [guard], 0    ;  plane it took one second, and a crash
        call Walk               ;  nobody saw coming teaches nothing.
                                ; ...and it never gets back here

Bye:    mov  ax, 0003h          ; a clean screen back to DOS - reached only
        int  10h                ;  by ESC at stage 5
        mov  ax, 4C00h
        int  21h
