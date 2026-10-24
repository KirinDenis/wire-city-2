# RUNWIN.ps1 - run one kit program in DOSBox from Windows, unattended.
#
#   powershell -File KIT\RUNWIN.ps1 TEST T_MATH            # runs T_MATH.COM /AUTO
#   powershell -File KIT\RUNWIN.ps1 TEST T_MATH -Seconds 30
#
# The program gets /AUTO on its command line: a kit test given /AUTO runs its
# checks, prints PASS/FAIL lines, and quits by itself (graphics tests show
# their picture for about two seconds first). Its text goes to NAME.OUT,
# which is printed here. DOSBox runs silent. If it has not closed after
# -Seconds, THIS DOSBox (by its process id, never by name) is killed and the
# run is reported as HUNG.
param([Parameter(Mandatory)][string]$Folder, [Parameter(Mandatory)][string]$Name,
      [int]$Seconds = 20, [string]$Tail = '/AUTO')
$root = Split-Path $PSScriptRoot -Parent
$dosbox = 'dosbox.exe'
$local = Join-Path $root 'LOCAL.BAT'
if (Test-Path $local) {
  $m = Select-String -Path $local -Pattern '^set DOSBOX=(.+)$' | Select-Object -First 1
  if ($m) { $dosbox = $m.Matches[0].Groups[1].Value.Trim() }
}
$dir = Join-Path $root "KIT\$Folder"
$out = Join-Path $dir "$Name.OUT"
if (Test-Path $out) { Remove-Item $out }
if (-not (Test-Path (Join-Path $dir "$Name.COM"))) { Write-Output "NO $Folder\$Name.COM - build it first"; exit 2 }
$argv = @('-noautoexec', '-noconsole', '-set', 'mixer nosound=true', '-set', 'speaker pcspeaker=false',
          '-c', "mount c $root", '-c', 'c:', '-c', "cd KIT\$Folder", '-c', "$Name $Tail > $Name.OUT", '-c', 'exit')
# Start-Process joins its arguments with bare spaces: quote each one ourselves.
$line = ($argv | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' '
$p = Start-Process -FilePath $dosbox -ArgumentList $line -PassThru
if (-not $p.WaitForExit($Seconds * 1000)) {
  Stop-Process -Id $p.Id -Force
  Write-Output "HUNG: $Folder\$Name did not quit in $Seconds s (DOSBox $($p.Id) killed)"
  if (Test-Path $out) { Get-Content $out }
  exit 3
}
if (Test-Path $out) { Get-Content $out } else { Write-Output "(no output file)" }

