; ============================================================================
;  RESDAT.ASM - the game resource file CITY.DAT, as plain assembler source.
;  Build (see BUILD.BAT):  TASM RESDAT ; TLINK /t RESDAT  -> RESDAT.COM,
;  which is a raw byte image (no header) and is copied to CITY.DAT.
;
;  Format:  'W','C', version, resource count, then directory entries of
;           (id: byte, offset: word, length: word), offsets file-relative.
;  TASM computes every offset/length from the labels - edit freely.
;
;  Resources:  id 1 = 4x6 bitmap font, 41 glyphs x 6 rows, high 3 bits.
;              Glyph order: 0-9, A-Z, + - : % .
;              id 2 = photo cockpit, 320x200 palette indexes (31..93),
;              255 = transparent. Generated from res\panel1.bmp by
;              res\mkpanel.py (also emits PALPNL.INC for DATA.INC).
; ============================================================================
        .8086
CODE    SEGMENT
        ASSUME  CS:CODE
        ORG 100h
RESBASE:
        db 'W','C'              ; magic
        db 1                    ; format version
        db 2                    ; resource count
        ; ---- directory ----
        db 1                    ; resource id 1: the 4x6 font
        dw FONT-RESBASE         ; offset  (TASM does the math)
        dw FONTEND-FONT         ; length
        db 2                    ; resource id 2: the photo cockpit bitmap
        dw PIMG-RESBASE
        dw PIMGEND-PIMG

; ---- resource 1: the font. One line per glyph, six rows each; the ----
; ---- binary literals ARE the pixel art (read the 1s).             ----
FONT:
        db 11100000b,10100000b,10100000b,10100000b,11100000b,00000000b ; 0
        db 01000000b,11000000b,01000000b,01000000b,11100000b,00000000b ; 1
        db 11100000b,00100000b,11100000b,10000000b,11100000b,00000000b ; 2
        db 11100000b,00100000b,11100000b,00100000b,11100000b,00000000b ; 3
        db 10100000b,10100000b,11100000b,00100000b,00100000b,00000000b ; 4
        db 11100000b,10000000b,11100000b,00100000b,11100000b,00000000b ; 5
        db 11100000b,10000000b,11100000b,10100000b,11100000b,00000000b ; 6
        db 11100000b,00100000b,01000000b,01000000b,01000000b,00000000b ; 7
        db 11100000b,10100000b,11100000b,10100000b,11100000b,00000000b ; 8
        db 11100000b,10100000b,11100000b,00100000b,11100000b,00000000b ; 9
        db 01000000b,10100000b,11100000b,10100000b,10100000b,00000000b ; A
        db 11000000b,10100000b,11000000b,10100000b,11000000b,00000000b ; B
        db 01100000b,10000000b,10000000b,10000000b,01100000b,00000000b ; C
        db 11000000b,10100000b,10100000b,10100000b,11000000b,00000000b ; D
        db 11100000b,10000000b,11000000b,10000000b,11100000b,00000000b ; E
        db 11100000b,10000000b,11000000b,10000000b,10000000b,00000000b ; F
        db 01100000b,10000000b,10100000b,10100000b,01100000b,00000000b ; G
        db 10100000b,10100000b,11100000b,10100000b,10100000b,00000000b ; H
        db 11100000b,01000000b,01000000b,01000000b,11100000b,00000000b ; I
        db 00100000b,00100000b,00100000b,10100000b,01000000b,00000000b ; J
        db 10100000b,11000000b,10000000b,11000000b,10100000b,00000000b ; K
        db 10000000b,10000000b,10000000b,10000000b,11100000b,00000000b ; L
        db 10100000b,11100000b,10100000b,10100000b,10100000b,00000000b ; M
        db 11100000b,10100000b,10100000b,10100000b,10100000b,00000000b ; N
        db 11100000b,10100000b,10100000b,10100000b,11100000b,00000000b ; O
        db 11100000b,10100000b,11100000b,10000000b,10000000b,00000000b ; P
        db 11100000b,10100000b,10100000b,11100000b,00100000b,00000000b ; Q
        db 11000000b,10100000b,11000000b,10100000b,10100000b,00000000b ; R
        db 11100000b,10000000b,11100000b,00100000b,11100000b,00000000b ; S
        db 11100000b,01000000b,01000000b,01000000b,01000000b,00000000b ; T
        db 10100000b,10100000b,10100000b,10100000b,11100000b,00000000b ; U
        db 10100000b,10100000b,10100000b,10100000b,01000000b,00000000b ; V
        db 10100000b,10100000b,10100000b,11100000b,10100000b,00000000b ; W
        db 10100000b,10100000b,01000000b,10100000b,10100000b,00000000b ; X
        db 10100000b,10100000b,01000000b,01000000b,01000000b,00000000b ; Y
        db 11100000b,00100000b,01000000b,10000000b,11100000b,00000000b ; Z
        db 00000000b,01000000b,11100000b,01000000b,00000000b,00000000b ; plus
        db 00000000b,00000000b,11100000b,00000000b,00000000b,00000000b ; minus
        db 00000000b,01000000b,00000000b,01000000b,00000000b,00000000b ; colon
        db 10100000b,00100000b,01000000b,10000000b,10100000b,00000000b ; percent
        db 00000000b,00000000b,00000000b,00000000b,01000000b,00000000b ; dot
FONTEND:

; ---- resource 2: the cockpit bitmap (generated - do not edit by hand) ----
PIMG:
        include PANELIMG.INC
PIMGEND:

CODE    ENDS
        END RESBASE
