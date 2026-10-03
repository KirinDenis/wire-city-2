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

        jmp  Boot               ; over the routines, to the boot at the bottom

; ============================================================================
;  Rot2 - lesson 12's matrix, exactly as lesson 0E used it. A turn about an
;  axis is a flat turn of the pair perpendicular to it. Nothing new here.
; ============================================================================
;  In C:
;
;      void rot2(int a)                     /* turns the byte pair (pa, pb) */
;      {
;          int s = SINTAB[a];               /* sin * 127, -127..127         */
;          int c = SINTAB[(a + 64) & 255];  /* cos = sin a quarter turn on  */
;          int na = (pa * c - pb * s) >> 7; /* the matrix, row one          */
;          int nb = (pa * s + pb * c) >> 7; /*             row two          */
;          pa = na;  pb = nb;               /* row two used the OLD pa      */
;      }
Rot2:   push ax                 ; keep a
        mov  bx, SINTAB         ; BX = the table
        xlatb                   ; AL = SINTAB[a] = s
        mov  [tsin], al         ; tsin = s
        pop  ax                 ; AL = a
        add  al, 64             ; AL = a + 64  (wraps: a byte is the circle)
        xlatb                   ; AL = SINTAB[a + 64] = c
        mov  [tcos], al         ; tcos = c
        mov  al, [tcos]         ; AL = c
        imul byte [pa]          ; AX = pa * c
        mov  dx, ax             ; DX = pa * c
        mov  al, [tsin]         ; AL = s
        imul byte [pb]          ; AX = pb * s
        sub  dx, ax             ; DX = pa * c - pb * s   in 128ths
        mov  cl, 7              ; CL = 7
        sar  dx, cl             ; DX >>= 7: / 128
        mov  [t1], dl           ; t1 = na   PARKED: nb still wants the old pa
        mov  al, [tsin]         ; AL = s
        imul byte [pa]          ; AX = pa * s
        mov  dx, ax             ; DX = pa * s
        mov  al, [tcos]         ; AL = c
        imul byte [pb]          ; AX = pb * c
        add  dx, ax             ; DX = pa * s + pb * c
        sar  dx, cl             ; DX >>= 7
        mov  [pb], dl           ; pb = nb
        mov  al, [t1]           ; AL = na
        mov  [pa], al           ; pa = na   ...and only now may it land
        ret                     ; return

;  In C:   pa = vx3; pb = vz3; rot2(angy); vx3 = pa; vz3 = pb;   - about Y: the pair is (x, z)
TurnY:  mov  al, [vx3]          ; AL = vx3
        mov  [pa], al           ; pa = vx3
        mov  al, [vz3]          ; AL = vz3
        mov  [pb], al           ; pb = vz3
        mov  al, [angy]         ; AL = angy
        call Rot2               ; rot2(angy)
        mov  al, [pa]           ; AL = pa
        mov  [vx3], al          ; vx3 = pa
        mov  al, [pb]           ; AL = pb
        mov  [vz3], al          ; vz3 = pb
        ret                     ; return

