; MENU.ASM - the catalogue. What autoexec runs instead of leaving a bare
; prompt.
;
;   FASM MENU.ASM MENU.COM
;
; It reads the .INF manifest beside every lesson, example and game - the
; same file the web page and the bundler read - and lists the three tiers
; plus WORK, the student's own directory. Choosing an entry offers three
; things: open it, build it, run it. EVERY choice prints the command it is
; about to run, then runs it - the menu is training wheels that show you
; the pedals, and a student who types MAKE instead of arrowing to it is a
; success, not a bypass.
;
; ESC never traps anybody: from the top screen it leaves a plain prompt
; with a one-line reminder of how to get back.
;
; 8086 only, like everything on the disk: E_8086.INC turns the conditional
; jumps into reach-checked macros, because FASM will otherwise emit a 386
; long jump (0F 8x) without a word said.

format binary as 'com'
        org  100h

include '..\..\ENGINE\E_8086.INC'

TEXTSEG = 0B800h                ; the text screen - 80x25, two bytes a cell
MAXENT  = 48                    ; more entries than the disk has manifests
MAXWORK = 18                    ; one screen of the student's own files
TITLESZ = 56
WHATSZ  = 78
MAINSZ  = 13
DIRSZ   = 28
INFSZ   = 3072                  ; the longest manifest is around one KB

start:
        cld
        mov     sp, stacktop    ; our own small stack, then give the rest
        mov     bx, progpara    ; of the segment back to DOS - EXEC cannot
        mov     ah, 4Ah         ; load a child into memory we still own
        int     21h

        call    find_comspec    ; where COMMAND.COM is - children run
                                ; through it, so PATH does the finding
        mov     ax, cs          ; the far pointers in the EXEC parameter
        mov     [epb_tseg], ax  ; block need real segment values
        mov     [epb_f1seg], ax
        mov     [epb_f2seg], ax

        call    scan_all        ; walk the manifests once; WORK is
                                ; rescanned every time its screen opens,
                                ; because N and MAKE change it

; ---------------------------------------------------------------------------
; The top screen: four sections. The three tiers ARE the curriculum, and
; the fourth is the student's own bench.
; ---------------------------------------------------------------------------

top_screen:
        call    screen_init
        mov     si, t_title
        mov     di, 0*160+2
        mov     ah, 70h
        call    puts
        mov     si, t_hint_top
        mov     di, 23*160+2
        mov     ah, 17h         ; hints: quiet gray on the blue desktop
        call    puts

        xor     bx, bx          ; BX = selected section
.draw:
        call    draw_sections
.key:
        call    getkey
        cmp     ah, 48h         ; up
        jne     .notup
        or      bx, bx
        jz      .key
        dec     bx
        jmp     .draw
.notup: cmp     ah, 50h         ; down
        jne     .notdn
        cmp     bx, 3
        jae     .key
        inc     bx
        jmp     .draw
.notdn: cmp     al, 13
        je      .enter
        cmp     al, 27
        jne     .key

        ; ESC - leave a usable prompt, never a trap
        mov     ax, 3
        int     10h
        mov     dx, t_bye
        mov     ah, 9
        int     21h
        mov     ax, 4C00h
        int     21h

.enter: cmp     bx, 3
        je      .work
        push    bx
        call    section_screen
        pop     bx
        jmp     top_screen
.work:  push    bx
        call    work_screen
        pop     bx
        jmp     top_screen

; draw the four section lines, BX selected
draw_sections:
        push    bx
        xor     cx, cx          ; CX = section being drawn
.line:  mov     al, cl          ; row = 5 + section*2
        add     al, al
        add     al, 5
        cbw
        call    rowofs          ; DI = row*160
        add     di, 6
        mov     ah, 1Eh         ; yellow on blue - second rank
        cmp     cx, bx
        jne     .attr
        mov     ah, 2Fh         ; the focused line: white on green, the
.attr:  mov     [numattr], ah   ; one place Turbo Vision spent its green
        push    cx
        push    bx
        mov     bx, cx
        shl     bx, 1
        mov     si, [secnames+bx]
        call    puts_pad16      ; name, padded so the columns are even
        mov     si, [secdescs+bx]
        call    puts
        mov     al, '('
        call    putc
        shr     bx, 1
        cmp     bx, 3
        jne     .cnt
        call    count_work      ; WORK is counted live
        mov     al, [workcnt]
        jmp     .num
