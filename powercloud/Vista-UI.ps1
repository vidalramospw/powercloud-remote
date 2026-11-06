<#
.SYNOPSIS
    Vista previa rapida de la interfaz (solo Flutter) para revisar cambios de UI con capturas.

.DESCRIPTION
    No compila Rust: toma librustdesk.dll y el bridge de la ultima compilacion exitosa de GitHub
    y compila solo la parte Flutter con los commits locales (aunque no esten subidos).
    Sirve mientras el cambio sea solo de interfaz (Dart); si cambia Rust hay que usar el CI
    o Compilar-Local.ps1.

    Resultado: D:\pcbuild\vista\PowerCloudRemote.exe
#>
[CmdletBinding()]
param(
    [string]$Base = "D:\pcbuild",
    [string]$RepoLocal = "E:\MonitoreoDE\powercloud-remote",
    [switch]$ActualizarRust
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$inicio = Get-Date
function Paso($t) { Write-Host "==> $t  [$((Get-Date) - $inicio | ForEach-Object { '{0:mm\:ss}' -f $_ })]" }
function Ejecutar($exe, [string[]]$argumentos) {
    & $exe @argumentos
    if ($LASTEXITCODE -ne 0) { throw "Fallo: $exe $($argumentos -join ' ') (codigo $LASTEXITCODE)" }
}

$src = Join-Path $Base "src"
$vista = Join-Path $Base "vista"
$repoGh = "vidalramospw/powercloud-remote"

Paso "Entorno"
$env:FLUTTER_SUPPRESS_ANALYTICS = "true"
$env:PUB_CACHE = "$Base\pub-cache"
$vcvars = "$Base\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
cmd /c "`"$vcvars`" >nul && set" | ForEach-Object { if ($_ -match '^([^=]+)=(.*)$') { Set-Item "env:$($Matches[1])" $Matches[2] } }
$env:PATH = "$Base\flutter\bin;$env:PATH"

$marcaFlutter = "$Base\flutter\.powercloud-listo"
if (-not (Test-Path $marcaFlutter)) {
    Paso "Flutter: precache y motor de RustDesk (una sola vez)"
    & flutter config --no-analytics | Out-Null
    Ejecutar flutter @("precache", "--windows")
    New-Item -ItemType Directory -Force -Path "$Base\descargas" | Out-Null
    $zip = "$Base\descargas\rustdesk-engine-windows-x64-release.zip"
    if (-not (Test-Path $zip)) { Ejecutar curl.exe @("-sSL", "--retry", "3", "-o", $zip, "https://github.com/rustdesk/engine/releases/download/main/windows-x64-release.zip") }
    $tmp = "$Base\descargas\engine-x64"
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Expand-Archive $zip -DestinationPath $tmp -Force
    Copy-Item "$tmp\*" "$Base\flutter\bin\cache\artifacts\engine\windows-x64-release\" -Recurse -Force
    Remove-Item $tmp -Recurse -Force
    $parche = "$src\.github\patches\flutter_3.24.4_dropdown_menu_enableFilter.diff"
    Push-Location "$Base\flutter"
    try {
        & git apply --check $parche 2>$null
        if ($LASTEXITCODE -eq 0) { Ejecutar git @("apply", $parche) }
    } finally { Pop-Location }
    Set-Content $marcaFlutter (Get-Date -Format o)
}

Paso "Codigo local"
Push-Location $src
try {
    Ejecutar git @("fetch", "-q", $RepoLocal, "powercloud")
    Ejecutar git @("reset", "-q", "--hard", "FETCH_HEAD")
    Ejecutar git @("clean", "-q", "-fd")
    # Cambios sin commit del repo local (para iterar sin hacer commit en cada prueba).
    $parche = Join-Path $env:TEMP "pc-vista.diff"
    Ejecutar git @("-C", $RepoLocal, "diff", "HEAD", "--binary", "--output=$parche")
    $diff = (Get-Item $parche).Length -gt 0
    if ($diff) {
        Ejecutar git @("apply", "--whitespace=nowarn", $parche)
    }
    # Archivos nuevos sin commit en flutter\lib
    Push-Location $RepoLocal
    $nuevos = & git ls-files --others --exclude-standard flutter powercloud
    Pop-Location
    foreach ($n in $nuevos) {
        $destino = Join-Path $src $n
        New-Item -ItemType Directory -Force -Path (Split-Path $destino) | Out-Null
        Copy-Item (Join-Path $RepoLocal $n) $destino -Force
    }
    Write-Host "    $(& git log -1 --format='%h %s') (+ cambios sin commit: $([bool]$diff))"

    $dll = "target\release\librustdesk.dll"
    if ($ActualizarRust -or -not (Test-Path $dll) -or -not (Test-Path "flutter\lib\generated_bridge.dart")) {
        Paso "Rust (librustdesk.dll + bridge) de la ultima compilacion exitosa"
        $run = & gh run list -R $repoGh --workflow powercloud-windows.yml --status success --limit 1 --json databaseId --jq ".[0].databaseId"
        foreach ($b in "src\bridge_generated.rs", "src\bridge_generated.io.rs", "flutter\lib\generated_bridge.dart", "flutter\lib\generated_bridge.freezed.dart", "flutter\macos\Runner\bridge_generated.h", "flutter\ios\Runner\bridge_generated.h") {
            if (Test-Path $b) { Remove-Item $b -Force }
        }
        Ejecutar gh @("run", "download", $run, "-R", $repoGh, "-n", "bridge-artifact", "-D", ".")
        $tmp = Join-Path $Base "descargas\carpeta"
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        Ejecutar gh @("run", "download", $run, "-R", $repoGh, "-n", "powercloud-remote-windows-x64-carpeta", "-D", $tmp)
        New-Item -ItemType Directory -Force -Path "target\release" | Out-Null
        $origenDll = Get-ChildItem $tmp -Recurse -Filter librustdesk.dll | Select-Object -First 1
        Copy-Item $origenDll.FullName $dll -Force
    }

    Paso "Marca PowerCloud"
    $env:PC_BUILD = "0"
    Ejecutar python @("powercloud\aplicar_marca.py")

    Paso "Flutter build windows"
    Push-Location flutter
    try {
        Ejecutar flutter @("build", "windows", "--release")
    } finally { Pop-Location }

    Paso "Copiando a $vista"
    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$vista\*" } | Stop-Process -Force
    Start-Sleep 1
    if (Test-Path $vista) { Remove-Item $vista -Recurse -Force }
    Copy-Item "flutter\build\windows\x64\runner\Release" $vista -Recurse
    Get-ChildItem $vista -Filter *.exe | Select-Object -First 3 | ForEach-Object { Write-Host "    $($_.FullName)" }
} finally { Pop-Location }
Paso "Listo"