;  In C:   pa = vy3; pb = vz3; rot2(angx); vy3 = pa; vz3 = pb;   - about X: the pair is (y, z)
TurnX:  mov  al, [vy3]          ; AL = vy3
        mov  [pa], al           ; pa = vy3
        mov  al, [vz3]          ; AL = vz3
        mov  [pb], al           ; pb = vz3
        mov  al, [angx]         ; AL = angx
        call Rot2               ; rot2(angx)
        mov  al, [pa]           ; AL = pa
        mov  [vy3], al          ; vy3 = pa
        mov  al, [pb]           ; AL = pb
        mov  [vz3], al          ; vz3 = pb
        ret                     ; return

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
;  In C:
;
;      void proj_div(void)
;      {
;          px = vx3 * dcon / deph;      /* dcon = D/2, deph = z/2: x*D/z    */
;          py = vy3 * dcon / deph;      /* ...and this divide can TRAP      */
;      }
;
;  In C the quotient simply becomes an int. On the 8086 a byte IDIV must
;  fit its quotient in AL, and a corner too close does not: INT 0.
ProjDiv:
        mov  al, [vx3]          ; AL = vx3
        imul byte [dcon]        ; AX = vx3 * dcon = x * D/2, sign kept
        idiv byte [deph]        ; AL = AX / deph = x*D/z. AH = the remainder,
                                ;  unused. THIS is the instruction that can trap
        cbw                     ; AX = AL, sign and all
        mov  [px], ax           ; px = AX
        mov  al, [vy3]          ; AL = vy3
        imul byte [dcon]        ; AX = vy3 * dcon
        idiv byte [deph]        ; AL = y*D/z
        cbw                     ; AX = AL
        mov  [py], ax           ; py = AX
        ret                     ; return

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
;  In C:
;
;      void proj_tab(void)
;      {
;          rcp = RECIP[depb];               /* d/z * 256, one word a row   */
;          px = (vx3 * rcp) >> 8;           /* the divide, as a multiply   */
;          py = (vy3 * rcp) >> 8;
;      }
ProjTab:
        mov  bl, [depb]         ; BL = depb, the depth 0..255
        xor  bh, bh             ; BX = depb
        add  bx, bx             ; BX = depb * 2: a word per row
        mov  ax, [RECIP+bx]     ; AX = RECIP[depb]: d/z, in 256ths
        mov  [rcp], ax          ; rcp = AX
        mov  al, [vx3]          ; AL = vx3
        cbw                     ; AX = vx3
        imul word [rcp]         ; DX:AX = vx3 * rcp = x * d/z * 256
        mov  cl, 8              ; CL = 8
        sar  ax, cl             ; AX >>= 8: /256, the integer part, sign kept
        mov  [px], ax           ; px = AX
        mov  al, [vy3]          ; AL = vy3
        cbw                     ; AX = vy3
        imul word [rcp]         ; DX:AX = vy3 * rcp
        sar  ax, cl             ; AX >>= 8
        mov  [py], ax           ; py = AX
        ret                     ; return

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
;  In C:
;
;      void xform(void)
;      {
;          for (int i = 0; i < NV; i++) {
;              vx3 = VERTS[i*3]; vy3 = VERTS[i*3+1]; vz3 = VERTS[i*3+2];
;              turn_y();  turn_x();
;              int z = vz3 + tz;                 /* the corner's depth       */
;              depb = z;  deph = z / 2;          /* a byte, and half a byte  */
;              switch (pmode) {
;                  case 0:  px = vx3;  py = vy3;                  break; /* flat  */
;                  case 1:  proj_div();                           break;
;                  case 3:  proj_div();                                   /* both: */
;                           sxd[i] = CX0 + px;  syd[i] = CY0 - py;        /* park  */
;                           /* fall through */
;                  case 2:  proj_tab();                           break;
;              }
;              sx[i] = CX0 + px;
;              sy[i] = CY0 - py;                 /* paper y up, beam down    */
;          }
;      }
Xform:  mov  si, VERTS          ; SI = &VERTS[0]
        xor  di, di             ; DI = 0: i * 2, the index into sx/sy
        mov  cx, NV             ; CX = 8 corners
.v:     push cx                 ; keep the count
        mov  al, [si]           ; AL = VERTS[i*3]
        mov  [vx3], al          ; vx3 = x
        mov  al, [si+1]         ; AL = VERTS[i*3+1]
        mov  [vy3], al          ; vy3 = y
        mov  al, [si+2]         ; AL = VERTS[i*3+2]
        mov  [vz3], al          ; vz3 = z
        push si                 ; keep SI and DI across the turns
        push di                 ; (the pair)
        call TurnY              ; turn_y()
        call TurnX              ; turn_x()
        pop  di                 ; DI back
        pop  si                 ; SI back

        mov  al, [vz3]          ; AL = vz3    the DEPTH: this corner's distance
        cbw                     ; AX = vz3    from the eye along its axis. The
        add  ax, [tz]           ; AX = z = vz3 + tz   cube's centre is tz out;
        mov  [depb], al         ; depb = z    the corner a little nearer or
        shr  ax, 1              ; AX = z / 2  further. As a BYTE: the table has
        mov  [deph], al         ; deph = z/2  a row per depth, 0..255 - and the
                                ;  divide gets HALF of it, so that a signed
                                ;  byte can still hold it
        mov  al, [pmode]        ; AL = pmode
        cmp  al, 1              ; pmode == 1 ?
        je   .div               ;   the divide
        cmp  al, 2              ; pmode == 2 ?
        je   .tab               ;   the table
        cmp  al, 3              ; pmode == 3 ?
        je   .both              ;   both
        mov  al, [vx3]          ; AL = vx3    ---- flat: the deleted coordinate
        cbw                     ; AX = vx3
        mov  [px], ax           ; px = vx3
        mov  al, [vy3]          ; AL = vy3
        cbw                     ; AX = vy3
        mov  [py], ax           ; py = vy3
        jmp  .land              ; to the landing
