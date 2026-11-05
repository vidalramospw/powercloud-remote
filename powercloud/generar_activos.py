#!/usr/bin/env python3
"""
Genera los iconos y logos de PowerCloud Remote en powercloud/activos/ a partir de la marca
PowerCloud (E:\\AdminCentral\\frontend\\public\\logo-celeste.svg, marca-solida.svg y
marca-horizontal*.svg). La geometria se copia aqui tal cual para no depender de un
rasterizador SVG: se dibuja con Pillow a 8x y se reduce.

Reglas de la marca que se respetan:
- 48 px o mas: nube de CONTORNO (trazo 7 sobre viewBox 128) con el chip y su nucleo calado.
- 16-32 px: version SOLIDA (nube rellena con el chip calado); el contorno se empasta.
- Celeste #38b6e8; texto "Power" #0b2b45 y "Cloud" #1a8fc4 (claro) / blanco y #7fd3f2 (oscuro).

Uso:  python powercloud/generar_activos.py   (requiere Pillow)
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SALIDA = Path(__file__).resolve().parent / "activos"
CELESTE = (0x38, 0xB6, 0xE8, 255)
SS = 8  # supermuestreo

# Nube del viewBox 128x96: M36 86 C... Z (curvas cubicas)
NUBE = [
    ((36, 86), (20, 86), (8, 74), (8, 59)),
    ((8, 59), (8, 46), (17, 36), (29, 34)),
    ((29, 34), (33, 20), (46, 10), (61, 10)),
    ((61, 10), (79, 10), (94, 23), (96, 41)),
    ((96, 41), (110, 43), (120, 55), (120, 68)),
    ((120, 68), (120, 78), (112, 86), (102, 86)),
]


def _bezier(p0, p1, p2, p3, n=40):
    pts = []
    for i in range(n + 1):
        t = i / n
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t ** 2, t ** 3
        pts.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0],
                    a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return pts


def _nube_puntos():
    pts = []
    for seg in NUBE:
        pts.extend(_bezier(*seg)[:-1])
    pts.append(NUBE[-1][3])  # (102,86); el Z cierra con una recta hasta (36,86)
    return pts


def _lienzo(lado: int, ancho_vb: float = 128, alto_vb: float = 96, margen: float = 2):
    """Lienzo cuadrado supermuestreado y transformacion viewBox -> pixeles (centrado)."""
    px = lado * SS
    escala = (px - 2 * margen * SS) / max(ancho_vb, alto_vb)
    dx = (px - ancho_vb * escala) / 2
    dy = (px - alto_vb * escala) / 2
    im = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    return im, (lambda x, y: (dx + x * escala, dy + y * escala)), escala


def _trazo(d, pts, ancho):
    """Trazo cerrado continuo: segmentos + circulos en cada vertice (union redonda real)."""
    r = ancho / 2
    cerrado = pts + [pts[0]]
    for a, b in zip(cerrado, cerrado[1:]):
        d.line([a, b], fill=CELESTE, width=round(ancho))
    for x, y in pts:
        d.ellipse([x - r, y - r, x + r, y + r], fill=CELESTE)


def _rrect(d, t, x, y, w, h, r, fill):
    (x0, y0), (x1, y1) = t(x, y), t(x + w, y + h)
    s = (x1 - x0) / w
    d.rounded_rectangle([x0, y0, x1, y1], radius=r * s, fill=fill)


def _chip(d, t, nucleo):
    _rrect(d, t, 48, 39, 32, 26, 5, CELESTE)
    for x, y in ((55, 32), (69, 32), (55, 64), (69, 64)):
        _rrect(d, t, x, y, 4, 8, 1.4, CELESTE)
    _rrect(d, t, 58, 48, 12, 8, 2, nucleo)


def marca_contorno(lado: int, nucleo=(255, 255, 255, 255)) -> Image.Image:
    im, t, escala = _lienzo(lado)
    d = ImageDraw.Draw(im)
    pts = [t(*p) for p in _nube_puntos()]
    _trazo(d, pts, 7 * escala)
    _chip(d, t, nucleo)
    return im.resize((lado, lado), Image.LANCZOS)


def marca_solida(lado: int) -> Image.Image:
    im, t, _ = _lienzo(lado, margen=0.5)
    d = ImageDraw.Draw(im)
    d.polygon([t(*p) for p in _nube_puntos()], fill=CELESTE)
    _rrect(d, t, 44, 38, 40, 32, 6, (0, 0, 0, 0))  # chip calado (evenodd del SVG)
    return im.resize((lado, lado), Image.LANCZOS)


def icono(lado: int) -> Image.Image:
    return marca_solida(lado) if lado <= 32 else marca_contorno(lado)


def marca_horizontal(alto: int, oscuro: bool) -> Image.Image:
    """Conjunto marca + nombre (viewBox 430x96), para el logo de la pantalla principal."""
    escala = alto * SS / 96
    ancho = round(430 * escala)
    im = Image.new("RGBA", (ancho, alto * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    t = lambda x, y: (x * escala, y * escala)  # noqa: E731
    pts = [t(*p) for p in _nube_puntos()]
    _trazo(d, pts, 7 * escala)
    _chip(d, t, (0x0B, 0x2B, 0x45, 255) if oscuro else (255, 255, 255, 255))

    fuente = ImageFont.truetype("segoeuib.ttf", round(44 * escala))
    x, base = 144 * escala, 63 * escala
    espacio = -1.1 * escala
    colores = ((255, 255, 255, 255), (0x7F, 0xD3, 0xF2, 255)) if oscuro else \
              ((0x0B, 0x2B, 0x45, 255), (0x1A, 0x8F, 0xC4, 255))
    for palabra, color in zip(("Power", "Cloud"), colores):
        for ch in palabra:
            d.text((x, base), ch, font=fuente, fill=color, anchor="ls")
            x += fuente.getlength(ch) + espacio
    ancho_util = min(ancho, round(x + 4 * escala))
    im = im.crop((0, 0, ancho_util, alto * SS))
    return im.resize((round(ancho_util / SS), alto), Image.LANCZOS)


SVG_SOLIDO = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -16 128 128">
  <!-- PowerCloud: marca solida (se usa a 16-30 px dentro de la app) -->
  <path fill="#38b6e8" fill-rule="evenodd"
        d="M36 86 C20 86 8 74 8 59 C8 46 17 36 29 34 C33 20 46 10 61 10
           C79 10 94 23 96 41 C110 43 120 55 120 68 C120 78 112 86 102 86 Z
           M50 38 h28 a6 6 0 0 1 6 6 v20 a6 6 0 0 1 -6 6 h-28 a6 6 0 0 1 -6 -6 v-20 a6 6 0 0 1 6 -6 Z"/>
</svg>
"""