.cnt:   mov     al, [seccnt+bx]
.num:   call    putnum
        mov     al, ')'
        call    putc
        pop     bx
        pop     cx
        inc     cx
        cmp     cx, 4
        jb      .line
        pop     bx
        ret

; ---------------------------------------------------------------------------
; A section screen: the entries of one tier. O or ENTER opens the main
; file in FASMD, B runs MAKE, R runs RUN - and the entry's .what line sits
; above the verbs so the list explains itself.
; BX = section 0..2 on entry.
; ---------------------------------------------------------------------------

section_screen:
        mov     ax, bx
        mov     [cursec], ax
.again:
        call    screen_init
        mov     bx, [cursec]
        shl     bx, 1
        mov     si, [secnames+bx]
        mov     di, 0*160+2
        mov     ah, 70h
        call    puts
        mov     si, [secdescs+bx]
        mov     ah, 70h
        call    puts

        xor     bx, bx          ; BX = selected entry inside the section
.draw:
        call    draw_entries
        call    draw_what
.key:
        call    getkey
        cmp     ah, 48h
        jne     .nu
        or      bx, bx
        jz      .key
        dec     bx
        jmp     .draw
.nu:    cmp     ah, 50h
        jne     .nd
        mov     cx, [curcnt]
        dec     cx
        cmp     bx, cx
        jae     .key
        inc     bx
        jmp     .draw
.nd:    cmp     al, 27
        jne     .ne
        ret
.ne:    call    upcase
        cmp     al, 13
        je      .open
        cmp     al, 'O'
        je      .open
        cmp     al, 'B'
        je      .build
        cmp     al, 'R'
        je      .run
        jmp     .key

.open:  call    sel_entptrs
        mov     si, vb_fasmd    ; "FASMD " + the entry's main file
        mov     di, vbuf
        call    strcpy
        mov     si, [pmain]
        call    strcpy
        call    exec_entry
        jmp     .again
.build: call    sel_entptrs
        mov     si, [pflag]
        test    byte [si], 1
        jz      .ro
        mov     si, vb_make
        mov     di, vbuf
        call    strcpy
        call    exec_entry
        jmp     .again
.run:   call    sel_entptrs
        mov     si, [pflag]
        test    byte [si], 2
        jz      .ro
        mov     si, vb_run
        mov     di, vbuf
        call    strcpy
        call    exec_entry
        jmp     .again
.ro:    ; nothing to build or run - the entry is for reading
        mov     si, t_readonly
        mov     di, 22*160+4
        mov     ah, 1Ch         ; light red on blue - a warning, not an error
        call    puts
        jmp     .key

; entry pointers for section [cursec], selection BX
sel_entptrs:
        push    bx
        mov     ax, [cursec]
        shl     ax, 1
        mov     si, ax
        mov     ax, [secstart+si]
        add     ax, bx
        call    entptrs
        pop     bx
        ret

; list the section's entries, selection BX inverse
draw_entries:
        push    bx
        mov     ax, [cursec]
        shl     ax, 1
        mov     si, ax
        mov     cx, [seccnt2+si] ; word copy of count
        mov     [curcnt], cx
        mov     dx, [secstart+si]
        xor     cx, cx          ; CX = line
.e:     push    cx
        push    dx
        push    bx
        mov     al, cl
        add     al, 3
        cbw
        call    rowofs
        add     di, 4
        mov     ah, 1Eh
        cmp     cx, bx
        jne     .a
        mov     ah, 2Fh
.a:     mov     [ax_save], ax
        mov     ax, dx
        add     ax, cx
        push    di
        call    entptrs
        pop     di
        mov     ax, [ax_save]
        mov     si, [ptitle]
        call    puts_pad60
        pop     bx
        pop     dx
        pop     cx
        inc     cx
        cmp     cx, [curcnt]
        jb      .e
        pop     bx
        ret

; the .what line of the selection, above the verb bar
draw_what:
        push    bx
        ; wipe the two rows first
        mov     al, 21
        cbw
        call    rowofs
        call    wipe_row
        mov     al, 22
        cbw
        call    rowofs
        call    wipe_row
        call    sel_entptrs
        mov     si, [pwhat]
        mov     al, 21
        cbw
        call    rowofs
        add     di, 4
        mov     ah, 17h         ; the .what line reads like a comment - gray
        call    puts
        ; the verb bar
        mov     si, t_verbs
        mov     di, 23*160+2
        mov     ah, 17h
        call    puts
        pop     bx
        ret

