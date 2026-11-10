# Comprueba la configuración de Google sin imprimir API keys ni credenciales.
param([string]$Keystore = "$env:USERPROFILE/.android/debug.keystore")
$ErrorActionPreference = 'Stop'
$configPath = Join-Path $PSScriptRoot 'android/app/google-services.json'
if (!(Test-Path -LiteralPath $configPath)) { throw 'Falta android/app/google-services.json.' }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$client = @($config.client | Where-Object {
    $_.client_info.android_client_info.package_name -eq 'com.lapticon.app'
}) | Select-Object -First 1
if (!$client) { throw 'El JSON no incluye com.lapticon.app.' }
$keytool = Get-Command keytool -ErrorAction SilentlyContinue
$keytoolPath = if ($keytool) { $keytool.Source } else { 'C:/Program Files/Java/jdk-17/bin/keytool.exe' }
if (!(Test-Path -LiteralPath $keytoolPath)) { throw 'No se encuentra keytool; configura JDK 17.' }
$certificate = & $keytoolPath '-J-Duser.language=en' -list -v -keystore $Keystore -alias androiddebugkey -storepass android -keypass android 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { throw 'No se pudo leer la firma de desarrollo.' }
$sha = [regex]::Match($certificate, 'SHA1:\s*([0-9A-F:]+)').Groups[1].Value
if (!$sha) { throw 'No se encontró la huella SHA-1.' }
$normalized = $sha.Replace(':', '').ToLowerInvariant()
$registered = @($client.oauth_client | Where-Object {
    $_.client_type -eq 1 -and $_.android_info.certificate_hash.ToLowerInvariant() -eq $normalized
}).Count -gt 0
$webClient = @($client.oauth_client | Where-Object { $_.client_type -eq 3 }).Count -gt 0
Write-Output "Proyecto: $($config.project_info.project_id)"
Write-Output 'Paquete: com.lapticon.app'
Write-Output "SHA-1 de desarrollo: $sha"
Write-Output "Firma registrada en este JSON: $registered"
Write-Output "Cliente OAuth web presente: $webClient"
if (!$registered -or !$webClient) {
    Write-Output 'En Firebase > Configuración del proyecto > app com.lapticon.app, registra esta SHA-1.'
    Write-Output 'Habilita Google en Authentication y descarga un google-services.json actualizado.'
    exit 1
}
Write-Output 'El archivo coincide con la firma local. Confirma también que Google está habilitado en Firebase.'
Write-Output 'Ejecuta flutter run --dart-define=GOOGLE_SIGN_IN_ENABLED=true y verifica el acceso real.'
