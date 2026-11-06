<#
.SYNOPSIS
    Compila PowerCloud Remote en esta PC (mismo resultado que el flujo de GitHub, mucho mas rapido
    despues de la primera vez porque conserva la compilacion de Rust y las dependencias de vcpkg).

.DESCRIPTION
    Entorno en D:\pcbuild (lo prepara una sola vez la instalacion inicial):
      BuildTools\ (MSVC + SDK), rust\ (1.75), llvm\ (15.0.6), flutter\ (3.24.5 + motor RustDesk),
      vcpkg\ (+ installed\x64-windows-static), src\ (copia del codigo), salida\ (resultados).

    Pasos: actualizar la copia del codigo -> bridge (del ultimo CI) -> marca PowerCloud con numero
    de compilacion -> cargo + flutter -> portable autoextraible en D:\pcbuild\salida.
    Luego:  .\firmar.ps1 -Archivo <exe>   y   .\publicar.ps1 -Archivo <exe firmado>

.PARAMETER Origen
    local  = compila los commits de E:\MonitoreoDE\powercloud-remote (aunque no esten subidos).
    github = compila la rama powercloud de GitHub.

.PARAMETER Build
    Numero de compilacion (version 1.5.1.<Build>). Por defecto el siguiente del contador local,
    que arranca en 100 para no chocar con las compilaciones de GitHub.