; ---------------------------------------------------------------------------
; WORK - the student's own directory, scanned live. The same three verbs,
; the same printed commands, so their file gets exactly the treatment a
; lesson gets. One new key: N.
; ---------------------------------------------------------------------------

work_screen:
.again:
        call    screen_init
        mov     si, t_work_bar
        mov     di, 0*160+2
        mov     ah, 70h
        call    puts
        call    scan_work
        xor     bx, bx
.draw:
        call    draw_work
.key:
        call    getkey
        cmp     ah, 48h
        jne     .nu
        or      bx, bx
        jz      .key
        dec     bx
        jmp     .draw
.nu:    cmp     ah, 50h
        jne     .nd
        mov     cl, [workcnt]
        xor     ch, ch
        jcxz    .key
        dec     cx
        cmp     bx, cx
        jae     .key
        inc     bx
        jmp     .draw
.nd:    cmp     al, 27
        jne     .ne
        ret
.ne:    call    upcase
        cmp     al, 'N'
        je      .new
        mov     cl, [workcnt]
        or      cl, cl
        jz      .key            ; nothing here yet but N
        cmp     al, 13
        je      .open
        cmp     al, 'O'
        je      .open
        cmp     al, 'B'
        je      .build
        cmp     al, 'R'
        je      .run
        jmp     .key

.open:  call    work_name       ; SI -> selected name
        mov     di, vbuf
        push    si
        mov     si, vb_fasmd
        call    strcpy
        pop     si
        call    strcpy
        mov     si, x_asm
        call    strcpy
        call    exec_work
        jmp     .again
.build: call    work_name       ; "FASM NAME.ASM NAME.COM"
        mov     di, vbuf
        push    si
        mov     si, vb_fasm
        call    strcpy
        pop     si
        push    si
        call    strcpy
        mov     si, x_asm2      ; ".ASM "
        call    strcpy
        pop     si
        call    strcpy
        mov     si, x_com
        call    strcpy
        call    exec_work
        jmp     .again
.run:   call    work_name       ; the name itself is the command
        mov     di, vbuf
        call    strcpy
        call    exec_work
        jmp     .again

.new:   call    ask_name        ; CY = cancelled
        jc      .again
        call    make_new        ; copy TOOLS\NEW.ASM to WORK\NAME.ASM
        mov     di, vbuf        ; and straight into the editor
        mov     si, vb_fasmd
        call    strcpy
        mov     si, namebuf
        call    strcpy
        mov     si, x_asm
        call    strcpy
        call    exec_work
        jmp     .again

; SI -> name of WORK entry BX
work_name:
        mov     ax, bx
        mov     cl, MAINSZ
        mul     cl
        add     ax, worknames
        mov     si, ax
        ret

draw_work:
        push    bx
        mov     cl, [workcnt]
        xor     ch, ch
        jcxz    .empty
        xor     dx, dx          ; DX = line
.e:     push    cx
        push    dx
        push    bx
        mov     ax, dx
        add     ax, 3
        call    rowofs
        add     di, 4
        mov     ah, 1Eh
        cmp     dx, bx
        jne     .a
        mov     ah, 2Fh
.a:     push    ax
        mov     ax, dx
        mov     cl, MAINSZ
        mul     cl
        add     ax, worknames
        mov     si, ax
        pop     ax
        call    puts_pad16
        pop     bx
        pop     dx
        pop     cx
        inc     dx
        dec     cx
        jnz     .e
        jmp     .bar
.empty: mov     si, t_work_empty
        mov     di, 4*160+4
        mov     ah, 17h
        call    puts
.bar:   mov     si, t_work_verbs
        mov     di, 23*160+2
        mov     ah, 17h
        call    puts
        pop     bx
        ret

; ask for the new program's name: letters and digits, up to eight
ask_name:
        mov     si, t_ask
        mov     di, 21*160+4
        mov     ah, 1Eh
        call    puts
        mov     di, namebuf
        xor     cx, cx          ; CX = length so far
.k:     call    getkey
        cmp     al, 27
        je      .no
        cmp     al, 13
        jne     .nb
        jcxz    .k              ; a name has at least one letter
        mov     byte [di], 0
        clc
        ret
.nb:    cmp     al, 8           ; backspace
        jne     .nc
        jcxz    .k
        dec     di
        dec     cx
        call    .echo_sp
        jmp     .k
