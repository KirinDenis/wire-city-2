# pack.ps1 -Game <OWLFLY|OWLFLY2|WIRECITY|TRAINER> - build a versioned js-dos bundle.
#
# js-dos caches extracted bundles in IndexedDB keyed by the bundle PATH,
# so every release gets a NEW FILENAME: <prefix>_vN.jsdos. This script
# reads the current N from the game's PLAYER PAGE, packs v(N+1), retires
# the older bundles of that game and patches the page.
# Built with .NET ZipArchive: PS 5.1 Compress-Archive writes backslash
# entry names which break js-dos unzip.
param([string]$Game = "OWLFLY")

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Split-Path -Parent $PSScriptRoot

# ---- the per-game map: add a game = add an entry --------------------------
$MAP = @{
  OWLFLY2 = @{
    prefix = "owlfly2"
    page   = Join-Path $root "docs\owlfly2.html"
    detect = "owlfly2_v(\d+)\.jsdos"
    files  = @(
      @{ p = "GAMES\OWLFLY2\INSTALL\FLYOWL2.EXE"; n = "FLYOWL2.EXE" },
      @{ p = "GAMES\OWLFLY2\INSTALL\CITY.DAT";    n = "CITY.DAT" },
      # the 90-degree cockpit views. Its own file because CITY.DAT is read
      # in one go with CX=0FFF0h and the front panel is 64000 of those bytes.
      @{ p = "GAMES\OWLFLY2\INSTALL\CPSIDE.DAT";  n = "CPSIDE.DAT" },
      # the recorded sound bank (TOOLS\Snd2Dat). Optional to the GAME - no
      # file and SFXPLAY is a no-op - which is exactly why leaving it out of
      # here was silent: the browser build simply had no effects, while the
      # engine note carried on because it is generated.
      @{ p = "GAMES\OWLFLY2\INSTALL\SFX.DAT";     n = "SFX.DAT" }
    )
    # NO .jsdos/jsdos.json HERE, AND THAT IS DELIBERATE. js-dos draws a
    # stick and buttons of its own from such a file, and for one afternoon
    # it did. Two of its rules cannot be configured: a button caption is
    # symbol.substr(0,1) - one character, so the lock button read as a zero
    # - and its joystick splits the circle into eight equal sectors, so a
    # thumb 25 degrees off straight-down gets a roll. The controls moved
    # into owlfly2.html, where both are ours to set. Put a jsdos.json back
    # and the pilot gets BOTH sets of buttons on top of each other.
    # Left out ON PURPOSE, and named here so the "not in the bundle" warning
    # below stays quiet about it. A warning that always fires is a warning
    # nobody reads, which would put us straight back where SFX.DAT was.
    # ENGINE.RAW: OWL FLY II generates its turbine (GENBED) and has since
    # 2026-07-23. The file in INSTALL is a leftover of the version that
    # loaded one.
    ignore = @("ENGINE.RAW")
    strings = @(
      # the BBS lesson (2026-07-19): minimal conf, and [ipx] ipx=true is
      # what lets the page's networkConnect reach the game's INT 7Ah
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[ipx]`nipx=true`n[autoexec]`necho off`nmount c .`nc:`nFLYOWL2`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[ipx]`nipx=true`n[autoexec]`necho off`nmount c .`nc:`nFLYOWL2`n" }
    )
  }
  OWLFLY3 = @{
    # the retro-cards release, on a COLOUR machine: the front step offers
    # CGA / EGA x2 / MCGA / VGA x2 and marks Hercules away. The mono
    # edition is its own bundle (OWLFLY3H) because the MACHINE differs.
    prefix = "owlfly3"
    page   = Join-Path $root "docs\owlfly3.html"
    detect = "owlfly3_v(\d+)\.jsdos"
    files  = @(
      @{ p = "GAMES\OWLFLY3\INSTALL\OWLFLY3.EXE"; n = "OWLFLY3.EXE" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CITY.DAT";    n = "CITY.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPSIDE.DAT";  n = "CPSIDE.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SFX.DAT";     n = "SFX.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SHCAB.DAT";   n = "SHCAB.DAT" },
      # the retro cards' baked cockpits, side-console marker maps
      # (TOOLS\VidRig emit) and the Shilka's retro cabins (TOOLS\Cab2Dat) -
      # miss one and that card flies on the plain lookup, silently, which
      # is exactly the SFX.DAT shape of failure
      @{ p = "GAMES\OWLFLY3\INSTALL\CPCGA.DAT";   n = "CPCGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPEGA.DAT";   n = "CPEGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPHGC.DAT";   n = "CPHGC.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPSCGA.DAT";  n = "CPSCGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPSEGA.DAT";  n = "CPSEGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPSHGC.DAT";  n = "CPSHGC.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SHCCGA.DAT";  n = "SHCCGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SHCEGA.DAT";  n = "SHCEGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SHCHGC.DAT";  n = "SHCHGC.DAT" },
      # the Shilka's F6/F7 side consoles (Cab2Dat -left/-right): the VGA
      # paint and the three marker bakes, same optional-but-silent shape
      @{ p = "GAMES\OWLFLY3\INSTALL\SHSIDE.DAT";  n = "SHSIDE.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SHSCGA.DAT";  n = "SHSCGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SHSEGA.DAT";  n = "SHSEGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SHSHGC.DAT";  n = "SHSHGC.DAT" }
    )
    ignore = @("ENGINE.RAW")
    # THE WIRE IS BACK (2026-08-25): v3 flies its OWN relay room - owlfly3,
    # not owlfly2 - so the byte-identical protocol can never walk into v2's
    # skies. The separation lives in the relay URL (the page's business);
    # ipx=true here only wakes the driver.
    strings = @(
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[ipx]`nipx=true`n[autoexec]`necho off`nmount c .`nc:`nOWLFLY3`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[ipx]`nipx=true`n[autoexec]`necho off`nmount c .`nc:`nOWLFLY3`n" }
    )
  }
  OWLFLY3H = @{
    # the Hercules edition: the same game, the same files, but DOSBox
    # comes up as a real mono machine - the only place 720x348 exists.
    # The front step's hardware quiz lands on 1) HERCULES by itself.
    prefix = "owlfly3h"
    page   = Join-Path $root "docs\owlfly3h.html"
    detect = "owlfly3h_v(\d+)\.jsdos"
    files  = @(
      @{ p = "GAMES\OWLFLY3\INSTALL\OWLFLY3.EXE"; n = "OWLFLY3.EXE" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CITY.DAT";    n = "CITY.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPSIDE.DAT";  n = "CPSIDE.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SFX.DAT";     n = "SFX.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SHCAB.DAT";   n = "SHCAB.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPCGA.DAT";   n = "CPCGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPEGA.DAT";   n = "CPEGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPHGC.DAT";   n = "CPHGC.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPSCGA.DAT";  n = "CPSCGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPSEGA.DAT";  n = "CPSEGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\CPSHGC.DAT";  n = "CPSHGC.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SHCCGA.DAT";  n = "SHCCGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SHCEGA.DAT";  n = "SHCEGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SHCHGC.DAT";  n = "SHCHGC.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SHSIDE.DAT";  n = "SHSIDE.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SHSCGA.DAT";  n = "SHSCGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SHSEGA.DAT";  n = "SHSEGA.DAT" },
      @{ p = "GAMES\OWLFLY3\INSTALL\SHSHGC.DAT";  n = "SHSHGC.DAT" }
    )
    ignore = @("ENGINE.RAW")
    strings = @(
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=hercules`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[ipx]`nipx=true`n[autoexec]`necho off`nmount c .`nc:`nOWLFLY3`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=hercules`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[ipx]`nipx=true`n[autoexec]`necho off`nmount c .`nc:`nOWLFLY3`n" }
    )
  }
  OWLFLY = @{
    prefix = "owlfly"
    page   = Join-Path $root "docs\owlfly.html"
    detect = "(?:city|owlfly)_v(\d+)\.jsdos"
    files  = @(
      @{ p = "GAMES\OWLFLY\INSTALL\FLYOWL.COM";   n = "FLYOWL.COM" },
      @{ p = "GAMES\OWLFLY\INSTALL\CITY.DAT";   n = "CITY.DAT" },
      @{ p = "GAMES\OWLFLY\INSTALL\ENGINE.RAW"; n = "ENGINE.RAW" },
      @{ p = "docs\dosbox.conf";      n = ".jsdos/dosbox.conf" },
      @{ p = "docs\dosbox-root.conf"; n = "dosbox.conf" }
    )
    strings = @()
  }
  TRAINER = @{
    prefix = "field"
    page   = Join-Path $root "docs\play.html"
    detect = "field_v(\d+)\.jsdos"
    files  = @(
      @{ p = "GAMES\TRAINER\FIELD.COM";  n = "FIELD.COM" },
      @{ p = "GAMES\TRAINER\PLANE1.DAT"; n = "PLANE1.DAT" },
      @{ p = "GAMES\TRAINER\RBASE1.DAT"; n = "RBASE1.DAT" },
      @{ p = "GAMES\TRAINER\RDISH1.DAT"; n = "RDISH1.DAT" },
      @{ p = "GAMES\TRAINER\TWR1.DAT";   n = "TWR1.DAT" },
      @{ p = "GAMES\TRAINER\CKPT1.DAT";  n = "CKPT1.DAT" },
      @{ p = "GAMES\TRAINER\CNPY1.DAT";  n = "CNPY1.DAT" }
    )
    strings = @(
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`nfield`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`nfield`n" }
    )
  }
  # The odd one out: this bundle is not a game, it is a WORKSHOP. It carries
  # SOURCES and the assembler rather than a finished binary, and the visitor
  # builds the programs themselves by typing MAKE - which is the entire point
  # of the lesson, and the reason FASM.EXE and CWSDPMI.EXE are in the list.
  # Their licences are in the list for the same reason: shipping the binaries
  # is only allowed with the notices beside them (see THIRD-PARTY.md).
  # The .BAT files come from LESSONS\L02\WEB and not from the lesson folder,
  # because in here every file sits in one directory and the lesson's own
  # MAKE.BAT reaches the assembler through ..\..\TOOLS\FASM.
  L02 = @{
    prefix = "l02"
    page   = Join-Path $root "docs\l02.html"
    detect = "l02_v(\d+)\.jsdos"
    files  = @(
      @{ p = "LESSONS\L02\HELLO.ASM";     n = "HELLO.ASM" },
      @{ p = "LESSONS\L02\HELLO2.ASM";    n = "HELLO2.ASM" },
      @{ p = "LESSONS\L02\HEX.ASM";       n = "HEX.ASM" },
      @{ p = "LESSONS\L02\WEB\MAKE.BAT";  n = "MAKE.BAT" },
      @{ p = "LESSONS\L02\WEB\EDIT.BAT";  n = "EDIT.BAT" },
      @{ p = "LESSONS\L02\WEB\HELP.BAT";  n = "HELP.BAT" },
      @{ p = "TOOLS\FASM\FASM.EXE";       n = "FASM.EXE" },
      @{ p = "TOOLS\FASM\FASMD.EXE";      n = "FASMD.EXE" },
      @{ p = "TOOLS\FASM\LICENSE.TXT";    n = "LICENSE.TXT" },
      @{ p = "TOOLS\CWSDPMI\CWSDPMI.EXE"; n = "CWSDPMI.EXE" },
      @{ p = "TOOLS\CWSDPMI\cwsdpmi.doc"; n = "CWSDPMI.DOC" }
    )
    # No binaries: the visitor assembles them. Shipping HELLO.COM would let
    # somebody reach step 3 without ever having run the assembler, and then
    # the page is a toy rather than a lesson.
    strings = @(
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`ncls`nHELP.BAT`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`ncls`nHELP.BAT`n" }
    )
  }
  # Lesson 3, same workshop shape as L02: sources and the assembler, no
  # binary. EDIT.BAT and FASMD.EXE come along because this is the first
  # lesson where changing a number and rebuilding is worth doing - one
  # constant is the colour of the dot.
  L03 = @{
    prefix = "l03"
    page   = Join-Path $root "docs\l03.html"
    detect = "l03_v(\d+)\.jsdos"
    files  = @(
      @{ p = "LESSONS\L03\PIXEL.ASM";     n = "PIXEL.ASM" },
      @{ p = "LESSONS\L03\WEB\MAKE.BAT";  n = "MAKE.BAT" },
      @{ p = "LESSONS\L03\WEB\RUN.BAT";   n = "RUN.BAT" },
      @{ p = "LESSONS\L03\WEB\HELP.BAT";  n = "HELP.BAT" },
      @{ p = "LESSONS\L02\WEB\EDIT.BAT";  n = "EDIT.BAT" },
      @{ p = "TOOLS\FASM\FASM.EXE";       n = "FASM.EXE" },
      @{ p = "TOOLS\FASM\FASMD.EXE";      n = "FASMD.EXE" },
      @{ p = "TOOLS\FASM\LICENSE.TXT";    n = "LICENSE.TXT" },
      @{ p = "TOOLS\CWSDPMI\CWSDPMI.EXE"; n = "CWSDPMI.EXE" },
      @{ p = "TOOLS\CWSDPMI\cwsdpmi.doc"; n = "CWSDPMI.DOC" }
    )
    strings = @(
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`ncls`nHELP.BAT`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`ncls`nHELP.BAT`n" }
    )
  }
  # Lesson 5, the workshop shape again. MKSIN.C rides along as SOURCE ONLY:
  # it needs a C compiler and floating point, and neither is in here. That is
  # not a gap in the bundle, it is the lesson's own argument - the modern
  # tool prepares the data somewhere else and the 8086 never meets it. So
  # SINT.INC is shipped finished, and MKSIN.C is shipped to be read.
  L05 = @{
    prefix = "l05"
    page   = Join-Path $root "docs\l05.html"
    detect = "l05_v(\d+)\.jsdos"
    files  = @(
      @{ p = "LESSONS\L05\TURN.ASM";      n = "TURN.ASM" },
      @{ p = "LESSONS\L05\SINT.INC";      n = "SINT.INC" },
      @{ p = "LESSONS\L05\MKSIN.C";       n = "MKSIN.C" },
      @{ p = "LESSONS\L05\WEB\MAKE.BAT";  n = "MAKE.BAT" },
      @{ p = "LESSONS\L05\WEB\RUN.BAT";   n = "RUN.BAT" },
      @{ p = "LESSONS\L05\WEB\HELP.BAT";  n = "HELP.BAT" },
      @{ p = "LESSONS\L02\WEB\EDIT.BAT";  n = "EDIT.BAT" },
      @{ p = "TOOLS\FASM\FASM.EXE";       n = "FASM.EXE" },
      @{ p = "TOOLS\FASM\FASMD.EXE";      n = "FASMD.EXE" },
      @{ p = "TOOLS\FASM\LICENSE.TXT";    n = "LICENSE.TXT" },
      @{ p = "TOOLS\CWSDPMI\CWSDPMI.EXE"; n = "CWSDPMI.EXE" },
      @{ p = "TOOLS\CWSDPMI\cwsdpmi.doc"; n = "CWSDPMI.DOC" }
    )
    strings = @(
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`ncls`nHELP.BAT`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`ncls`nHELP.BAT`n" }
    )
  }
  # LESSON 15 - the relief, and hidden lines. The first lesson bundle that
  # carries the ENGINE, because from lesson 13 onward the lesson programs
  # are built out of the same five includes the game is. They go in a folder
  # called ENGINE and the source is shipped UNCHANGED, still saying
  # '..\..\ENGINE\E_MATH.INC' - which resolves, because DOS clamps ".." at
  # the root of a drive and the bundle is mounted as the whole of C:.
  #
  # cycles IS NOT max HERE, and that is the point of the lesson. At max the
  # frame counter is a number about this laptop. At 30000 it reads 70 and
  # 35, which are the two numbers the lesson explains, and pressing H moves
  # between them in one step.
  L21 = @{
    prefix = "l21"
    page   = Join-Path $root "docs\l21.html"
    detect = "l21_v(\d+)\.jsdos"
    files  = @(
      @{ p = "LESSONS\L21\RELIEF.ASM";    n = "RELIEF.ASM" },
      @{ p = "ENGINE\E_8086.INC";         n = "ENGINE/E_8086.INC" },
      @{ p = "ENGINE\E_MATH.INC";         n = "ENGINE/E_MATH.INC" },
      @{ p = "ENGINE\E_TERR.INC";         n = "ENGINE/E_TERR.INC" },
      @{ p = "ENGINE\E_M3D.INC";          n = "ENGINE/E_M3D.INC" },
      @{ p = "ENGINE\E_RAST.INC";         n = "ENGINE/E_RAST.INC" },
      @{ p = "LESSONS\L21\WEB\MAKE.BAT";  n = "MAKE.BAT" },
      @{ p = "LESSONS\L21\WEB\RUN.BAT";   n = "RUN.BAT" },
      # NOT HELP.BAT. DOSBox has an internal HELP and an internal command
      # beats a batch file of the same name, extension typed or not, CALL
      # or not - so a bundle that greets with HELP.BAT greets with DOSBox's
      # own command list instead. Lesson 5's bundle still does. Measured
      # 2026-09-25, in real DOSBox, both ways round.
      @{ p = "LESSONS\L21\WEB\LESSON.BAT"; n = "LESSON.BAT" },
      @{ p = "LESSONS\L02\WEB\EDIT.BAT";  n = "EDIT.BAT" },
      @{ p = "TOOLS\FASM\FASM.EXE";       n = "FASM.EXE" },
      @{ p = "TOOLS\FASM\FASMD.EXE";      n = "FASMD.EXE" },
      @{ p = "TOOLS\FASM\LICENSE.TXT";    n = "LICENSE.TXT" },
      @{ p = "TOOLS\CWSDPMI\CWSDPMI.EXE"; n = "CWSDPMI.EXE" },
      @{ p = "TOOLS\CWSDPMI\cwsdpmi.doc"; n = "CWSDPMI.DOC" }
    )
    strings = @(
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=30000`n[autoexec]`necho off`nmount c .`nc:`ncls`nLESSON.BAT`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=30000`n[autoexec]`necho off`nmount c .`nc:`ncls`nLESSON.BAT`n" }
    )
  }
  # OWL NIGHT, the LAB game, on the unlisted page: the story engine and the
  # whole NIGHT story - every SCENE.INI and every product beside it. The
  # story is a TREE, not a list of files, so it comes in through `trees`:
  # a folder walked for the extensions named, `frames\` and the recipes'
  # logs left behind. The bundle is large (the clips are a megabyte a
  # second) and GitHub refuses a file over 100 MB, so the script says the
  # size out loud and stops rather than commit a bundle Pages cannot serve.
  # The story is made in TWO editions - 640x400 through VESA and 320x200
  # through mode 13h - and the two together are over GitHub's 100 MB, so
  # each is its own bundle and the page offers the choice before the
  # machine starts. Each bundle's STORY.INI is patched to list only the
  # edition it carries, so the engine does not ask again. The 320x200
  # products live in a 320\ folder inside each scene; SCENE.INI and the
  # music are shared and go into both.
  OWLVID = @{
    prefix = "owlvid"
    page   = Join-Path $root "docs\owlvid.html"
    detect = "owlvid_v(\d+)\.jsdos"
    files  = @(
      @{ p = "LAB\OWLFLY4\ENGINE\STORY.COM"; n = "ENGINE/STORY.COM" }
    )
    trees  = @(
      @{ p = "LAB\OWLFLY4\STORY\NIGHT"; n = "STORY/NIGHT"; ext = @('.INI', '.OWV', '.SPR', '.SLT', '.PCM'); skip = @('frames', '320') }
    )
    patch  = @(
      @{ p = "LAB\OWLFLY4\STORY\NIGHT\STORY.INI"; n = "STORY/NIGHT/STORY.INI"; find = '(?m)^SCREENS\s*=[^\r\n]*'; put = 'SCREENS  = 640x400' }
    )
    # the clips ride outside the bundle; the room, the music and every INI
    # stay inside it, because the machine cannot start without them
    # DORMANT, and the reason is worth keeping. Uncomment these four and the
    # STREAM.ON line below and the clips come OUT of the bundle, into
    # docs\owlnight\ with a JSON list, for the page to fetch and write into
    # the running machine with ci.fsWriteFile. Every part of that works
    # except the last one: the write lands in the emulator's file system -
    # ci.fsTree() shows the whole 3.8 MB clip at the right path - and DOS
    # cannot see it. DOSBox caches the directory of a mounted drive, and
    # neither a NEW file nor new CONTENT in an old one reaches a machine
    # that has already booted. Proved by making the engine print the four
    # bytes it read: "WAIT", the placeholder, with the real clip sitting in
    # the file system underneath it.
    #
    # So streaming needs one of: a js-dos whose fsWriteFile invalidates that
    # cache, or a feed that does not go through the file system at all
    # (IPX, which this project already has a relay for). Until then the
    # clips travel in the bundle, and the bundle has to fit.
    # loose    = '\.OWV$'
    # looseNot = '/PICKUP/'
    # dist     = "docs\owlnight"
    # storyIni = "LAB\OWLFLY4\STORY\NIGHT\STORY.INI"
    ignore = @()
    limit  = 100MB
    strings = @(
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[sblaster]`nsbtype=sb16`n[autoexec]`necho off`nmount c .`nc:`ncd ENGINE`n:again`nSTORY`necho.`necho Press a key to play it again.`npause`ngoto again`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[sblaster]`nsbtype=sb16`n[autoexec]`necho off`nmount c .`nc:`ncd ENGINE`n:again`nSTORY`necho.`necho Press a key to play it again.`npause`ngoto again`n" }
      # the engine looks for this: with it here a product that is not
      # there is one that has not landed yet, and it waits instead of
      # saying MISSING
      # dormant with the loose-clip feature above
    )
  }
  OWLVID320 = @{
    prefix = "owlvid320"
    page   = Join-Path $root "docs\owlvid.html"
    detect = "owlvid320_v(\d+)\.jsdos"
    files  = @(
      @{ p = "LAB\OWLFLY4\ENGINE\STORY.COM"; n = "ENGINE/STORY.COM" }
    )
    trees  = @(
      # the shared text and music from the scenes themselves...
      @{ p = "LAB\OWLFLY4\STORY\NIGHT"; n = "STORY/NIGHT"; ext = @('.INI', '.PCM'); skip = @('frames', '320') },
      # ...and the pictures only from the 320\ folders
      @{ p = "LAB\OWLFLY4\STORY\NIGHT"; n = "STORY/NIGHT"; ext = @('.INI', '.OWV', '.SPR', '.SLT'); skip = @('frames'); only = '\\320\\' }
    )
    patch  = @(
      @{ p = "LAB\OWLFLY4\STORY\NIGHT\STORY.INI"; n = "STORY/NIGHT/STORY.INI"; find = '(?m)^SCREENS\s*=[^\r\n]*'; put = 'SCREENS  = 320x200' }
    )
    # DORMANT, and the reason is worth keeping. Uncomment these four and the
    # STREAM.ON line below and the clips come OUT of the bundle, into
    # docs\owlnight\ with a JSON list, for the page to fetch and write into
    # the running machine with ci.fsWriteFile. Every part of that works
    # except the last one: the write lands in the emulator's file system -
    # ci.fsTree() shows the whole 3.8 MB clip at the right path - and DOS
    # cannot see it. DOSBox caches the directory of a mounted drive, and
    # neither a NEW file nor new CONTENT in an old one reaches a machine
    # that has already booted. Proved by making the engine print the four
    # bytes it read: "WAIT", the placeholder, with the real clip sitting in
    # the file system underneath it.
    #
    # So streaming needs one of: a js-dos whose fsWriteFile invalidates that
    # cache, or a feed that does not go through the file system at all
    # (IPX, which this project already has a relay for). Until then the
    # clips travel in the bundle, and the bundle has to fit.
    # loose    = '\.OWV$'
    # looseNot = '/PICKUP/'
    # dist     = "docs\owlnight"
    # storyIni = "LAB\OWLFLY4\STORY\NIGHT\STORY.INI"
    ignore = @()
    limit  = 100MB
    strings = @(
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[sblaster]`nsbtype=sb16`n[autoexec]`necho off`nmount c .`nc:`ncd ENGINE`n:again`nSTORY`necho.`necho Press a key to play it again.`npause`ngoto again`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`nmemsize=16`n[cpu]`ncore=auto`ncycles=max`n[sblaster]`nsbtype=sb16`n[autoexec]`necho off`nmount c .`nc:`ncd ENGINE`n:again`nSTORY`necho.`necho Press a key to play it again.`npause`ngoto again`n" }
      # the engine looks for this: with it here a product that is not
      # there is one that has not landed yet, and it waits instead of
      # saying MISSING
      # dormant with the loose-clip feature above
    )
  }
  WIRECITY = @{
    prefix = "wirecity"
    page   = Join-Path $root "docs\play.html"
    detect = "wirecity_v(\d+)\.jsdos"
    files  = @(
      @{ p = "GAMES\WIRECITY\CITY.COM"; n = "CITY.COM" }
    )
    strings = @(
      @{ n = ".jsdos/dosbox.conf"; c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`ncity`n" },
      @{ n = "dosbox.conf";        c = "[sdl]`nautolock=false`n[dosbox]`nmachine=svga_s3`n[cpu]`ncore=auto`ncycles=max`n[autoexec]`necho off`nmount c .`nc:`ncity`n" }
    )
  }
}
if (-not $MAP.ContainsKey($Game)) { throw "Unknown game '$Game' - see the map in pack.ps1" }
$g = $MAP[$Game]

foreach ($f in $g.files) {
  $full = Join-Path $root $f.p
  if (-not (Test-Path $full)) { throw "$($f.p) not found - build it first (MAKE.BAT $Game)" }
}

# a tree becomes files: walked now, so that everything below sees one list.
# `skip` names folders left out anywhere on the path, `only` a regex the
# path must match; a file named by a `patch` entry is left to the patch.
$patched = @()
if ($g.ContainsKey('patch')) { $patched = $g.patch | ForEach-Object { $_.n } }
if ($g.ContainsKey('trees')) {
  $g.files = @($g.files)
  $seen = @{}
  foreach ($t in $g.trees) {
    $base = Join-Path $root $t.p
    if (-not (Test-Path $base)) { throw "$($t.p) not found" }
    Get-ChildItem $base -File -Recurse | Where-Object {
      $f = $_
      $f.Extension.ToUpper() -in $t.ext -and
      -not ($t.skip | Where-Object { $_ -and $f.FullName -match "\\$_\\" }) -and
      (-not $t.ContainsKey('only') -or $f.FullName -match $t.only)
    } | Sort-Object FullName | ForEach-Object {
      $rel = $_.FullName.Substring($base.Length + 1) -replace '\\', '/'
      $n = "$($t.n)/$rel"
      if ($patched -contains $n -or $seen.ContainsKey($n)) { return }
      $seen[$n] = $true
      $g.files += @{ p = $_.FullName.Substring($root.Length + 1); n = $n }
    }
  }
}
# a patched file: read, one regex replaced, and put in as a string entry
if ($g.ContainsKey('patch')) {
  $g.strings = @($g.strings)
  foreach ($pt in $g.patch) {
    $src = Join-Path $root $pt.p
    if (-not (Test-Path $src)) { throw "$($pt.p) not found" }
    $text = [System.IO.File]::ReadAllText($src)
    if ($text -match $pt.find) { $text = [regex]::Replace($text, $pt.find, $pt.put) }
    else {
      # the line is not there (a desk built before it knew the key rewrote
      # the file without it): the bundle still needs it, so it is added
      Write-Warning "$($pt.p) has no line matching $($pt.find) - adding '$($pt.put)' to the bundle's copy"
      $text = $text.TrimEnd("`r", "`n") + "`r`n" + $pt.put + "`r`n"
    }
    $g.strings += @{ n = $pt.n; c = $text }
  }
}

# ...and now the other direction, which is the one that actually bites. The
# list above is hand-written, so a NEW data file is not left out loudly - it
# is left out SILENTLY: the local build has it, the browser build does not,
# and nothing fails anywhere. SFX.DAT shipped exactly that way, and the game
# was right to carry on without it (no bank, no effects, engine note
# unchanged), which is what made it invisible. This warns instead.
$listed = $g.files | ForEach-Object { Split-Path $_.p -Leaf }
$dirs   = $g.files | ForEach-Object { Split-Path (Join-Path $root $_.p) -Parent } |
          Sort-Object -Unique
foreach ($d in $dirs) {
  Get-ChildItem $d -File | Where-Object { $_.Extension -in '.DAT', '.RAW' } |
    ForEach-Object {
      if ($listed -notcontains $_.Name -and $g.ignore -notcontains $_.Name) {
        Write-Warning "$($_.Name) is in $d but NOT in the bundle - deliberate?"
      }
    }
}

# ---- the clips do not travel in the bundle ---------------------------------
#
# A story of half-hour clips is a hundred megabytes, and a browser will not
# hold anyone at a progress bar for that long - nor will GitHub take a file
# that size. So `loose` names the entries that come OUT of the zip: they are
# copied, unchanged, into `dist` (a folder git ignores) and listed in a JSON
# beside them, in the order the scenes play. The page reads that list and
# writes each file into the running machine while the player is still in the
# room ahead of it; the engine waits for whatever has not landed yet, which
# is what STREAM.ON in the bundle tells it to do.
#
# The order is the story's: ORDER in STORY.INI, then the file's own name, so
# what is wanted first is fetched first.
if ($g.ContainsKey('loose')) {
  $distDir = Join-Path $root $g.dist
  New-Item -ItemType Directory -Force $distDir | Out-Null
  # Clear only what THIS edition put here last time, from its own list: the
  # two editions share the folder, and a blanket wipe had the 320 pack
  # deleting the 640 pack's clips a minute after it wrote them.
  $listPath = Join-Path $distDir "$($g.prefix)_clips.json"
  if (Test-Path $listPath) {
    foreach ($old in (Get-Content $listPath -Raw | ConvertFrom-Json)) {
      Remove-Item (Join-Path $distDir $old.file) -Force -ErrorAction SilentlyContinue
    }
    Remove-Item $listPath -Force -ErrorAction SilentlyContinue
  }

  $order = @()
  $storyIni = Join-Path $root $g.storyIni
  if (Test-Path $storyIni) {
    $m2 = [regex]::Match([IO.File]::ReadAllText($storyIni), '(?m)^ORDER\s*=\s*([^\r\n]*)')
    if ($m2.Success) { $order = $m2.Groups[1].Value -split '\s+' | Where-Object { $_ } }
  }
  function SceneRank($n) {
    $parts = $n -split '/'
    for ($i = 0; $i -lt $order.Count; $i++) { if ($parts -contains $order[$i]) { return $i } }
    return 9999
  }

  $keep = @(); $sent = @()
  foreach ($f in $g.files) {
    if ($f.n -notmatch $g.loose -or ($g.ContainsKey('looseNot') -and $f.n -match $g.looseNot)) { $keep += $f; continue }
    $sent += $f
  }
  $g.files = $keep
  $sent = $sent | Sort-Object @{ e = { SceneRank $_.n } }, @{ e = { $_.n } }

  $list = @()
  $looseBytes = 0
  foreach ($f in $sent) {
    $flat = ($f.n -replace '/', '__')
    $src  = Join-Path $root $f.p
    Copy-Item $src (Join-Path $distDir $flat) -Force
    $len  = (Get-Item $src).Length
    $looseBytes += $len
    # a PSCustomObject, not a hashtable: ConvertTo-Json keeps the order of
    # the properties either way, and this one can also be measured
    $list += [pscustomobject]@{ into = $f.n; file = $flat; bytes = $len }
  }
  # ...and a PLACEHOLDER for each goes INTO the bundle, at the name the
  # clip will have. DOS caches the directory of a mounted drive: a file
  # written from outside after the machine booted is not there as far as
  # DOS is concerned, however plainly it sits in the file system. A file
  # whose directory entry was there at boot reads back its new content,
  # though - so the entry must exist from the start, and the engine tells
  # a waiting placeholder from an arrived clip by its first four bytes.
  $g.strings = @($g.strings)
  foreach ($f in $sent) { $g.strings += @{ n = $f.n; c = "WAIT" } }

  $json = Join-Path $distDir "$($g.prefix)_clips.json"
  [IO.File]::WriteAllText($json, (ConvertTo-Json @($list) -Compress), [Text.Encoding]::ASCII)
  Write-Host ("  loose     {0} clip(s), {1:N1} MB, into {2}\ (not in the bundle, not in git)" -f $list.Count, ($looseBytes / 1MB), $g.dist)
}

# next version = the one referenced in the player page + 1
$s = Get-Content $g.page -Raw
$m = [regex]::Match($s, $g.detect)
if ($m.Success) { $n = [int]$m.Groups[1].Value + 1 } else { $n = 1 }
$name = "$($g.prefix)_v$n.jsdos"
$out  = Join-Path $root "docs\$name"

if (Test-Path $out) { Remove-Item -Force $out }
$fs  = [System.IO.File]::Open($out, [System.IO.FileMode]::CreateNew)
$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
# Every folder on the way to a file gets an entry of its own, parents
# first. js-dos's unzip makes ONE level of folder from a file's path and no
# more: a file two folders deep came out as "STORY/NIGHT/END_FLY: No such
# file or directory" and the machine never booted. (.jsdos/dosbox.conf is
# one level deep, which is why the flat games never met this.)
$dirs = @{}
foreach ($f in @($g.files) + @($g.strings)) {
  $parts = $f.n -split '/'
  for ($i = 1; $i -lt $parts.Length; $i++) { $dirs[(($parts[0..($i - 1)]) -join '/') + '/'] = $true }
}
foreach ($d in $dirs.Keys | Sort-Object { ($_ -split '/').Length }, { $_ }) { [void]$zip.CreateEntry($d) }
foreach ($f in $g.files) {
  $entry  = $zip.CreateEntry($f.n, [System.IO.Compression.CompressionLevel]::Optimal)
  $stream = $entry.Open()
  $bytes  = [System.IO.File]::ReadAllBytes((Join-Path $root $f.p))
  $stream.Write($bytes, 0, $bytes.Length)
  $stream.Close()
}
foreach ($e in $g.strings) {
  $entry  = $zip.CreateEntry($e.n, [System.IO.Compression.CompressionLevel]::Optimal)
  $stream = $entry.Open()
  $bytes  = [System.Text.Encoding]::ASCII.GetBytes($e.c)
  $stream.Write($bytes, 0, $bytes.Length)
  $stream.Close()
}
$zip.Dispose()
$fs.Close()

# a bundle GitHub will not take is not a release: stop before the page is
# touched, and leave the older bundle in place
if ($g.ContainsKey('limit')) {
  $len = (Get-Item $out).Length
  Write-Host ("  bundle    {0:N1} MB" -f ($len / 1MB))
  if ($len -gt $g.limit) {
    Remove-Item -Force $out
    throw ("docs/$name would be {0:N1} MB and GitHub refuses files over {1:N0} MB - leave a clip out of the story (a missing product plays as MISSING, any key moves on)" -f ($len / 1MB), ($g.limit / 1MB))
  }
}

# retire this game's older bundles (incl. the legacy city_v* for OWLFLY)
Get-ChildItem (Join-Path $root "docs") -Filter "$($g.prefix)_v*.jsdos" |
    Where-Object { $_.Name -ne $name } | Remove-Item -Force
if ($Game -eq "OWLFLY") {
  Get-ChildItem (Join-Path $root "docs") -Filter "city_v*.jsdos" | Remove-Item -Force
}

# point the player page at the new bundle
$s = [regex]::Replace($s, $g.detect, $name)
Set-Content -Encoding ascii $g.page $s
Write-Host "Created docs/$name and updated $(Split-Path $g.page -Leaf)"
# say WHAT went in, with the hour it was built: a bundle is only ever as
# fresh as the binary inside it, and a stale one looks exactly like a
# good one from the outside (the lesson of 2026-07-28)
foreach ($f in $g.files) {
  $fi = Get-Item (Join-Path $root $f.p)
  Write-Host ("  {0,-14} {1,8:N0} bytes  built {2:yyyy-MM-dd HH:mm}" -f $f.n, $fi.Length, $fi.LastWriteTime)
}
