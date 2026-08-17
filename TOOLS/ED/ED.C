/* ===========================================================================
 *  ED - the editor this course is typed in.
 *
 *      ED TURN.ASM
 *
 *  IT EXISTS BECAUSE FIVE TAKES WERE LOST TO SOMEBODY ELSE'S DIALOGS.
 *  The lessons are typed by a rig that cannot see the screen: it sends
 *  keystrokes down a serial line and trusts the editor to be where it left
 *  it. Volkov Commander is a fine editor for a person and an impossible one
 *  for a machine - its state is invisible. Ctrl-O toggles the panels, and
 *  with them hidden Shift-F4 does nothing at all; the rig types the rest of
 *  the lesson into the command prompt and runs happily to the end. The take
 *  log shows the two file-opens with byte-identical keystrokes, one working
 *  and one not.
 *
 *  So this editor has NO DIALOGS. None. The file comes from the command
 *  line, F2 saves without asking, Alt-X leaves without asking. There is
 *  nothing to be in the wrong state.
 *
 *  AND IT IS PART OF THE COURSE. Written in C first, with Open Watcom -
 *  the compiler lesson 1 already uses - because it has to work before it
 *  can teach. Later it gets written again in assembly, on camera, and the
 *  two are compared. That is the same shape as lesson 5B: do it the clear
 *  way, then do it the cheap way, and show they agree.
 *
 *      wcl -0 -ml -bcl=dos ED.C
 *
 *  -0 is an 8086 build, on purpose: this editor runs on the machine the
 *  course is about.
 * ======================================================================== */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <conio.h>
#include <dos.h>

#define COLS      80
#define ROWS      25
#define MAXLINES  2000
#define MAXCOL    250

/* The edit area sits inside the frame: row 0 is the menu, row 1 the top of
 * the frame, row 23 the bottom of it, row 24 the key bar. */
#define TOP       2
#define BOTTOM    22
#define PAGE      (BOTTOM - TOP + 1)
#define LEFT      1
#define WIDTH     (COLS - 2)

/* Turbo Vision's palette, near enough: a blue desktop, a white frame, and a
 * cyan bar of function keys along the bottom. Anyone who used a DOS IDE
 * knows where to look before they have read a word. */
#define C_DESK    0x17      /* white on blue    */
#define C_FRAME   0x1F      /* bright white     */
#define C_TITLE   0x1E      /* yellow on blue   */
#define C_TEXT    0x17
#define C_MENU    0x30      /* black on cyan    */
#define C_KEY     0x3F      /* white on cyan    */
#define C_NUM     0x30
#define C_MSG     0x4F      /* white on red     */

static char far *vid = (char far *) 0xB8000000L;

static char  *ln[MAXLINES];
static int    nlines = 0;
static int    cy = 0, cx = 0;      /* the cursor, in the FILE            */
static int    top = 0, left = 0;   /* the first line and column on screen */
static char   fname[80];
static int    dirty = 0;
static char   msg[COLS + 1];

/* ---- the screen, written straight into the card's memory ---------------- */
static void put(int row, int col, int attr, const char *s)
{
    char far *p = vid + (row * COLS + col) * 2;
    while (*s && col < COLS) { *p++ = *s++; *p++ = (char) attr; col++; }
}

static void fill(int row, int col, int n, int attr, char ch)
{
    char far *p = vid + (row * COLS + col) * 2;
    while (n-- > 0) { *p++ = ch; *p++ = (char) attr; }
}

static void cursor(int row, int col)
{
    union REGS r;
    r.h.ah = 2; r.h.bh = 0; r.h.dh = (unsigned char) row; r.h.dl = (unsigned char) col;
    int86(0x10, &r, &r);
}

/* ---- the furniture ------------------------------------------------------ */
static void frame(void)
{
    int i;
    char t[COLS];

    fill(0, 0, COLS, C_MENU, ' ');
    put(0, 1, C_MENU, " File   Edit   Build   Help ");

    /* the top of the frame, with the file's name sitting in it, which is the
     * one thing you always want to know and never want to ask for */
    fill(1, 0, COLS, C_FRAME, (char) 205);          /* a double line */
    vid[(1 * COLS + 0) * 2]           = (char) 201;
    vid[(1 * COLS + COLS - 1) * 2]    = (char) 187;
    sprintf(t, " %s%s ", fname, dirty ? " *" : "");
    put(1, (COLS - (int) strlen(t)) / 2, C_TITLE, t);

    for (i = TOP; i <= BOTTOM; i++)
    {
        fill(i, 0, 1, C_FRAME, (char) 186);
        fill(i, COLS - 1, 1, C_FRAME, (char) 186);
    }
    fill(BOTTOM + 1, 0, COLS, C_FRAME, (char) 205);
    vid[((BOTTOM + 1) * COLS + 0) * 2]        = (char) 200;
    vid[((BOTTOM + 1) * COLS + COLS - 1) * 2] = (char) 188;
}