.nc:    cmp     cx, 8
        jae     .k
        call    upcase
        cmp     al, '0'
        jb      .k
        cmp     al, '9'
        jbe     .ok
        cmp     al, 'A'
        jb      .k
        cmp     al, 'Z'
        ja      .k
.ok:    stosb
        inc     cx
        call    .echo
        jmp     .k
.no:    stc
        ret
.echo:  ; show the name as it is typed, right after the prompt
        push    di
        push    cx
        push    ax
        mov     di, 21*160+4+2*T_ASKLEN
        pop     ax
        push    ax
        push    es
        mov     es, [vseg]
        mov     ah, 1Fh
        add     di, cx
        add     di, cx
        sub     di, 2
        stosw
        pop     es
        pop     ax
        pop     cx
        pop     di
        ret
.echo_sp:
        push    di
        push    cx
        push    ax
        push    es
        mov     es, [vseg]
        mov     di, 21*160+4+2*T_ASKLEN
        add     di, cx
        add     di, cx
        mov     ax, 1F20h
        stosw
        pop     es
        pop     ax
        pop     cx
        pop     di
        ret

; copy \TOOLS\NEW.ASM to \WORK\<name>.ASM - create-new, so an existing
; file of that name is OPENED rather than wiped: nothing on the disk
; writes over the student's files, this program included
make_new:
        mov     di, pathbuf     ; "\WORK\NAME.ASM"
        mov     si, x_workpre
        call    strcpy
        mov     si, namebuf
        call    strcpy
        mov     si, x_asm
        call    strcpy
        mov     ah, 5Bh         ; create NEW - fails if it exists
        xor     cx, cx
        mov     dx, pathbuf
        int     21h
        jc      .done           ; already there: fine, just open it
        mov     [hdst], ax
        mov     ax, 3D00h       ; open the template for reading
        mov     dx, x_template
        int     21h
        jc      .close
        mov     [hsrc], ax
.loop:  mov     bx, [hsrc]
        mov     ah, 3Fh
        mov     cx, 512
        mov     dx, iobuf
        int     21h
        jc      .close2
        or      ax, ax
        jz      .close2
        mov     cx, ax
        mov     bx, [hdst]
        mov     ah, 40h
        mov     dx, iobuf
        int     21h
        jmp     .loop
.close2:
        mov     bx, [hsrc]
        mov     ah, 3Eh
        int     21h
.close: mov     bx, [hdst]
        mov     ah, 3Eh
        int     21h
.done:  ret

; ---------------------------------------------------------------------------
; Running things. The contract: print the command as the student would
; type it, run it through COMMAND.COM in the entry's own directory, wait
; for a key, hand the menu back.
; ---------------------------------------------------------------------------

exec_entry:                     ; vbuf = the command; dir from selection
        call    sel_entptrs
        mov     si, [pdir]
        jmp     exec_in
exec_work:
        mov     si, x_workdir
        ; fall through
exec_in:                        ; SI -> directory "\..."; vbuf = command
        mov     di, dirbuf
        call    strcpy

        mov     ax, 3           ; a clean text screen for the child
        int     10h
        call    cursor_show

        mov     dl, 'C'         ; the prompt, as the student would see it
        mov     ah, 2
        int     21h
        mov     dl, ':'
        int     21h
        mov     si, dirbuf
        call    puts_dos
        mov     dl, '>'
        mov     ah, 2
        int     21h
        mov     si, vbuf
        call    puts_dos
        call    crlf

        mov     dx, dirbuf      ; into the entry's directory -
        mov     ah, 3Bh         ; MAKE.BAT and the sources live there
        int     21h

        ; " /C " + command, as COMMAND.COM wants it: length, text, CR
        mov     di, tail_txt
        mov     si, x_slc
        call    strcpy
        mov     si, vbuf
        call    strcpy
        mov     ax, di
        sub     ax, tail_txt
        mov     byte [tail_len], al
        mov     al, 13
        stosb

        mov     [save_sp], sp   ; EXEC comes back with a foreign stack
        mov     dx, comspec
        mov     bx, epb
        mov     ax, 4B00h
        int     21h
        cli
        mov     ax, cs
        mov     ss, ax
        mov     sp, [cs:save_sp]
        sti
        push    cs
        pop     ds
        push    cs
        pop     es
        jnc     .ran
        mov     si, t_execfail
        call    puts_dos
