param([switch]$Editor)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path $env:LOCALAPPDATA 'Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $enginePath)) {
    throw 'Godot 4.7.2 is not installed. See docs/environment.md.'
}
$engineArgs = @('--path', ('"' + $projectRoot + '"'))
if ($Editor) { $engineArgs += '--editor' }
# This entry point opens the interactive game/editor window for the user.
Start-Process -FilePath $enginePath -ArgumentList $engineArgs -WindowStyle Normal
