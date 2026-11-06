#!/usr/bin/env python3
"""
Iconos de PowerCloud Remote para Android, Linux, macOS e iOS, con la misma geometria de marca de
generar_activos.py (nube celeste con chip). Escribe directamente en las carpetas de cada
plataforma del proyecto.

Uso:  python powercloud/generar_plataformas.py [android] [linux] [macos] [ios]
      (sin argumentos genera todas)
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generar_activos import marca_contorno, marca_solida  # noqa: E402

RAIZ = Path(__file__).resolve().parents[1]
FLUTTER = RAIZ / "flutter"
NAVY = (15, 21, 28, 255)
SS = 4


def _sobre_fondo(lado: int, forma: str, proporcion: float) -> Image.Image:
    """Logo centrado sobre fondo azul marino; forma = 'cuadro' (esquinas redondeadas) o 'circulo'."""
    grande = lado * SS
    im = Image.new("RGBA", (grande, grande), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if forma == "circulo":
        d.ellipse((0, 0, grande - 1, grande - 1), fill=NAVY)
    else:
        d.rounded_rectangle((0, 0, grande - 1, grande - 1), radius=int(grande * 0.22), fill=NAVY)
    lado_logo = int(grande * proporcion)
    logo = marca_contorno(lado_logo)
    im.alpha_composite(logo, ((grande - lado_logo) // 2, (grande - lado_logo) // 2))
    return im.resize((lado, lado), Image.LANCZOS)


def _centrado(lado: int, proporcion: float) -> Image.Image:
    im = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    lado_logo = int(lado * proporcion)
    im.alpha_composite(marca_contorno(lado_logo), ((lado - lado_logo) // 2, (lado - lado_logo) // 2))
    return im


def _blanco(lado: int) -> Image.Image:
    """Silueta blanca (iconos monocromo: barra de notificaciones)."""
    sol = marca_solida(lado)
    blanco = Image.new("RGBA", sol.size, (255, 255, 255, 0))
    blanco.putalpha(sol.getchannel("A"))
    return blanco


def android() -> None:
    res = FLUTTER / "android" / "app" / "src" / "main" / "res"
    densidades = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for nombre, f in densidades.items():
        carpeta = res / f"mipmap-{nombre}"
        _sobre_fondo(int(48 * f), "cuadro", 0.66).save(carpeta / "ic_launcher.png")
        _sobre_fondo(int(48 * f), "circulo", 0.62).save(carpeta / "ic_launcher_round.png")
        # Adaptativo: lienzo de 108 dp, zona segura de 66 dp en el centro.
        _centrado(int(108 * f), 0.50).save(carpeta / "ic_launcher_foreground.png")
        _blanco(int(24 * f)).save(carpeta / "ic_stat_logo.png")
    fondo = res / "values" / "ic_launcher_background.xml"
    fondo.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#0F151C</color>\n</resources>\n',
        encoding="utf-8",
    )
    print("  android: mipmap-* y ic_launcher_background")


def linux() -> None:
    # En Linux/Windows los iconos de res/ los pone aplicar_marca.py desde powercloud/activos;
    # esta version (sobre fondo) queda disponible por si se prefiere para el escritorio Linux.
    destino = RAIZ / "res"
    for s in (32, 64, 128):
        _sobre_fondo(s, "cuadro", 0.70).save(destino / f"{s}x{s}.png")
    _sobre_fondo(256, "cuadro", 0.70).save(destino / "128x128@2x.png")
    _sobre_fondo(512, "cuadro", 0.70).save(destino / "icon.png")
    print("  linux: res/*.png")


def macos() -> None:
    archivo = FLUTTER / "macos" / "Runner" / "AppIcon.icns"
    base = _sobre_fondo(1024, "cuadro", 0.68)
    base.save(archivo, format="ICNS", sizes=[(16, 16), (32, 32), (64, 64), (128, 128), (256, 256), (512, 512), (1024, 1024)])
    print("  macos: Runner/AppIcon.icns")


def ios() -> None:
    carpeta = FLUTTER / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for archivo in carpeta.glob("*.png"):
        lado = Image.open(archivo).size[0]
        # iOS no admite transparencia en el icono: fondo azul marino completo.
        im = Image.new("RGBA", (lado, lado), NAVY)
        lado_logo = int(lado * 0.66)
        im.alpha_composite(marca_contorno(lado_logo), ((lado - lado_logo) // 2, (lado - lado_logo) // 2))
        im.convert("RGB").save(archivo)
    print("  ios: AppIcon.appiconset")


if __name__ == "__main__":
    pedidas = sys.argv[1:] or ["android", "macos", "ios"]
    for p in pedidas:
        globals()[p]()