.ran:
        mov     dx, x_root      ; back to the root
        mov     ah, 3Bh
        int     21h

        mov     ah, 0Fh         ; a game leaves mode 13h behind - only
        int     10h             ; reset if the child changed it, so build
        cmp     al, 3           ; output stays on screen to be read
        je      .txt
        mov     ax, 3
        int     10h
.txt:   mov     si, t_done
        call    puts_dos
        call    getkey
        ret

; ---------------------------------------------------------------------------
; Scanning. One pass over the manifests at startup; the .INF format is
; ".field value", CRLF, ASCII - the same file the web page and the
; bundler read.
; ---------------------------------------------------------------------------

scan_all:
        mov     word [entcnt], 0
        ; LESSONS and GAMES have a directory per entry
        mov     ax, [entcnt]
        mov     [secstart+0], ax
        mov     si, x_lessons
        call    scan_tree
        mov     ax, [entcnt]
        sub     ax, [secstart+0]
        mov     [seccnt2+0], ax
        mov     [seccnt+0], al

        mov     ax, [entcnt]
        mov     [secstart+2], ax
        call    scan_examples
        mov     ax, [entcnt]
        sub     ax, [secstart+2]
        mov     [seccnt2+2], ax
        mov     [seccnt+1], al

        mov     ax, [entcnt]
        mov     [secstart+4], ax
        mov     si, x_games
        call    scan_tree
        mov     ax, [entcnt]
        sub     ax, [secstart+4]
        mov     [seccnt2+4], ax
        mov     [seccnt+2], al
        ret

; scan "\<tier>\*" for directories, then each for one-or-more *.INF
scan_tree:
        mov     di, treebuf     ; keep "\TIER" for reuse
        mov     al, '\'
        stosb
        call    strcpy
        mov     byte [di], 0

        mov     di, pathbuf     ; "\TIER\*"
        mov     si, treebuf
        call    strcpy
        mov     si, x_star
        call    strcpy

        mov     dx, dta1
        mov     ah, 1Ah
        int     21h
        mov     dx, pathbuf
        mov     cx, 10h         ; directories too
        mov     ah, 4Eh
        int     21h
        jc      .done
.next:  test    byte [dta1+15h], 10h
        jz      .skip           ; plain file in the tier root
        cmp     byte [dta1+1Eh], '.'
        je      .skip
        ; "\TIER\DIR\*.INF"
        mov     di, dirbuf2
        mov     si, treebuf
        call    strcpy
        mov     al, '\'
        stosb
        mov     si, dta1+1Eh
        call    strcpy
        mov     byte [di], 0
        call    scan_infs       ; dirbuf2 = the entry directory
.skip:  mov     dx, dta1
        mov     ah, 1Ah
        int     21h
        mov     ah, 4Fh
        int     21h
        jnc     .next
.done:  ret

scan_examples:
        mov     di, dirbuf2
        mov     si, x_examplesd
        call    strcpy
        mov     byte [di], 0
        call    scan_infs
        ret

; find every *.INF in directory dirbuf2 and record an entry for each
scan_infs:
        mov     di, pathbuf
        mov     si, dirbuf2
        call    strcpy
        mov     si, x_inf
        call    strcpy
        mov     dx, dta2
        mov     ah, 1Ah
        int     21h
        mov     dx, pathbuf
        xor     cx, cx
        mov     ah, 4Eh
        int     21h
        jc      .done
.next:  call    record_entry
        mov     dx, dta2
        mov     ah, 1Ah
        int     21h
        mov     ah, 4Fh
        int     21h
        jnc     .next
.done:  ret

; one .INF (name in dta2) in directory dirbuf2 becomes one entry
record_entry:
        mov     ax, [entcnt]
        cmp     ax, MAXENT
        jae     .full
        call    entptrs

        mov     di, [pdir]      ; the directory, for chdir later
        mov     si, dirbuf2
        call    strcpy
        mov     byte [di], 0

        mov     si, [pflag]
        mov     byte [si], 0

        ; the title falls back to the file's own name
        mov     di, [ptitle]
        mov     si, dta2+1Eh
        call    strcpy
        mov     byte [di], 0
        mov     di, [pwhat]
        mov     byte [di], 0
        mov     di, [pmain]
        mov     byte [di], 0

        ; open "\DIR\NAME.INF" and read it whole
        mov     di, pathbuf
        mov     si, dirbuf2
        call    strcpy
        mov     al, '\'
        stosb
        mov     si, dta2+1Eh
        call    strcpy
        mov     byte [di], 0
        mov     ax, 3D00h
        mov     dx, pathbuf
        int     21h
        jc      .full
        mov     bx, ax
        mov     ah, 3Fh
        mov     cx, INFSZ
        mov     dx, infbuf
        int     21h
        push    ax
        mov     ah, 3Eh
        int     21h
        pop     ax
        mov     si, infbuf
        add     ax, si
        mov     di, ax
        mov     byte [di], 0    ; a hard stop for the line walker