static void keybar(void)
{
    static const char *k[10] = {
        "Help", "Save", "    ", "    ", "    ",
        "    ", "    ", "    ", "Build", "Run"
    };
    int i, col = 0;
    char n[4];

    fill(24, 0, COLS, C_KEY, ' ');
    for (i = 0; i < 10; i++)
    {
        sprintf(n, "%d", i + 1);
        put(24, col, C_NUM, n);
        put(24, col + (i < 9 ? 1 : 2), C_KEY, k[i]);
        col += 8;
    }
}

static void status(const char *s)
{
    strncpy(msg, s, COLS); msg[COLS] = 0;
}

static void draw(void)
{
    int i, r;
    char t[COLS + 1];

    frame();
    keybar();
    for (i = 0; i < PAGE; i++)
    {
        r = TOP + i;
        fill(r, LEFT, WIDTH, C_TEXT, ' ');
        if (top + i < nlines)
        {
            const char *s = ln[top + i];
            int len = (int) strlen(s);
            if (left < len)
            {
                strncpy(t, s + left, WIDTH); t[WIDTH] = 0;
                put(r, LEFT, C_TEXT, t);
            }
        }
    }
    if (msg[0])
    {
        put(BOTTOM, LEFT, C_MSG, msg);
        msg[0] = 0;
    }
    /* line and column, bottom right of the frame */
    sprintf(t, " %d:%d ", cy + 1, cx + 1);
    put(BOTTOM + 1, COLS - 1 - (int) strlen(t), C_TITLE, t);
    cursor(TOP + (cy - top), LEFT + (cx - left));
}

/* ---- the file ----------------------------------------------------------- */
static char *dup(const char *s)
{
    char *p = (char *) malloc(strlen(s) + 1);
    if (p) strcpy(p, s);
    return p;
}

static void load(const char *path)
{
    FILE *f = fopen(path, "r");
    char buf[MAXCOL + 2];
    int n;

    nlines = 0;
    if (f)
    {
        while (nlines < MAXLINES && fgets(buf, sizeof(buf), f))
        {
            n = (int) strlen(buf);
            while (n > 0 && (buf[n - 1] == '\n' || buf[n - 1] == '\r')) buf[--n] = 0;
            ln[nlines++] = dup(buf);
        }
        fclose(f);
    }
    if (nlines == 0) ln[nlines++] = dup("");
    dirty = 0;
}

/* CRLF, always. This file is read by DOS tools and shown in DOS editors,
 * and a lone LF makes Volkov show the whole program as one endless line. */
static int save(void)
{
    FILE *f = fopen(fname, "wb");
    int i;
    if (!f) return 0;
    for (i = 0; i < nlines; i++) fprintf(f, "%s\r\n", ln[i]);
    fclose(f);
    dirty = 0;
    return 1;
}

/* ---- editing ------------------------------------------------------------ */
static void scroll_into_view(void)
{
    if (cy < top) top = cy;
    if (cy >= top + PAGE) top = cy - PAGE + 1;
    if (cx < left) left = cx;
    if (cx >= left + WIDTH) left = cx - WIDTH + 1;
    if (top < 0) top = 0;
    if (left < 0) left = 0;
}

static void insert_char(int ch)
{
    char *s = ln[cy];
    int len = (int) strlen(s);
    char *n;
    if (len >= MAXCOL) return;
    n = (char *) malloc(len + 2);
    if (!n) return;
    memcpy(n, s, cx);
    n[cx] = (char) ch;
    strcpy(n + cx + 1, s + cx);
    free(s); ln[cy] = n;
    cx++; dirty = 1;
}

static void split_line(void)
{
    int i;
    char *s = ln[cy];
    char *a, *b;
    if (nlines >= MAXLINES) return;
    a = (char *) malloc(cx + 1);
    b = dup(s + cx);
    if (!a || !b) return;
    memcpy(a, s, cx); a[cx] = 0;
    free(s);
    for (i = nlines; i > cy; i--) ln[i] = ln[i - 1];
    ln[cy] = a; ln[cy + 1] = b;
    nlines++;
    cy++; cx = 0; dirty = 1;
}

static void join_prev(void)
{
    int i, len;
    char *n;
    if (cy == 0) return;
    len = (int) strlen(ln[cy - 1]);
    n = (char *) malloc(len + strlen(ln[cy]) + 1);
    if (!n) return;
    strcpy(n, ln[cy - 1]); strcat(n, ln[cy]);
    free(ln[cy - 1]); free(ln[cy]);
    ln[cy - 1] = n;
    for (i = cy; i < nlines - 1; i++) ln[i] = ln[i + 1];
    nlines--;
    cy--; cx = len; dirty = 1;
}

static void backspace(void)
{
    char *s;
    int len;
    if (cx > 0)
    {
        s = ln[cy]; len = (int) strlen(s);
        memmove(s + cx - 1, s + cx, len - cx + 1);
        cx--; dirty = 1;
    }
    else join_prev();
}

static void del_char(void)
{
    char *s = ln[cy];
    int len = (int) strlen(s);
    if (cx < len) { memmove(s + cx, s + cx + 1, len - cx); dirty = 1; }
    else if (cy + 1 < nlines) { cy++; cx = 0; join_prev(); }
}