.div:   push si                 ; keep SI, DI
        push di                 ; (the pair)
        call ProjDiv            ; proj_div()
        pop  di                 ; DI back
        pop  si                 ; SI back
        jmp  .land              ; to the landing
.both:  push si                 ; keep SI, DI
        push di                 ; (the pair)
        call ProjDiv            ; proj_div(): the divided answer, parked aside...
        pop  di                 ; DI back
        pop  si                 ; SI back
        mov  ax, [px]           ; AX = px
        add  ax, CX0            ; AX = CX0 + px
        mov  [sxd+di], ax       ; sxd[i] = AX
        mov  ax, CY0            ; AX = CY0
        sub  ax, [py]           ; AX = CY0 - py
        mov  [syd+di], ax       ; syd[i] = AX
.tab:   push si                 ; keep SI, DI
        push di                 ; (the pair)
        call ProjTab            ; proj_tab(): ...and the table's, which is drawn
        pop  di                 ; DI back
        pop  si                 ; SI back
.land:  mov  ax, [px]           ; AX = px
        add  ax, CX0            ; AX = CX0 + px
        mov  [sx+di], ax        ; sx[i] = AX
        mov  ax, CY0            ; AX = CY0
        sub  ax, [py]           ; AX = CY0 - py: THE MINUS, paper y up, beam down
        mov  [sy+di], ax        ; sy[i] = AX
        add  si, 3              ; SI += 3: the next corner's bytes
        add  di, 2              ; DI += 2: the next corner's word
        pop  cx                 ; the count
        dec  cx                 ; CX--    LOOP reaches one signed byte backwards
        jz   .done              ; done?    and this body is longer than that. So:
        jmp  .v                 ;   no: next corner   count by hand, let a JMP reach
.done:  ret                     ; return   (the assembler refusing was the good case)

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
;  In C there is no such function: the CPU calls it, and it never returns.
;
;      void trap(void)   { set_mode(3);  puts(t_trap);  exit(1); }
Trap:   mov  ax, cs             ; AX = our segment: the interrupt brings whatever
        mov  ds, ax             ; DS = AX   DS it finds; ours is CS, the string is in it
        mov  ax, 0003h          ; AX = 3: a text screen, so the words can be read
        int  10h                ; set_mode(3)
        mov  dx, t_trap         ; DX = the string
        mov  ah, 9              ; AH = 9: DOS print string, up to the $
        int  21h                ; puts(t_trap)
        mov  ax, 4C01h          ; AH = 4Ch exit, AL = 1: a non-zero exit code
        int  21h                ; exit(1)

t_trap  db 'INT 0: the quotient did not fit in a byte.',13,10
        db 'A corner came closer than the near plane, and x*d/z outran AL.',13,10
        db 'The near plane was the promise never to ask the divide this.',13,10,'$'

; ---- the eye's axis, where it meets the glass: a small yellow cross ------
;  In C:   line(CX0-5, CY0, CX0+5, CY0);  line(CX0, CY0-5, CX0, CY0+5);  in yellow
Axis:   mov  word [p0x], CX0-5  ; p0x = 155  \
        mov  word [p1x], CX0+5  ; p1x = 165   > the horizontal stroke
        mov  word [p0y], CY0    ; p0y = 100   >
        mov  word [p1y], CY0    ; p1y = 100  /
        mov  byte [col], ORGC   ; col = yellow
        call Line               ; line()
        mov  word [p0x], CX0    ; p0x = 160  \
        mov  word [p1x], CX0    ; p1x = 160   > the vertical stroke
        mov  word [p0y], CY0-5  ; p0y = 95    >
        mov  word [p1y], CY0+5  ; p1y = 105  /
        mov  byte [col], ORGC   ; col = yellow
        call Line               ; line()
        ret                     ; return