.line:  cmp     byte [si], 0
        je      .parsed
        mov     bx, f_title
        call    matchf
        jc      .n1
        mov     di, [ptitle]
        mov     cx, TITLESZ-1
        call    cpval
        jmp     .eol
.n1:    mov     bx, f_what
        call    matchf
        jc      .n2
        mov     di, [pwhat]
        mov     cx, WHATSZ-1
        call    cpval
        jmp     .eol
.n2:    mov     bx, f_main
        call    matchf
        jc      .n3
        mov     di, [pmain]
        mov     cx, MAINSZ-1
        call    cpval
        jmp     .eol
.n3:    mov     bx, f_build
        call    matchf
        jc      .n4
        mov     di, [pflag]
        or      byte [di], 1
        jmp     .eol
.n4:    mov     bx, f_run
        call    matchf
        jc      .eol
        mov     di, [pflag]
        or      byte [di], 2
.eol:   ; to the byte after the next LF
        mov     al, [si]
        or      al, al
        jz      .parsed
        inc     si
        cmp     al, 10
        jne     .eol
        jmp     .line

.parsed:
        inc     word [entcnt]
.full:  ret

; live count of \WORK\*.ASM into worknames (extension stripped)
scan_work:
        call    count_work
        ret
count_work:
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        mov     byte [workcnt], 0
        mov     dx, dta2
        mov     ah, 1Ah
        int     21h
        mov     dx, x_workpat
        xor     cx, cx
        mov     ah, 4Eh
        int     21h
        jc      .done
.next:  mov     al, [workcnt]
        cmp     al, MAXWORK
        jae     .done
        cbw
        mov     cl, MAINSZ
        mul     cl
        add     ax, worknames
        mov     di, ax
        mov     si, dta2+1Eh
.cp:    lodsb
        cmp     al, '.'         ; stop at the extension
        je      .cut
        or      al, al
        jz      .cut
        stosb
        jmp     .cp
.cut:   mov     byte [di], 0
        inc     byte [workcnt]
        mov     dx, dta2
        mov     ah, 1Ah
        int     21h
        mov     ah, 4Fh
        int     21h
        jnc     .next
.done:  pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        ret

; ---------------------------------------------------------------------------
; Small tools.
; ---------------------------------------------------------------------------

; pointers to the fields of entry AX
entptrs:
        push    bx
        push    cx
        push    dx
        mov     bx, ax
        mov     cx, TITLESZ
        mul     cx
        add     ax, ent_title
        mov     [ptitle], ax
        mov     ax, bx
        mov     cx, WHATSZ
        mul     cx
        add     ax, ent_what
        mov     [pwhat], ax
        mov     ax, bx
        mov     cx, MAINSZ
        mul     cx
        add     ax, ent_main
        mov     [pmain], ax
        mov     ax, bx
        mov     cx, DIRSZ
        mul     cx
        add     ax, ent_dir
        mov     [pdir], ax
        mov     ax, bx
        add     ax, ent_flag
        mov     [pflag], ax
        mov     ax, bx
        pop     dx
        pop     cx
        pop     bx
        ret

; does the line at SI start with the field at BX (template ends with a
; space)? on a match SI moves past the field and its padding
matchf:
        push    di
        push    si
        mov     di, bx
.c:     mov     al, [di]
        or      al, al
        jz      .hit
        cmp     al, [si]
        jne     .miss
        inc     si
        inc     di
        jmp     .c
.hit:
.sp:    cmp     byte [si], ' '
        jne     .out
        inc     si
        jmp     .sp
.out:   pop     ax              ; the saved SI is not wanted back
        pop     di
        clc
        ret
.miss:  pop     si
        pop     di
        stc
        ret

; copy the rest of the line at SI into DI, at most CX chars, stop at CR/LF
cpval:
.c:     mov     al, [si]
        cmp     al, 13
        je      .end
        cmp     al, 10
        je      .end
        or      al, al
        jz      .end
        jcxz    .end
        mov     [di], al
        inc     si
        inc     di
        dec     cx
        jmp     .c
