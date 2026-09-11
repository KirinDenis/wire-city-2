@echo off
REM ============================================================================
REM RUN.BAT - play a story, from inside DOS.
REM
REM   cd LAB\OWLFLY4\ENGINE
REM   RUN                           plays ..\STORY\NIGHT
REM   RUN ..\STORY\OTHER            plays that one
REM   RUN ..\STORY\NIGHT /AUTO      plays itself and writes SHOTnn.OWV
REM   RUN ..\STORY\NIGHT /AUTO EXIT the same, then closes DOSBox
REM   RUN ..\STORY\NIGHT EXIT       plays it by hand, then closes DOSBox
REM
REM WHY THE EXIT ARGUMENT EXISTS. A batch file started from a DOSBox -c line
REM SWALLOWS every -c line that follows it, so RUNWIN's closing -c "exit"
REM never runs and the emulator sits at a prompt forever afterwards. Typed by
REM hand, RUN leaves you where you were; driven from Windows, it has to close
REM itself.
REM
REM EXIT is for this batch and must NOT reach STORY.COM: the first version
REM passed every argument through, the engine took "EXIT" as part of the
REM story path, found nothing there, and the emulator closed before anyone
REM could read why.
REM ============================================================================
REM Two switches can ride along - /AUTO and /320 or /640 - so EXIT may be
REM the second, third or fourth word.
if not exist STORY.COM goto nostory
if "%1"=="" goto plain
if "%2"=="EXIT" goto dironly
if "%3"=="EXIT" goto oneswitch
STORY.COM %1 %2 %3
goto done
:oneswitch
STORY.COM %1 %2
goto done
:dironly
STORY.COM %1
goto done
:plain
STORY.COM
goto done

:nostory
echo.
echo STORY.COM is not built. Type MAKE first.

:done
if "%2"=="EXIT" exit
if "%3"=="EXIT" exit
if "%4"=="EXIT" exit
