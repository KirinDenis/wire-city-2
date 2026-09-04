@echo off
REM ============================================================================
REM RUN.BAT - the video workbench, from inside DOS.
REM
REM   cd LAB\OWLFLY4\VIDEO
REM   RUN                       play TEST2.OWV
REM   RUN PLAYER SOME.OWV       play that one instead
REM   RUN VESATEST              ask what this machine grants
REM
REM   RUN PLAYER X.OWV EXIT     play it, then close DOSBox
REM
REM WHY THE EXIT ARGUMENT EXISTS. A batch file started from a DOSBox -c line
REM SWALLOWS every -c line that follows it, so RUNWIN's closing -c "exit"
REM never runs and the emulator sits at a prompt forever afterwards. Typed by
REM hand, RUN leaves you where you were; driven from Windows, it has to close
REM itself.
REM
REM This is the same trap MAKE.BAT documents, and it is worth stating twice:
REM a run whose end is never defined cannot be timed. An afternoon went into
REM stopwatch figures that were, every one of them, measuring an idle
REM emulator waiting at a prompt.
REM
REM VESATEST asks this machine three questions and prints the answers: is
REM there a 386, what does VESA offer for mode 100h, does the banked window
REM work, and does unreal mode work. The last one decided how PLAYER is built.
REM ============================================================================
if "%1"=="" goto player
if "%1"=="PLAYER" goto player
if "%1"=="VESATEST" goto vesatest
echo Unknown program: %1
goto end

:player
if not exist PLAYER.COM goto noplayer
PLAYER.COM %2
goto done

:vesatest
if not exist VESATEST.COM goto novesa
VESATEST.COM
goto done

REM These go to :done, not :end. A path that skips the EXIT check leaves
REM DOSBox sitting open on a machine that was driven from Windows - which is
REM exactly the failure that made a build error look like an 84-second run.
:noplayer
echo.
echo PLAYER.COM is not built. Type MAKE first.
goto done

:novesa
echo.
echo VESATEST.COM is not built. Type MAKE first.
goto done

:done
if "%3"=="EXIT" exit
:end
