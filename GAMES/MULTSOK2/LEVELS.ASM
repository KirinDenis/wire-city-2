; ==================================================================
;  LEVELS.ASM - MULTIPLAY SOKO II's 60 levels as a file of their own:
;      FASM LEVELS.ASM LEVELS.DAT    (MAKE does it, before the game)
;  They had been 17 KB of the .COM's 64; the room went to the EGA 640
;  picture.  MULTSOK2.COM reads the table at start and one level at each
;  level change, from the folder it was started from.
;    +0  'SOKOLEV2'
;    +8  dw  where LEVTAB is in the file
;    +10 dw  NLEVELS
;    then LEVELS.INC (TOOLS\LevConv's): every level, db width, height,
;    the rows; and LEVTAB, a word per level, where it begins.
;  Every offset counts from the file's first byte (FASM's binary format
;  starts at 0).
; ==================================================================
format binary as 'DAT'
        db 'SOKOLEV2'
        dw LEVTAB, NLEVELS
        include 'LEVELS.INC'
