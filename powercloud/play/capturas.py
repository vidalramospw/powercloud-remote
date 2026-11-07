#!/usr/bin/env python3
"""
Capturas de pantalla para la ficha de Google Play, tomadas de la app real en un emulador o
telefono conectado por adb (en espanol y en ingles).

Antes de correrlo:
  1. Instalar el APK nuevo:  adb install -r PowerCloudRemote-<version>-arm64.apk
  2. Abrir la app, ir a "Compartir pantalla" e iniciar el servicio (aceptar el aviso y
     "Compartir pantalla") hasta que diga "Listo".

Uso:  python powercloud/play/capturas.py
Deja graficos/capturas-es/*.png y graficos/capturas-en/*.png a 1080x2160 (Play pide como maximo 2:1).
"""
from __future__ import annotations

import os
import shutil
import subprocess
import time
from pathlib import Path

AQUI = Path(__file__).resolve().parent
PAQUETE = "sv.com.powercloud.remote"
ACTIVIDAD = f"{PAQUETE}/com.carriez.flutter_hbb.MainActivity"
ANCHO, ALTO = 1080, 2160


def adb_ruta() -> str:
    sdk = os.environ.get("ANDROID_HOME") or os.path.join(os.environ.get("LOCALAPPDATA", ""), "Android", "Sdk")
    ruta = os.path.join(sdk, "platform-tools", "adb.exe" if os.name == "nt" else "adb")
    return ruta if os.path.exists(ruta) else (shutil.which("adb") or "adb")


ADB = adb_ruta()


def adb(*args: str, binario: bool = False):
    r = subprocess.run([ADB, *args], capture_output=True, check=False)
    return r.stdout if binario else r.stdout.decode("utf-8", "replace")


def tocar(x: int, y: int, espera: float = 3) -> None:
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(espera)


def buscar(*textos: str) -> tuple[int, int]:
    """Centro del primer elemento en pantalla cuyo texto empieza con alguno de `textos`."""
    import re
    adb("shell", "uiautomator", "dump", "/sdcard/pc_ui.xml")
    xml = adb("shell", "cat", "/sdcard/pc_ui.xml")
    for nodo in re.findall(r"<node [^>]*>", xml):
        m = re.search(r'(?:text|content-desc)="([^"]+)"', nodo)
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', nodo)
        if m and b and m.group(1).startswith(textos):
            x1, y1, x2, y2 = map(int, b.groups())
            return (x1 + x2) // 2, (y1 + y2) // 2
    raise SystemExit(f"No se encontro en pantalla: {textos}")


def captura(destino: Path) -> None:
    destino.write_bytes(adb("exec-out", "screencap", "-p", binario=True))
    print("  ", destino.relative_to(AQUI))


def pestana(i: int) -> None:
    # Barra inferior de 4 pestanas: Conexion, Chat, Compartir pantalla, Ajustes.
    tocar(ANCHO * (2 * i + 1) // 8, ALTO - 130)


def main() -> None:
    adb("shell", "wm", "size", f"{ANCHO}x{ALTO}")
    try:
        for idioma, locale in (("es", "es-419"), ("en", "en-US")):
            carpeta = AQUI / "graficos" / f"capturas-{idioma}"
            carpeta.mkdir(parents=True, exist_ok=True)
            print(idioma)
            adb("shell", "cmd", "locale", "set-app-locales", PAQUETE, "--locales", locale)
            adb("shell", "am", "start", "-n", ACTIVIDAD)
            time.sleep(8)
            pestana(2)
            buscar("Detener servicio", "Stop service")  # el servicio debe estar iniciado
            captura(carpeta / "1-compartir-pantalla.png")
            pestana(0)
            captura(carpeta / "2-conectar.png")
            pestana(2)
            tocar(*buscar("Control de entrada", "Input control"))  # aviso de accesibilidad
            captura(carpeta / "3-aviso-accesibilidad.png")
            adb("shell", "input", "keyevent", "KEYCODE_BACK")
            time.sleep(1)
    finally:
        adb("shell", "wm", "size", "reset")


if __name__ == "__main__":
    main()