.end:   mov     byte [di], 0
        ret

strcpy:                         ; SI -> DI, and the copy is TERMINATED. DI
.c:     lodsb                   ; stays on the 0 so a second strcpy appends
        or      al, al          ; - without the terminator, "MAKE" written
        jz      .d              ; over a longer "FASMD MEMORY.C" left its
        stosb                   ; tail behind and DOS was asked to run
        jmp     .c              ; MAKED MEMORY.C. B and R died of exactly
.d:     dec     si              ; this on the disk's first flight.
        mov     byte [di], 0
        ret

upcase:
        cmp     al, 'a'
        jb      .d
        cmp     al, 'z'
        ja      .d
        sub     al, 32
.d:     ret

getkey:
        xor     ah, ah
        int     16h
        ret

crlf:
        mov     dl, 13
        mov     ah, 2
        int     21h
        mov     dl, 10
        mov     ah, 2
        int     21h
        ret

puts_dos:                       ; SI asciiz through DOS, so the cursor moves
.c:     lodsb
        or      al, al
        jz      .d
        mov     dl, al
        mov     ah, 2
        int     21h
        jmp     .c
.d:     ret

; DI = row*160 for the row in AX
rowofs:
        push    dx
        mov     dx, 160
        mul     dx
        mov     di, ax
        pop     dx
        ret

wipe_row:                       ; DI = row offset
        push    es
        push    di
        mov     es, [vseg]
        mov     cx, 80
        mov     ax, 1720h
        rep     stosw
        pop     di
        pop     es
        ret

; SI asciiz to the screen at DI (cell offset), attribute AH
puts:
        push    es
        mov     es, [vseg]
.c:     lodsb
        or      al, al
        jz      .d
        stosw
        jmp     .c
.d:     pop     es
        ret

putc:                           ; one char AL, attr AH, at ES-relative DI
        push    es
        mov     es, [vseg]
        stosw
        pop     es
        ret

; like puts but pads with spaces to 16 cells - keeps columns even
puts_pad16:
        mov     cx, 16
        jmp     puts_padn
puts_pad60:
        mov     cx, 60
puts_padn:
        push    es
        mov     es, [vseg]
.c:     lodsb
        or      al, al
        jz      .pad
        stosw
        dec     cx
        jnz     .c
        jmp     .d
.pad:   mov     al, ' '
        jcxz    .d
.p:     stosw
        dec     cx
        jnz     .p
.d:     pop     es
        ret

putnum:                         ; AL = 0..99 in the current attr at DI
        push    es
        mov     es, [vseg]
        aam                     ; AH = tens, AL = ones
        or      ah, ah
        jz      .ones
        push    ax
        mov     al, ah
        add     al, '0'
        mov     ah, [numattr]
        stosw
        pop     ax
.ones:  add     al, '0'
        mov     ah, [numattr]
        stosw
        pop     es
        ret

screen_init:
        mov     ax, 3
        int     10h
        call    cursor_hide
        push    es
        mov     es, [vseg]
        xor     di, di
        mov     cx, 2000
        mov     ax, 1720h       ; the blue desktop - the workbench palette,
        rep     stosw           ; same numbers as FASMD.INI
        pop     es
        ret

cursor_hide:
        mov     ah, 1
        mov     cx, 2000h
        int     10h
        ret
cursor_show:
        mov     ah, 1
        mov     cx, 0607h
        int     10h
        ret

; COMSPEC out of the environment - children are run through COMMAND.COM,
; which is also what resolves PATH
find_comspec:
        push    ds
        push    es
        mov     es, [cs:2Ch]    ; the environment segment, from the PSP
        xor     di, di
.var:   cmp     byte [es:di], 0
        je      .miss           ; end of the environment, no COMSPEC
        push    di
        mov     si, x_comspec
.c:     lodsb
        or      al, al
        jz      .found
        cmp     al, [es:di]
        jne     .nextv
        inc     di
        jmp     .c
.nextv: pop     di
.skipz: cmp     byte [es:di], 0
        je      .z
        inc     di
        jmp     .skipz
.z:     inc     di
        jmp     .var
.found: pop     ax              ; the value follows the '='
        push    cs
        pop     ds
        mov     bx, comspec
.cpy:   mov     al, [es:di]
        mov     [bx], al
        inc     di
        inc     bx
        or      al, al
        jnz     .cpy
        pop     es
        pop     ds
        ret
