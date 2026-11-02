# Invoca el SDK instalado directamente; evita problemas del wrapper flutter.bat.
$ErrorActionPreference = 'Stop'
$flutterCommand = Get-Command flutter -ErrorAction Stop
$flutterDirectory = Split-Path (Split-Path $flutterCommand.Source -Parent) -Parent
$dartExecutable = Join-Path $flutterDirectory 'bin\cache\dart-sdk\bin\dart.exe'
$flutterTools = Join-Path $flutterDirectory 'bin\cache\flutter_tools.snapshot'
if (!(Test-Path -LiteralPath $dartExecutable) -or !(Test-Path -LiteralPath $flutterTools)) {
    throw 'No se encuentra el SDK completo. Ejecuta flutter doctor y vuelve a intentarlo.'
}
Push-Location $PSScriptRoot
try {
    & $dartExecutable $flutterTools @args
    $toolExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $toolExitCode
