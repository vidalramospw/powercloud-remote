#!/usr/bin/env python3
"""
Graficos de la ficha de Google Play de PowerCloud Remote (se generan con la misma geometria de
marca que powercloud/generar_activos.py):

  graficos/icono-512.png              icono de la aplicacion (512x512, sin transparencia)
  graficos/grafico-destacado-es.png   grafico destacado 1024x500 (espanol)
  graficos/grafico-destacado-en.png   grafico destacado 1024x500 (ingles)

El fondo es el mismo del icono adaptativo de Android (#0F151C).

Uso:  python powercloud/play/generar_graficos.py   (requiere Pillow)
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI.parent))
from generar_activos import marca_contorno, marca_horizontal  # noqa: E402

SALIDA = AQUI / "graficos"
FONDO = (0x0F, 0x15, 0x1C, 255)
FUENTES = AQUI.parent.parent / "flutter" / "assets" / "fonts" / "pc"

TEXTOS = {
    "es": ("Remote", "Soporte remoto seguro para tus equipos",
           "Tú aceptas cada sesión  ·  Cifrado de extremo a extremo"),
    "en": ("Remote", "Secure remote support for your devices",
           "You approve every session  ·  End-to-end encryption"),
}


def fuente(peso: str, tam: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FUENTES / f"Inter-{peso}.ttf"), tam)


def icono_play() -> Image.Image:
    lado = 512
    im = Image.new("RGBA", (lado, lado), FONDO)
    marca = marca_contorno(round(lado * 0.74), nucleo=FONDO)
    im.alpha_composite(marca, ((lado - marca.width) // 2, (lado - marca.height) // 2 + 6))
    return im.convert("RGB")


def destacado(idioma: str) -> Image.Image:
    ancho, alto = 1024, 500
    im = Image.new("RGBA", (ancho, alto), FONDO)
    # Degradado suave hacia el celeste de la marca en la esquina derecha.
    capa = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(capa)
    for i in range(60):
        r = 620 - i * 9
        d.ellipse((ancho - r * 0.55, alto - r * 0.9, ancho + r, alto + r * 0.6),
                  fill=(0x38, 0xB6, 0xE8, 3))
    im.alpha_composite(capa)

    d = ImageDraw.Draw(im)
    logo = marca_horizontal(96, oscuro=True)
    x = 72
    im.alpha_composite(logo, (x, 120))
    palabra, lema, detalle = TEXTOS[idioma]
    f_rem = fuente("SemiBold", 66)
    d.text((x + logo.width + 18, 120 + 63 * 96 / 96 + 2), palabra, font=f_rem,
           fill=(255, 255, 255, 255), anchor="ls")
    d.text((x + 4, 290), lema, font=fuente("SemiBold", 40), fill=(255, 255, 255, 255))
    d.text((x + 4, 352), detalle, font=fuente("Regular", 26), fill=(0x7F, 0xD3, 0xF2, 255))
    return im.convert("RGB")


def main() -> None:
    SALIDA.mkdir(exist_ok=True)
    icono_play().save(SALIDA / "icono-512.png", optimize=True)
    for idioma in TEXTOS:
        destacado(idioma).save(SALIDA / f"grafico-destacado-{idioma}.png", optimize=True)
    print("Listo:", ", ".join(sorted(p.name for p in SALIDA.glob("*.png"))))


if __name__ == "__main__":
    main()
