<#
.SYNOPSIS
    Descarga el portable de PowerCloud Remote desde GitHub Actions y lo firma con el
    certificado Certum (SimplySign) instalado en este equipo.

.DESCRIPTION
    Requisitos:
      - SimplySign Desktop abierto y con sesion iniciada (codigo de la app SimplySign del celular).
        Asi el certificado aparece en Cert:\CurrentUser\My.
      - gh (GitHub CLI) con sesion iniciada, para descargar la compilacion.
      - Opcional: signtool.exe (Windows SDK). Si no esta, se usa Set-AuthenticodeSignature.

    No guarda ni pide contrasenas: la clave privada nunca sale de la nube de Certum.

.PARAMETER RunId
    Ejecucion de GitHub Actions a descargar. Por defecto, la ultima exitosa.

.PARAMETER Archivo
    Firmar un .exe que ya tengas en disco en vez de descargarlo.

.PARAMETER Certificado
    Texto a buscar en el sujeto del certificado. Por defecto se usa el certificado de firma
    de codigo de Certum vigente que venza mas tarde (Standard Code Signing in the Cloud).

.EXAMPLE
    .\firmar.ps1
.EXAMPLE
    .\firmar.ps1 -Archivo .\PowerCloudRemote-1.5.1-x64.exe
#>
[CmdletBinding()]
param(
    [string]$RunId,
    [string]$Archivo,
    [string]$Certificado = "",
    [string]$Repo = "vidalramospw/powercloud-remote",
    [string]$Salida = (Join-Path $PSScriptRoot "..\firmados"),
    [string]$Timestamp = "http://time.certum.pl"
)

$ErrorActionPreference = "Stop"
function Paso($t) { Write-Host "`n==> $t" -ForegroundColor Cyan }

# 1. Certificado
Paso "Buscando certificado de firma de codigo de Certum"
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
    Where-Object { $_.Issuer -like "*Certum*" -and $_.Subject -like "*$Certificado*" -and $_.NotAfter -gt (Get-Date) } |
    Sort-Object NotAfter -Descending | Select-Object -First 1
if (-not $cert) {
    throw "No se encontro el certificado. Abra SimplySign Desktop, inicie sesion con el codigo de la app y vuelva a intentar."
}
Write-Host "    $($cert.Subject)"
Write-Host "    Vence: $($cert.NotAfter.ToString('yyyy-MM-dd'))  Huella: $($cert.Thumbprint)"

# 2. Archivo a firmar
New-Item -ItemType Directory -Force -Path $Salida | Out-Null
$Salida = (Resolve-Path $Salida).Path
if (-not $Archivo) {
    Paso "Descargando el portable desde GitHub Actions"
    if (-not $RunId) {
        $RunId = gh run list -R $Repo --workflow powercloud-windows.yml --status success --limit 1 --json databaseId --jq '.[0].databaseId'
        if (-not $RunId) { throw "No hay compilaciones exitosas en $Repo." }
    }
    Write-Host "    Ejecucion: $RunId"
    $tmp = Join-Path $env:TEMP ("pcr-" + [guid]::NewGuid().ToString("N"))
    gh run download $RunId -R $Repo -n powercloud-remote-windows-x64-portable -D $tmp
    if ($LASTEXITCODE -ne 0) { throw "No se pudo descargar el artefacto." }
    $origen = Get-ChildItem $tmp -Filter *.exe | Select-Object -First 1
    if (-not $origen) { throw "El artefacto no contiene un .exe." }
    $Archivo = Join-Path $Salida $origen.Name
    Copy-Item $origen.FullName $Archivo -Force
    Remove-Item $tmp -Recurse -Force
} else {
    $copia = Join-Path $Salida (Split-Path $Archivo -Leaf)
    if ((Resolve-Path $Archivo).Path -ne $copia) { Copy-Item $Archivo $copia -Force }
    $Archivo = $copia
}
Write-Host "    $Archivo"

# 3. Firmar
Paso "Firmando (SHA-256 + sello de tiempo $Timestamp)"
$signtool = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe" -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending | Select-Object -First 1
if ($signtool) {
    Write-Host "    Usando $($signtool.FullName)"
    & $signtool.FullName sign /sha1 $cert.Thumbprint /fd sha256 /tr $Timestamp /td sha256 /v $Archivo
    if ($LASTEXITCODE -ne 0) { throw "signtool fallo (codigo $LASTEXITCODE)." }
} else {
    Write-Host "    signtool no instalado: usando Set-AuthenticodeSignature"
    $r = Set-AuthenticodeSignature -FilePath $Archivo -Certificate $cert -HashAlgorithm SHA256 -TimestampServer $Timestamp
    if ($r.Status -ne "Valid") { throw "La firma fallo: $($r.Status) $($r.StatusMessage)" }
}

# 4. Verificar
Paso "Verificando"
$sig = Get-AuthenticodeSignature $Archivo
if ($sig.Status -ne "Valid") { throw "Firma no valida: $($sig.Status) $($sig.StatusMessage)" }
$hash = (Get-FileHash $Archivo -Algorithm SHA256).Hash
Write-Host "    Estado:    $($sig.Status)" -ForegroundColor Green
Write-Host "    Firmante:  $($sig.SignerCertificate.Subject)"
Write-Host "    Sello:     $(if ($sig.TimeStamperCertificate) { $sig.TimeStamperCertificate.Subject } else { 'SIN SELLO DE TIEMPO' })"
Write-Host "    SHA256:    $hash"
"$hash  $(Split-Path $Archivo -Leaf)" | Set-Content "$Archivo.sha256" -Encoding ASCII
Write-Host "`nListo: $Archivo" -ForegroundColor Green