; ---- the edges, from whichever corner table [esrc] points at -------------
;  Lesson 0E's routine, with one change: it reads the corners through a
;  pointer, so stage 4 can draw the divided cube and the table's cube with
;  the same twelve lines.
;  In C:
;
;      void edges(void)                   /* esrc points at sx or at sxd */
;      {
;          int *X = esrc, *Y = esrc + 8;  /* the y table is 16 bytes on   */
;          for (int e = 0; e < NE; e++) {
;              int a = EDGES[e*2], b = EDGES[e*2+1];
;              p0x = X[a];  p0y = Y[a];
;              p1x = X[b];  p1y = Y[b];
;              col = ecol;
;              line();
;          }
;      }
Edges:  mov  si, EDGES          ; SI = &EDGES[0]
        mov  cx, NE             ; CX = 12 joins
.e:     push cx                 ; keep the count
        mov  bx, [esrc]         ; BX = X, whichever table esrc points at
        mov  al, [si]           ; AL = a, the first corner's number
        xor  ah, ah             ; AX = a
        add  ax, ax             ; AX = a * 2: words
        add  bx, ax             ; BX = &X[a]
        mov  ax, [bx]           ; AX = X[a]
        mov  [p0x], ax          ; p0x = X[a]
        mov  ax, [bx+16]        ; AX = Y[a]: the y table sits sixteen bytes after x
        mov  [p0y], ax          ; p0y = Y[a]
        mov  bx, [esrc]         ; BX = X again
        mov  al, [si+1]         ; AL = b, the second corner's number
        xor  ah, ah             ; AX = b
        add  ax, ax             ; AX = b * 2
        add  bx, ax             ; BX = &X[b]
        mov  ax, [bx]           ; AX = X[b]
        mov  [p1x], ax          ; p1x = X[b]
        mov  ax, [bx+16]        ; AX = Y[b]
        mov  [p1y], ax          ; p1y = Y[b]
        mov  al, [ecol]         ; AL = ecol
        mov  [col], al          ; col = ecol
        push si                 ; keep SI: the rule is to keep what the loop needs
        call Line               ; line()
        pop  si                 ; SI back
        add  si, 2              ; SI += 2: the next pair
        pop  cx                 ; the count
        loop .e                 ; 12 times
        ret                     ; return

; ---- Differ: a red dot on every corner the two methods disagree about ----
;  "Disagree" means further apart than ONE pixel. A table in 256ths and a
;  divide that truncates will not land on the same pixel every time, and
;  painting those red would only teach that rounding exists. Two pixels
;  apart would be a wrong table. Count the red dots: there are none.
;  In C:
;
;      void differ(void)
;      {
;          for (int i = 0; i < NV; i++) {
;              int dx = sx[i] - sxd[i], dy = sy[i] - syd[i];
;              if (dx > 1 || dx < -1 || dy > 1 || dy < -1) {
;                  dcol = DIFFC;  dot(sx[i], sy[i]);
;              }
;          }
;      }
Differ: xor  di, di             ; DI = 0  (i * 2)
        mov  cx, NV             ; CX = 8 corners
.d:     push cx                 ; keep the count
        mov  ax, [sx+di]        ; AX = sx[i]
        sub  ax, [sxd+di]       ; AX = dx = sx[i] - sxd[i]
        cmp  ax, 1              ; dx > 1 ?
        jg   .red               ;   yes: a real disagreement
        cmp  ax, -1             ; dx < -1 ?
        jl   .red               ;   yes
        mov  ax, [sy+di]        ; AX = sy[i]
        sub  ax, [syd+di]       ; AX = dy = sy[i] - syd[i]
        cmp  ax, 1              ; dy > 1 ?
        jg   .red               ;   yes
        cmp  ax, -1             ; dy >= -1 ?
        jge  .ok                ;   yes: within a pixel, no dot
.red:   mov  byte [dcol], DIFFC ; dcol = red
        mov  ax, [sx+di]        ; AX = sx[i]   \  dot(sx[i], sy[i])
        mov  bx, [sy+di]        ; BX = sy[i]   /
        push di                 ; keep i: Dot uses DI
        call Dot                ; dot()
        pop  di                 ; i back
.ok:    add  di, 2              ; i++
        pop  cx                 ; the count
        loop .d                 ; 8 times
        ret                     ; return