def main() -> None:
    SALIDA.mkdir(parents=True, exist_ok=True)

    tamanos_ico = [16, 20, 24, 32, 40, 48, 64, 128, 256]
    imgs = [icono(s) for s in tamanos_ico]
    imgs[-1].save(SALIDA / "icon.ico", format="ICO",
                  sizes=[(s, s) for s in tamanos_ico], append_images=imgs[:-1])

    tray = [16, 20, 24, 32]
    timgs = [marca_solida(s) for s in tray]
    timgs[-1].save(SALIDA / "tray-icon.ico", format="ICO",
                   sizes=[(s, s) for s in tray], append_images=timgs[:-1])

    marca_contorno(1024).save(SALIDA / "icon.png")
    marca_solida(32).save(SALIDA / "32x32.png")
    for s in (64, 128):
        marca_contorno(s).save(SALIDA / f"{s}x{s}.png")
    marca_contorno(256).save(SALIDA / "128x128@2x.png")

    (SALIDA / "icon.svg").write_text(SVG_SOLIDO, encoding="utf-8")

    marca_horizontal(180, oscuro=True).save(SALIDA / "logo_dark.png")
    marca_horizontal(180, oscuro=False).save(SALIDA / "logo_light.png")

    for f in sorted(SALIDA.iterdir()):
        print(f"  {f.name}")


if __name__ == "__main__":
    main()