static void clamp(void)
{
    int len;
    if (cy < 0) cy = 0;
    if (cy >= nlines) cy = nlines - 1;
    len = (int) strlen(ln[cy]);
    if (cx > len) cx = len;
    if (cx < 0) cx = 0;
}

/* ---- build and run ------------------------------------------------------ */
/* Both PRINT THE COMMAND before running it. The viewer is meant to learn
 * that F9 is a shortcut for something they could type themselves - not that
 * building is a magic button. */
static void shell_out(const char *cmd)
{
    union REGS r;
    r.h.ah = 0; r.h.al = 3; int86(0x10, &r, &r);     /* clear, back to text */
    printf("%s\n", cmd);
    system(cmd);
    printf("\n-- any key --");
    getch();
    r.h.ah = 0; r.h.al = 3; int86(0x10, &r, &r);
}

/* FASM says   FILE.ASM [123]:   when it stops. Find that number and put the
 * cursor on the line, because the difference between "I will fix it" and "I
 * will close this" is whether you are shown where. */
static void build(void)
{
    char cmd[160], base[80], *dot;
    char lineno[16];
    FILE *f;
    char buf[200];
    int n;

    if (!save()) { status("cannot write the file"); return; }
    strcpy(base, fname);
    dot = strchr(base, '.');
    if (dot) *dot = 0;
    sprintf(cmd, "FASM %s > ED.ERR", fname);
    shell_out(cmd);

    f = fopen("ED.ERR", "r");
    if (!f) return;
    while (fgets(buf, sizeof(buf), f))
    {
        char *b = strchr(buf, '[');
        char *e = b ? strchr(b, ']') : 0;
        if (b && e && strstr(buf, ".ASM"))
        {
            n = (int) (e - b - 1);
            if (n > 0 && n < 15)
            {
                memcpy(lineno, b + 1, n); lineno[n] = 0;
                cy = atoi(lineno) - 1;
                cx = 0; clamp(); scroll_into_view();
            }
        }
        if (strstr(buf, "error:")) status(buf);
    }
    fclose(f);
}

static void run(void)
{
    char cmd[100], base[80], *dot;
    strcpy(base, fname);
    dot = strchr(base, '.');
    if (dot) *dot = 0;
    sprintf(cmd, "%s.COM", base);
    shell_out(cmd);
}

/* ---- the loop ----------------------------------------------------------- */
int main(int argc, char **argv)
{
    int ch;
    union REGS r;

    if (argc < 2)
    {
        printf("ED - the course editor\n\n  ED <file>\n\n"
               "F2 save   F9 build   F10 run   Alt-X quit\n");
        return 1;
    }
    strncpy(fname, argv[1], sizeof(fname) - 1);
    strupr(fname);
    load(fname);

    r.h.ah = 0; r.h.al = 3; int86(0x10, &r, &r);
    status("");
    draw();

    for (;;)
    {
        ch = getch();
        if (ch == 0 || ch == 0xE0)
        {
            ch = getch();
            switch (ch)
            {
            case 0x48: cy--; break;                       /* up      */
            case 0x50: cy++; break;                       /* down    */
            case 0x4B: if (cx > 0) cx--;
                       else if (cy > 0) { cy--; cx = (int) strlen(ln[cy]); } break;
            case 0x4D: if (cx < (int) strlen(ln[cy])) cx++;
                       else if (cy + 1 < nlines) { cy++; cx = 0; } break;
            /* HOME GOES TO COLUMN ZERO. Volkov's goes to the first non-blank,
             * which is why every lesson script says END-then-ENTER instead of
             * HOME: landing in front of a line and typing drags that line
             * along at the end of everything typed. Here it means column 0,
             * and a script can rely on it. */
            case 0x47: cx = 0; break;                     /* Home    */
            case 0x4F: cx = (int) strlen(ln[cy]); break;  /* End     */
            case 0x49: cy -= PAGE; break;                 /* PgUp    */
            case 0x51: cy += PAGE; break;                 /* PgDn    */
            case 0x84: cy = 0; cx = 0; break;             /* Ctrl-PgUp */
            case 0x76: cy = nlines - 1; cx = 0; break;    /* Ctrl-PgDn */
            case 0x77: cy = 0; cx = 0; break;             /* Ctrl-Home */
            case 0x75: cy = nlines - 1; break;            /* Ctrl-End  */
            case 0x53: del_char(); break;                 /* Del     */
            case 0x3C: if (save()) status("saved"); break;         /* F2  */
            case 0x43: build(); break;                             /* F9  */
            case 0x44: run(); break;                               /* F10 */
            case 0x2D: save(); r.h.ah = 0; r.h.al = 3;             /* Alt-X */
                       int86(0x10, &r, &r);
                       return 0;
            default: break;
            }
        }
        else if (ch == 13) split_line();
        else if (ch == 8)  backspace();
        else if (ch == 9)  { int i; for (i = 0; i < 8; i++) insert_char(' '); }
        else if (ch >= 32 && ch < 127) insert_char(ch);

        clamp();
        scroll_into_view();
        draw();
    }
}