.miss:  push    cs
        pop     ds
        mov     si, x_command   ; fall back to a bare COMMAND.COM
        mov     di, comspec
        call    strcpy
        mov     byte [di], 0
        pop     es
        pop     ds
        ret

; ---------------------------------------------------------------------------
; Text. ASCII, like everything the disk carries.
; ---------------------------------------------------------------------------

t_title      db 'WIRE CITY WORKBENCH - the disk is the course',0
t_hint_top   db 'arrows choose   ENTER opens   ESC leaves you at the DOS prompt',0
t_verbs      db 'ENTER open   B build   R run   ESC back',0
t_work_verbs db 'N new   ENTER open   B build   R run   ESC back',0
t_work_bar   db 'WORK - your own programs',0
t_work_empty db '(empty - N starts a new program)',0
t_readonly   db 'nothing to build here - this entry is for reading. ENTER opens it.',0
t_ask        db 'name for the new program: ',0
T_ASKLEN = $ - t_ask - 1
t_done       db 13,10,'-- a key returns to the catalogue --',0
t_execfail   db 13,10,'could not run it - COMMAND.COM was not where COMSPEC says.',0
t_bye        db 'The catalogue is one word away: MENU',13,10
             db 'Your own files live in C:\WORK',13,10,'$'

secnames     dw sn0, sn1, sn2, sn3
secdescs     dw sd0, sd1, sd2, sd3
sn0 db 'LESSONS',0
sn1 db 'EXAMPLES',0
sn2 db 'GAMES',0
sn3 db 'WORK',0
sd0 db 'one idea, built from nothing ',0
sd1 db 'the same idea, standalone and running ',0
sd2 db 'the same idea in production, at scale ',0
sd3 db 'your own programs ',0

f_title      db '.title ',0
f_what       db '.what ',0
f_main       db '.main ',0
f_build      db '.build ',0
f_run        db '.run ',0

vb_fasmd     db 'FASMD ',0
vb_fasm      db 'FASM ',0
vb_make      db 'MAKE',0
vb_run       db 'RUN',0

x_lessons    db 'LESSONS',0
x_games      db 'GAMES',0
x_examplesd  db '\EXAMPLES',0
x_star       db '\*',0
x_inf        db '\*.INF',0
x_workpat    db '\WORK\*.ASM',0
x_workdir    db '\WORK',0
x_workpre    db '\WORK\',0
x_template   db '\TOOLS\NEW.ASM',0
x_root       db '\',0
x_asm        db '.ASM',0
x_asm2       db '.ASM ',0
x_com        db '.COM',0
x_slc        db ' /C ',0
x_comspec    db 'COMSPEC=',0
x_command    db 'COMMAND.COM',0

vseg         dw TEXTSEG
numattr      db 07h

; the EXEC parameter block - the segments are stamped in at startup
epb          dw 0               ; environment: 0 = the child inherits ours
             dw tail_len
epb_tseg     dw 0
             dw fcb1
epb_f1seg    dw 0
             dw fcb2
epb_f2seg    dw 0

fcb1         db 0, 11 dup (' '), 25 dup (0)
fcb2         db 0, 11 dup (' '), 25 dup (0)

; ---------------------------------------------------------------------------
; State and buffers.
; ---------------------------------------------------------------------------

entcnt       dw 0
cursec       dw 0
cursel       dw 0
curcnt       dw 0
seccnt       db 0, 0, 0         ; byte counts for the top screen
seccnt2      dw 0, 0, 0         ; word copies for arithmetic
secstart     dw 0, 0, 0
workcnt      db 0

ptitle       dw 0
pwhat        dw 0
pmain        dw 0
pdir         dw 0
pflag        dw 0
ax_save      dw 0

save_sp      dw 0
hsrc         dw 0
hdst         dw 0

tail_len     db 0
tail_txt     rb 100

comspec      rb 80
vbuf         rb 60
namebuf      rb 12
pathbuf      rb 128
dirbuf       rb 64
dirbuf2      rb 64
treebuf      rb 32
dta1         rb 43
dta2         rb 43
iobuf        rb 512
infbuf       rb INFSZ+1

ent_title    rb MAXENT*TITLESZ
ent_what     rb MAXENT*WHATSZ
ent_main     rb MAXENT*MAINSZ
ent_dir      rb MAXENT*DIRSZ
ent_flag     rb MAXENT
worknames    rb MAXWORK*MAINSZ

             rb 256             ; the stack
stacktop:
progpara = (stacktop + 15) shr 4