; ---- one whole picture ---------------------------------------------------
;  In C:
;
;      void frame(void)
;      {
;          vsync();  gclear();  xform();  axis();
;          if (pmode == 3) { esrc = sxd; ecol = DIVC;  edges(); }   /* grey under  */
;          esrc = sx;  ecol = EDGEC;  edges();                      /* white over  */
;          if (pmode == 3) differ();                                /* red where not */
;      }
Frame:  call Vsync              ; vsync()
        call GClear             ; gclear()
        call Xform              ; xform()
        call Axis               ; axis()
        cmp  byte [pmode], 3    ; pmode == 3 ?
        jne  .one               ;   no: one cube only
        mov  word [esrc], sxd   ; esrc = sxd: stage 4, the divided cube underneath...
        mov  byte [ecol], DIVC  ; ecol = grey
        call Edges              ; edges()
.one:   mov  word [esrc], sx    ; esrc = sx: ...and the drawn one on top
        mov  byte [ecol], EDGEC ; ecol = white
        call Edges              ; edges()
        cmp  byte [pmode], 3    ; pmode == 3 ?
        jne  .out               ;   no: done
        call Differ             ; differ(): the red dots, if there are any
.out:   ret                     ; return

; ---- Spin: turn until a key --------------------------------------------
;  In C:   do { frame(); angy += stepy; angx += stepx; } while (!key_check());
Spin:   call Frame              ; frame()
        mov  al, [stepy]        ; AL = stepy
        add  [angy], al         ; angy += stepy
        mov  al, [stepx]        ; AL = stepx
        add  [angx], al         ; angx += stepx
        call KeyChk             ; AL = key_check()
        or   al, al             ; a key ?
        jz   Spin               ;   no: another frame
        ret                     ; return

; ---- Walk: slide along Z until a key ------------------------------------
;  Every [hold] frames, tz moves by [wdz]. At TZFAR it turns back. At TZMIN
;  it does what [guard] says: 1 bounce, 2 stop dead, 0 KEEP GOING - and
;  keeping going is stage 6, which does not come back.
;  In C:
;
;      void walk(void)
;      {
;          do {
;              frame();
;              if (--hcnt == 0) {                  /* every hold frames   */
;                  hcnt = hold;
;                  tz += wdz;
;                  if (tz >= TZFAR) wdz = -wdz;    /* the far end: turn   */
;                  if (tz < TZMIN && guard) {      /* the near plane...   */
;                      tz = TZMIN;                 /* ...this far, no more */
;                      if (guard == 2) wdz = 0;    /* 2: stop dead        */
;                      else            wdz = -wdz; /* 1: bounce           */
;                  }                               /* 0: on to the trap   */
;              }
;          } while (!key_check());
;      }
Walk:   call Frame              ; frame()
        dec  byte [hcnt]        ; hcnt--
        jnz  .k                 ; not yet a step: to the key
        mov  al, [hold]         ; AL = hold
        mov  [hcnt], al         ; hcnt = hold
        mov  al, [wdz]          ; AL = wdz
        cbw                     ; AX = wdz
        add  [tz], ax           ; tz += wdz
        cmp  word [tz], TZFAR   ; tz >= TZFAR ?
        jl   .n1                ;   no
        neg  byte [wdz]         ;   yes: wdz = -wdz, the far end: turn
.n1:    cmp  word [tz], TZMIN   ; tz < TZMIN ?
        jge  .k                 ;   no: to the key
        cmp  byte [guard], 0    ; guard == 0 ?
        je   .k                 ;   yes: no guard, on towards the trap
        mov  word [tz], TZMIN   ; tz = TZMIN: the NEAR PLANE, this far and no further
        cmp  byte [guard], 2    ; guard == 2 ?
        je   .stop              ;   yes: stop dead
        neg  byte [wdz]         ;   no:  wdz = -wdz, bounce
        jmp  .k                 ; to the key
