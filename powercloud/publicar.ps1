<#
.SYNOPSIS
    Sube una version de PowerCloud Remote al portal de descargas de PowerCloud.

.DESCRIPTION
    Flujo completo:  compilar (GitHub Actions)  ->  .\firmar.ps1  ->  .\publicar.ps1
    Clientes descargan desde https://monitoreo.powercloud.com.sv:21114/descargar

    La clave de publicacion se genera en la consola (Descargas > Clave de publicacion) y se toma
    de la variable POWERCLOUD_PUBLICACION o se pide por teclado (oculta). No usa contrasenas.
    Por seguridad, se niega a subir un archivo sin firma valida salvo que se indique -PermitirSinFirma.

.PARAMETER Archivo
    El .exe a subir. Por defecto, el mas reciente en ..\firmados\ (lo deja ahi firmar.ps1).

.PARAMETER Version
    Version a mostrar. Por defecto se toma del nombre del archivo (ej. 1.5.1).

.PARAMETER NoPublicar
    Sube la version al historial sin ofrecerla todavia en la pagina publica.

.EXAMPLE
    .\firmar.ps1; .\publicar.ps1 -Notas "Alias nombre@dominio y servidor API por HTTPS"
#>
[CmdletBinding()]
param(
    [string]$Archivo,
    [string]$Version,
    [string]$Notas = "",
    [string]$Servidor = "https://monitoreo.powercloud.com.sv:21114",
    [switch]$NoPublicar,
    [switch]$PermitirSinFirma
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
function Paso($t) { Write-Host "`n==> $t" -ForegroundColor Cyan }

if (-not $Archivo) {
    $Archivo = Get-ChildItem (Join-Path $PSScriptRoot "..\firmados") -Filter *.exe -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (-not $Archivo) { throw "No hay .exe en ..\firmados. Ejecute primero firmar.ps1 o indique -Archivo." }
}
$Archivo = (Resolve-Path $Archivo).Path
if (-not $Version -and ([IO.Path]::GetFileName($Archivo) -match '(\d+\.\d+\.\d+)')) { $Version = $Matches[1] }

Paso "Archivo"
$info = Get-Item $Archivo
$sig = Get-AuthenticodeSignature $Archivo
Write-Host "    $($info.Name)  ($([math]::Round($info.Length / 1MB, 1)) MB)  version: $Version"
Write-Host "    SHA256: $((Get-FileHash $Archivo -Algorithm SHA256).Hash)"
if ($sig.Status -eq "Valid") {
    Write-Host "    Firma: valida ($($sig.SignerCertificate.Subject))" -ForegroundColor Green
} elseif ($PermitirSinFirma) {
    Write-Host "    AVISO: firma '$($sig.Status)'. Se sube igual por -PermitirSinFirma." -ForegroundColor Yellow
} else {
    throw "El archivo no tiene una firma valida ($($sig.Status)). Firmelo con firmar.ps1 o use -PermitirSinFirma."
}

$clave = $env:POWERCLOUD_PUBLICACION
if (-not $clave) {
    $seguro = Read-Host "Clave de publicacion" -AsSecureString
    $clave = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($seguro))
}

Paso "Subiendo a $Servidor"
Add-Type -AssemblyName System.Net.Http
$cliente = New-Object System.Net.Http.HttpClient
$cliente.Timeout = [TimeSpan]::FromMinutes(20)
$cliente.DefaultRequestHeaders.Add("X-PowerCloud-Publicacion", $clave)
$form = New-Object System.Net.Http.MultipartFormDataContent
$flujo = [IO.File]::OpenRead($Archivo)
try {
    $contenido = New-Object System.Net.Http.StreamContent($flujo)
    $contenido.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/octet-stream")
    $form.Add($contenido, "archivo", $info.Name)
    $form.Add((New-Object System.Net.Http.StringContent($Version)), "version")
    $form.Add((New-Object System.Net.Http.StringContent($Notas)), "notas")
    $form.Add((New-Object System.Net.Http.StringContent((-not $NoPublicar).ToString().ToLower())), "actual")
    $resp = $cliente.PostAsync("$Servidor/api/portal/descargas", $form).GetAwaiter().GetResult()
    $cuerpo = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
} finally { $flujo.Dispose(); $cliente.Dispose() }

$json = $null
try { $json = $cuerpo | ConvertFrom-Json } catch { }
if (-not $resp.IsSuccessStatusCode -or ($json -and $json.error)) {
    throw "El servidor respondio $([int]$resp.StatusCode): $(if ($json.error) { $json.error } else { $cuerpo })"
}
Write-Host "    Version $($json.version) subida (firmante segun el servidor: '$($json.firmante)')." -ForegroundColor Green
if ($json.actual) { Write-Host "    Publicada: $Servidor/descargar" -ForegroundColor Green }
else { Write-Host "    Quedo en el historial sin publicar (consola > Descargas)." }
