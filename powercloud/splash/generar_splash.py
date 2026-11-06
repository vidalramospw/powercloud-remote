"""Genera las imagenes de la ventana de carga del portable (libs/portable/src/res).

label.png : logo + nombre (320 x 80), sobre el fondo de la ventana.
spin.gif  : barra de progreso animada (240 x 40).
Ejecutar:  python powercloud/splash/generar_splash.py
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parents[2]
RES = RAIZ / "libs" / "portable" / "src" / "res"
FUENTES = RAIZ / "flutter" / "assets" / "fonts" / "pc"
LOGO = RAIZ / "powercloud" / "activos" / "icon.png"

FONDO = (15, 21, 28)
PISTA = (31, 42, 54)
AZUL = (56, 182, 232)
BLANCO = (238, 243, 247)
S = 4  # supermuestreo


def label():
    w, h = 320, 80
    im = Image.new("RGB", (w * S, h * S), FONDO)
    d = ImageDraw.Draw(im)
    f1 = ImageFont.truetype(str(FUENTES / "Inter-Bold.ttf"), 23 * S)
    f2 = ImageFont.truetype(str(FUENTES / "Inter-SemiBold.ttf"), 23 * S)
    tam_logo, sep = 48 * S, 14 * S
    ancho_texto = d.textlength("PowerCloud ", font=f1) + d.textlength("Remote", font=f2)
    x0 = int((w * S - (tam_logo + sep + ancho_texto)) / 2)
    logo = Image.open(LOGO).convert("RGBA").resize((tam_logo, tam_logo), Image.LANCZOS)
    im.paste(logo, (x0, (h * S - tam_logo) // 2), logo)
    x, y = x0 + tam_logo + sep, 27 * S
    d.text((x, y), "PowerCloud", font=f1, fill=BLANCO)
    x += d.textlength("PowerCloud ", font=f1)
    d.text((x, y), "Remote", font=f2, fill=AZUL)
    im.resize((w, h), Image.LANCZOS).save(RES / "label.png", optimize=True)


def barra():
    w, h = 240, 40
    frames = []
    n = 48
    alto, y0 = 6, 17
    largo = 80
    for i in range(n):
        im = Image.new("RGB", (w * S, h * S), FONDO)
        d = ImageDraw.Draw(im)
        d.rounded_rectangle((0, y0 * S, w * S - 1, (y0 + alto) * S), radius=alto * S // 2, fill=PISTA)
        t = i / n
        # avance con aceleracion suave (ease in-out)
        e = t * t * (3 - 2 * t)
        x = -largo + e * (w + largo)
        x1, x2 = max(0, x), min(w, x + largo)
        if x2 > x1:
            d.rounded_rectangle((x1 * S, y0 * S, x2 * S, (y0 + alto) * S), radius=alto * S // 2, fill=AZUL)
        q = im.resize((w, h), Image.LANCZOS).quantize(colors=32)
        # Cada cuadro debe guardarse completo: la ventana estira cada cuadro al tamano total
        # y el GIF solo guarda la zona que cambia. Un pixel de esquina que alterna lo evita.
        fondo = q.getpixel((w // 2, 1))
        otro = q.getpixel((w // 2, y0 + alto // 2))
        q.putpixel((0, 0), fondo if i % 2 else otro)
        q.putpixel((w - 1, h - 1), otro if i % 2 else fondo)
        frames.append(q)
    frames[0].save(RES / "spin.gif", save_all=True, append_images=frames[1:], duration=28, loop=0, optimize=False)


def vista_previa(salida):
    """Composicion de como se ve la ventana completa (solo para revisar)."""
    W, H = 400, 240
    im = Image.new("RGB", (W, H), FONDO)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, W - 1, H - 1), outline=(36, 48, 61))
    im.paste(Image.open(RES / "label.png").convert("RGB"), (40, 40))
    g = Image.open(RES / "spin.gif")
    g.seek(16)
    im.paste(g.convert("RGB"), (80, 160))
    im.resize((W * 2, H * 2), Image.LANCZOS).save(salida)


if __name__ == "__main__":
    import sys
    label()
    barra()
    if len(sys.argv) > 1:
        vista_previa(sys.argv[1])
    print("splash generado en", RES)
