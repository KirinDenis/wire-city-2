# MKCAT.ps1 - make the kit's two catalogs from the ;@ lines of every kit file.
#
#   powershell -File KIT\MKCAT.ps1
#
# CATALOG.TXT  - what a model reads first: ONE LINE A FILE - the file, what
#                it is for, and the names of every block in it. Short.
# CATFULL.TXT  - one line a block: name, file, what it does (the ;@ line).
# A block's header line  ;@ NAME  what it does  feeds both. Regenerated,
# never edited.
$kit = $PSScriptRoot
$full = New-Object System.Collections.Generic.List[string]
$idx  = New-Object System.Collections.Generic.List[string]
$n = 0
$full.Add('KIT CATFULL - one line a block (made by MKCAT.ps1; do not edit). The short list: CATALOG.TXT.')
$idx.Add('KIT CATALOG - one line a file: what it is for, then its blocks. Made by MKCAT.ps1; do not edit.')
$idx.Add('LIB: include it after your way out, call its blocks (read only the header of the block you use).')
$idx.Add('REC: copy the fragment into your program and adapt. ART: how to draw a thing + a ready picture.')
$idx.Add('T_*: whole small games - START FROM ONE (docs guide KIT). CATFULL.TXT: every block with its line.')
function Purpose($f) {
  # the file's own "NAME - what it is" line in its top comment
  # (and the comment lines after it, to the first sentence's end)
  $lines = @(Get-Content $f.FullName -TotalCount 16)
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match ('^\s*;\s*' + [regex]::Escape($f.Name) + '\s+-\s+(.*)$')) {
      $s = ($Matches[1] -replace '^(KIT|recipe|KIT template):\s*', '').Trim()
      $j = $i + 1
      while ($s -notmatch '[.:]$' -and $j -lt $lines.Count -and $lines[$j] -match '^\s*;\s*(\S.*)$' -and $lines[$j] -notmatch '^\s*;\s*[=-]{4}') {
        $s += ' ' + $Matches[1].Trim(); $j++
      }
      $dot = $s.IndexOf('. ')
      if ($dot -gt 20) { $s = $s.Substring(0, $dot + 1) }
      return $s
    }
  }
  return ''
}
function Section($title, $files) {
  $script:full.Add(''); $script:full.Add("== $title")
  $script:idx.Add('');  $script:idx.Add("== $title")
  foreach ($f in $files) {
    $rel = $f.FullName.Substring($kit.Length + 1)
    $names = @()
    $first = ''
    foreach ($m in Select-String -Path $f.FullName -Pattern '^\s*;@\s*(\S+)\s+(.*)$') {
      $nm = $m.Matches[0].Groups[1].Value
      $script:full.Add(('{0,-14} {1,-22} {2}' -f $nm, $rel, $m.Matches[0].Groups[2].Value.Trim()))
      $names += $nm
      if (-not $first) { $first = $m.Matches[0].Groups[2].Value.Trim() }
      $script:n++
    }
    $what = Purpose $f
    if (-not $what) { $what = $first }
    if ($what.Length -gt 110) { $what = $what.Substring(0, 107) + '...' }
    $line = '{0,-20} {1}' -f $rel, $what
    if ($names.Count -gt 1) { $line += "`r`n" + (' ' * 21) + ($names -join ' ') }
    $script:idx.Add($line)
  }
}
Section 'LIB - include and call'        (Get-ChildItem (Join-Path $kit 'LIB') -Filter *.INC -ErrorAction SilentlyContinue | Sort-Object Name)
Section 'T_* - templates (start here)'  (Get-ChildItem $kit -Directory -Filter 'T_*' | Sort-Object Name | ForEach-Object { Get-ChildItem $_.FullName -Filter *.ASM })
Section 'REC - recipes to copy'         (Get-ChildItem (Join-Path $kit 'REC') -Filter *.ASM -ErrorAction SilentlyContinue | Sort-Object Name)
$full.Add(''); $full.Add('== ART - drawing recipes (KIT\ART\NAME.TXT)')
$arts = @()
foreach ($f in Get-ChildItem (Join-Path $kit 'ART') -Filter *.TXT -ErrorAction SilentlyContinue | Sort-Object Name) {
  $first = ((Get-Content $f.FullName -TotalCount 1) -replace '^\W+', '').Trim()
  $full.Add(('{0,-14} {1,-22} {2}' -f $f.BaseName, "ART\$($f.Name)", $first))
  $arts += $f.BaseName
  $n++
}
$idx.Add(''); $idx.Add('== ART - drawing recipes, KIT\ART\NAME.TXT (each: the rule + a text-art picture)')
$idx.Add(($arts -join ' '))
[IO.File]::WriteAllText((Join-Path $kit 'CATFULL.TXT'), (($full -join "`r`n") + "`r`n"))
[IO.File]::WriteAllText((Join-Path $kit 'CATALOG.TXT'), (($idx -join "`r`n") + "`r`n"))
Write-Output ("{0} blocks; CATALOG.TXT {1} bytes, CATFULL.TXT {2} bytes" -f $n,
  (Get-Item (Join-Path $kit 'CATALOG.TXT')).Length, (Get-Item (Join-Path $kit 'CATFULL.TXT')).Length)