.stop:  mov  byte [wdz], 0      ; wdz = 0
.k:     call KeyChk             ; AL = key_check()
        or   al, al             ; a key ?
        jz   Walk               ;   no: another frame
        ret                     ; return

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
;  In C:
;
;      int main(void)
;      {
;          int_vector[0] = trap;                      /* DOS fn 25h       */
;          set_mode(0x13);
;          pmode = 0; tz = TZHOME; frame(); key();                 /* 1 */
;          pmode = 1;              frame(); key();                 /* 2 */
;          tz = TZFAR; wdz = -1; hold = 2; guard = 1; walk();      /* 3 */
;          pmode = 3; tz = TZHOME; stepy = 1; stepx = 0; spin();   /* 4 */
;          pmode = 2; stepy = 0; tz = TZFAR; wdz = -1; hold = 2;
;          guard = 2; walk();                                      /* 5 */
;          if (lastk == ESC) { set_mode(3); exit(0); }
;          pmode = 1; tz = TZFAR; wdz = -1; hold = 3; guard = 0;
;          walk();                          /* 6: never comes back */
;      }
Boot:   cld                     ; string ops count UP (STOSW in GClear)
        mov  ax, 2500h          ; AH = 25h set interrupt vector, AL = 0: the
        mov  dx, Trap           ; DX = Trap     divide fault. INT 21h fn 25h
        int  21h                ; int_vector[0] = DS:DX.  In a COM DS is CS,
                                ;  so DX alone names it. From here on an
                                ;  overflowing IDIV lands in our handler, not
                                ;  in DOS's, which would loop on the fault
        mov  ax, 0013h          ; AX = 13h: 320x200, 256 colours
        int  10h                ; set_mode(0x13)
        mov  ax, VGA            ; AX = A000h
        mov  es, ax             ; ES = the screen, for the whole program

; ---- 1. flat: lesson 0E's cube, z thrown away ----------------------------
        mov  byte [pmode], 0    ; pmode = 0: flat
        mov  word [tz], TZHOME  ; tz = TZHOME
        call Frame              ; frame()
        call Key                ; key()

; ---- 2. the divide: the same cube, and the far face is smaller -----------
        mov  byte [pmode], 1    ; pmode = 1: the divide
        call Frame              ; frame()
        call Key                ; key()

; ---- 3. it grows: the cube comes towards you, and back ------------------
        mov  word [tz], TZFAR   ; tz = TZFAR: start far away
        mov  byte [wdz], -1     ; wdz = -1: coming closer
        mov  byte [hold], 2     ; hold = 2 frames a step
        mov  byte [guard], 1    ; guard = 1: bounce off the near plane
        call Walk               ; walk()

; ---- 4. the table, drawn on the divide - count the red dots --------------
        mov  byte [pmode], 3    ; pmode = 3: both
        mov  word [tz], TZHOME  ; tz = TZHOME
        mov  byte [stepy], 1    ; stepy = 1: turning about Y
        mov  byte [stepx], 0    ; stepx = 0
        call Spin               ; spin()

; ---- 5. the near plane: it comes, and it STOPS ---------------------------
        mov  byte [pmode], 2    ; pmode = 2: the table
        mov  byte [stepy], 0    ; stepy = 0: still
        mov  word [tz], TZFAR   ; tz = TZFAR
        mov  byte [wdz], -1     ; wdz = -1
        mov  byte [hold], 2     ; hold = 2
        mov  byte [guard], 2    ; guard = 2: stop dead at the plane
        call Walk               ; walk()
        mov  al, [lastk]        ; AL = lastk, the key that ended it
        cmp  al, 27             ; lastk == ESC ?  ESC here leaves cleanly.
        je   Bye                ;   yes: Bye.     Anything else...

; ---- 6. no guard: the divide, unprotected. This stage does not return. ---
;      The cube is at the near plane. Take the plane away and keep coming.
;      Within a few steps a corner's x*D/z will not fit in AL, IDIV raises
;      INT 0, and Trap ends the program with three lines of text. That is
;      not this program failing. That is the machine telling you what the
;      near plane was for, in the only voice it has.
        mov  byte [pmode], 1    ; pmode = 1: the divide
        mov  word [tz], TZFAR   ; tz = TZFAR: from the far end, all the way in -
        mov  byte [wdz], -1     ; wdz = -1     about five seconds of approach
        mov  byte [hold], 3     ; hold = 3     before the quotient outruns the
        mov  byte [guard], 0    ; guard = 0    byte. From the plane it took one
        call Walk               ; walk()       second, and a crash nobody saw
                                ;  coming teaches nothing. ...and it never
                                ;  gets back here

Bye:    mov  ax, 0003h          ; AX = 3: a clean screen back to DOS - reached
        int  10h                ; set_mode(3)   only by ESC at stage 5
        mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)
