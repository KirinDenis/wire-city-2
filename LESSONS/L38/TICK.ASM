; ============================================================================
;  TICK.ASM - Lesson 26, step one. THE TIMER CHIP, ON ITS OWN: five seconds of
;  the machine's clock and of ours, side by side, and nothing else.
;
;      FASM TICK.ASM TICK.COM
;
;  THE PHYSICAL FACT THIS LESSON HANDS OVER:
;
;      THE TIME IS A CRYSTAL AND A DIVIDER. On the board is a quartz crystal,
;      and from it the timer chip gets 1193182 pulses a second. All the chip
;      does is count them down from a number and pull a wire when it reaches
;      nothing: that wire is IRQ 0, and the processor runs INT 8. The BIOS
;      loads the largest number there is, 65536, and 1193182 / 65536 is
;      18.2 - the tick of every PC. Write 16384 into the chip and the same
;      crystal ticks 72.8 times a second.
;
;  WHAT IT PRINTS: the BIOS's tick count and ours, until ours reaches 364:
;  five seconds. Every fourth of our ticks is handed on to the BIOS, so the
;  BIOS counts 91, and its clock keeps the right time.
;
;  Everything from TIMERON to T8 goes into the flight as it stands.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
        format binary as 'COM'
        org  100h

PITDIV  = 16384                 ; THE CLOCK: 1193182 / 16384 = 72.8 ticks a second
TICKS   = 364                   ; 5 seconds of them: 72.8 * 5

; ---- the program ------------------------------------------------------------
;  In C:
;      puts(title);
;      timeron();
;      bios0 = *(unsigned far *)0x0040006C;
;      do {
;          seen = clk;
;          print(bios_now - bios0, seen);
;      } while (seen < TICKS);
;      timeroff();
START:
        mov  dx,Title           ; DX = the title
        mov  ah,9               ; DOS: print up to the $
        int  21h
        call TIMERON            ; the chip at 72.8, INT 8 ours
        mov  ax,40h             ; AX = the BIOS's data segment
        mov  es,ax              ; ES = it
        mov  ax,[es:6Ch]        ; AX = the BIOS's tick count now
        mov  [bios0],ax         ; bios0 = AX
.loop:  mov  ax,[clk]           ; AX = our count, first: it is the one we stop on
        mov  [seen],ax          ; seen = AX
        mov  dx,LBios           ; DX = "BIOS ticks "
        mov  ah,9
        int  21h
        mov  ax,[es:6Ch]        ; AX = the BIOS's count
        sub  ax,[bios0]         ; AX -= where it started
        call PRDEC              ; print it
        mov  dx,LOurs           ; DX = "   our ticks "
        mov  ah,9
        int  21h
        mov  ax,[seen]          ; AX = our count
        call PRDEC              ; print it
        cmp  word [seen],TICKS  ; five seconds?
        jb   .loop              ;   not yet
        call TIMEROFF           ; the chip and the vector back
        mov  dx,Done            ; DX = the last line
        mov  ah,9
        int  21h
        mov  ax,4C00h           ; back to DOS
        int  21h

; ---- PRDEC: AX in decimal, five places, leading blanks ----------------------
;  In C:  for (n = 0; n < 5; n++) { digit[n] = ax % 10; ax /= 10; }
PRDEC:  mov  bx,10              ; BX = the divisor
        mov  cx,5               ; CX = five places
.d:     xor  dx,dx              ; DX:AX = the number
        div  bx                 ; AX = number / 10, DX = the last digit
        push dx                 ; keep the digit: they come out backwards
        loop .d
        mov  cx,5               ; CX = five places again
.p:     pop  dx                 ; DX = the next digit, the first one first
        add  dl,'0'             ; DL += '0': a digit into a letter
        mov  ah,2               ; DOS: print DL
        int  21h
        loop .p
        ret

; ============================================================================
;  THE GAME'S OWN CLOCK. The timer chip's channel 0 is two ports: 43h says
;  what is about to happen, 40h takes the number, low byte, then high.
;  36h = 00 11 011 0: channel 0, low then high, mode 3 (a square wave), binary.
;  In C:
;      oldi8 = int_vector[8];  int_vector[8] = T8;
;      outp(0x43, 0x36);  outp(0x40, PITDIV & 255);  outp(0x40, PITDIV >> 8);
; ============================================================================
TIMERON:
        xor  ax,ax              ; AX = 0
        mov  es,ax              ; ES = 0: the vector table
        mov  ax,[es:8*4]        ; AX = vector 8's offset
        mov  [oldi8],ax         ; oldi8.offset = AX
        mov  ax,[es:8*4+2]      ; AX = its segment
        mov  [oldi8+2],ax       ; oldi8.segment = AX
        cli                     ; interrupts off: no tick between the words
        mov  word [es:8*4],T8   ; vector[8].offset  = T8
        mov  [es:8*4+2],cs      ; vector[8].segment = cs
        mov  al,36h             ; AL = channel 0, low then high, square wave
        out  43h,al             ; the chip's command port
        mov  ax,PITDIV          ; AX = the number to count down from
        out  40h,al             ; its low byte
        mov  al,ah              ; AL = its high byte
        out  40h,al             ; and from the next count on, 72.8 a second
        sti                     ; interrupts on
        ret

; ---- TIMEROFF: the number and the vector, both back as we found them ---------
;  0 means 65536 to the chip: sixteen bits cannot say it any other way.
TIMEROFF:
        xor  ax,ax              ; AX = 0
        mov  es,ax              ; ES = 0: the vector table
        cli                     ; interrupts off
        mov  al,36h             ; AL = the same command
        out  43h,al
        xor  al,al              ; AL = 0
        out  40h,al             ; low byte
        out  40h,al             ; high byte: 18.2 a second again
        mov  ax,[oldi8]         ; AX = oldi8.offset
        mov  [es:8*4],ax        ; vector[8].offset = AX
        mov  ax,[oldi8+2]       ; AX = oldi8.segment
        mov  [es:8*4+2],ax      ; vector[8].segment = AX
        sti                     ; interrupts on
        ret

; ---- T8: the wire. 72.8 times a second, whatever the program is doing --------
;  An interrupt arrives with DS anything, so every name here says CS:. Three
;  ticks of four tell the interrupt controller "done" with 20h on port 20h;
;  the fourth goes on to the BIOS's routine, which says it for us.
;  In C:
;      clk++;
;      if (clk & 3) outp(0x20, 0x20);
;      else oldi8();
T8:     push ax                 ; AX is the program's: keep it
        inc  word [cs:clk]      ; clk++
        test byte [cs:clk],3    ; its low two bits nought: every fourth
        jz   .bios              ;   the BIOS's turn
        mov  al,20h             ; AL = end of interrupt
        out  20h,al             ; to the interrupt controller
        pop  ax                 ; AX back
        iret                    ; back to whatever was running
.bios:  pop  ax                 ; AX back
        jmp  dword [cs:oldi8]   ; the BIOS's INT 8: it does its own IRET

clk     dw 0                    ; THE GAME'S CLOCK: 72.8 ticks a second
oldi8   dw 0,0                  ; INT 8 as we found it: offset, segment
bios0   dw 0                    ; the BIOS's count when we started
seen    dw 0                    ; our count, as printed

Title   db 'ONE CRYSTAL, TWO DIVIDERS',13,10,'$'
LBios   db 13,'BIOS ticks $'
LOurs   db '   our ticks $'
Done    db 13,10,'One tick of the BIOS is four of ours.',13,10,'$'