#>
[CmdletBinding()]
param(
    [string]$Base = "D:\pcbuild",
    [ValidateSet("local", "github")][string]$Origen = "local",
    [string]$RepoLocal = "E:\MonitoreoDE\powercloud-remote",
    [int]$Build = 0,
    [switch]$ActualizarBridge
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$inicio = Get-Date
function Paso($t) { Write-Host "`n==> $t  [$((Get-Date) - $inicio | ForEach-Object { '{0:mm\:ss}' -f $_ })]" -ForegroundColor Cyan }
function Ejecutar($exe, [string[]]$argumentos) {
    & $exe @argumentos
    if ($LASTEXITCODE -ne 0) { throw "Fallo: $exe $($argumentos -join ' ') (codigo $LASTEXITCODE)" }
}

$src = Join-Path $Base "src"
$salida = Join-Path $Base "salida"
New-Item -ItemType Directory -Force -Path $salida | Out-Null

# ── entorno ──────────────────────────────────────────────────────────────
Paso "Entorno"
$env:RUSTUP_HOME = "$Base\rust\rustup"
$env:CARGO_HOME = "$Base\rust\cargo"
$env:LIBCLANG_PATH = "$Base\llvm\bin"
$env:VCPKG_ROOT = "$Base\vcpkg"
$env:VCPKG_DEFAULT_BINARY_CACHE = "$Base\vcpkg-cache"
$env:FLUTTER_SUPPRESS_ANALYTICS = "true"
$env:PUB_CACHE = "$Base\pub-cache"
$env:CARGO_TARGET_DIR = "$src\target"
$vcvars = "$Base\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if (-not (Test-Path $vcvars)) { throw "No esta $vcvars (Build Tools)." }
# Importa las variables del entorno de MSVC (cl, link, SDK) a esta sesion.
cmd /c "`"$vcvars`" >nul && set" | ForEach-Object { if ($_ -match '^([^=]+)=(.*)$') { Set-Item "env:$($Matches[1])" $Matches[2] } }
$env:PATH = "$env:CARGO_HOME\bin;$Base\llvm\bin;$Base\flutter\bin;$env:PATH"
foreach ($h in "cargo.exe", "flutter.bat", "clang.exe", "cl.exe", "git.exe", "python.exe") {
    if (-not (Get-Command $h -ErrorAction SilentlyContinue)) { throw "Falta $h en el entorno." }
}
if (-not (Test-Path "$env:VCPKG_ROOT\installed\x64-windows-static\lib")) { throw "Faltan las dependencias de vcpkg (ejecutar la instalacion inicial)." }
Write-Host "    $(& rustc --version) | $((& flutter --version 2>$null) | Select-Object -First 1)"

# ── Flutter: motor de RustDesk y parche (una sola vez) ────────────────────
$marcaFlutter = "$Base\flutter\.powercloud-listo"
if (-not (Test-Path $marcaFlutter)) {
    Paso "Flutter: precache, motor de RustDesk y parche"
    & flutter config --no-analytics | Out-Null
    Ejecutar flutter @("precache", "--windows")
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
        if ($LASTEXITCODE -eq 0) { Ejecutar git @("apply", $parche) } else { Write-Host "    parche ya aplicado" }
    } finally { Pop-Location }
    Set-Content $marcaFlutter (Get-Date -Format o)
}

# ── codigo ───────────────────────────────────────────────────────────────
Paso "Codigo ($Origen)"
Push-Location $src
try {
    if ($Origen -eq "local") {
        Ejecutar git @("fetch", "-q", $RepoLocal, "powercloud")
    } else {
        Ejecutar git @("fetch", "-q", "origin", "powercloud")
    }
    Ejecutar git @("reset", "-q", "--hard", "FETCH_HEAD")
    Ejecutar git @("submodule", "update", "--init", "--recursive", "-q")
    Ejecutar git @("submodule", "foreach", "-q", "git reset -q --hard")
    # Sin -x: conserva lo ignorado (target\, build de flutter, bridge generado).
    Ejecutar git @("clean", "-q", "-fd")
    $commit = (& git log -1 --format="%h %s")
    Write-Host "    $commit"

    # ── bridge (codigo generado en Linux por el CI) ──────────────────────
    if ($ActualizarBridge -or -not (Test-Path "src\bridge_generated.rs")) {
        Paso "Bridge desde la ultima compilacion exitosa de GitHub"
        $run = & gh run list -R vidalramospw/powercloud-remote --workflow powercloud-windows.yml --status success --limit 1 --json databaseId --jq ".[0].databaseId"
        if (-not $run) { throw "No hay compilaciones exitosas en GitHub para tomar el bridge." }
        Ejecutar gh @("run", "download", $run, "-R", "vidalramospw/powercloud-remote", "-n", "bridge-artifact", "-D", ".")
    }

    # ── numero de compilacion ────────────────────────────────────────────
    $contador = Join-Path $Base "build-number.txt"
    if ($Build -le 0) { $Build = if (Test-Path $contador) { [int](Get-Content $contador) + 1 } else { 100 } }
    $version = "1.5.1.$Build"

    Paso "Marca PowerCloud ($version)"
    $env:PC_BUILD = "$Build"
    Ejecutar python @("powercloud\aplicar_marca.py")

    Paso "Compilacion (cargo + flutter)"
    Ejecutar python @(".\build.py", "--portable", "--flutter", "--skip-portable-pack", "--hwcodec", "--vram")
    $release = "flutter\build\windows\x64\runner\Release"
    if (-not (Test-Path "$release\PowerCloudRemote.exe")) { throw "No se genero $release\PowerCloudRemote.exe" }

    Paso "Portable autoextraible"
    $carpeta = Join-Path $salida "PowerCloudRemote-$version"
    if (Test-Path $carpeta) { Remove-Item $carpeta -Recurse -Force }
    Copy-Item $release $carpeta -Recurse
    # Agente del tunel de PowerCloud Engine (programa aparte), igual que en el CI.
    Copy-Item "powercloud\engine\windows-x64\pce-agente.exe", "powercloud\engine\windows-x64\pce-conector.exe" $carpeta -Force
    $res = Get-ChildItem -Recurse -Filter Runner.res -Path "flutter\build" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($res) { Copy-Item $res.FullName "libs\portable\Runner.res" -Force }
    (Get-Content "res\manifest.xml") | Where-Object { $_ -notmatch "dpiAware" } | Set-Content "res\manifest.xml" -Encoding UTF8
    Ejecutar python @("-m", "pip", "install", "-q", "-r", "libs\portable\requirements.txt")
    Push-Location "libs\portable"
    try { Ejecutar python @(".\generate.py", "-f", $carpeta, "-o", ".", "-e", "$carpeta\PowerCloudRemote.exe") }
    finally { Pop-Location }
    $exe = Join-Path $salida "PowerCloudRemote-$version-x64.exe"
    Copy-Item "target\release\rustdesk-portable-packer.exe" $exe -Force
    Set-Content $contador $Build
} finally { Pop-Location }

$v = (Get-Item $exe).VersionInfo
Paso "Listo en $((Get-Date) - $inicio | ForEach-Object { '{0:hh\:mm\:ss}' -f $_ })"
Write-Host "    $exe" -ForegroundColor Green
Write-Host "    $([math]::Round((Get-Item $exe).Length / 1MB, 1)) MB | $($v.ProductName) | $($v.CompanyName) | SHA256 $((Get-FileHash $exe).Hash)"
Write-Host "`n    Firmar:   .\firmar.ps1 -Archivo `"$exe`""
Write-Host "    Publicar: .\publicar.ps1 -Archivo <exe firmado>"
