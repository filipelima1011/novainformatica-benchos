#!/usr/bin/env python3
"""
Nova Informática BenchOS - gera os wallpapers (escuro e claro) e a
marca d'água da tela de inicialização.
Saída:
  branding/wallpapers/BenchOS-Escuro/  (pacote de wallpaper do KDE)
  branding/wallpapers/BenchOS-Claro/
  branding/plymouth/watermark.png
A logo aqui é PROVISÓRIA. Ao receber a logo oficial, ajuste a função
desenhar_marca() para colar o arquivo oficial e rode de novo.
Uso: python3 branding/gerar-wallpapers.py
"""
import os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WP = os.path.join(RAIZ, "branding", "wallpapers")
PLY = os.path.join(RAIZ, "branding", "plymouth")
TAMANHOS = [(1920, 1080), (2560, 1440)]

TEMAS = {
    "Escuro": dict(fa=(3, 6, 12), fb=(9, 24, 50), trilha=(30, 111, 255), a_min=30, a_max=85,
                   brilho=60, texto=(255, 255, 255), sub=(175, 190, 215), destaque=(110, 170, 255),
                   chip=(12, 22, 40), chip_borda=(60, 140, 255)),
    "Claro":  dict(fa=(244, 247, 252), fb=(214, 226, 244), trilha=(30, 100, 220), a_min=25, a_max=70,
                   brilho=40, texto=(10, 18, 32), sub=(70, 85, 110), destaque=(20, 95, 230),
                   chip=(232, 238, 248), chip_borda=(40, 110, 235)),
}

def fonte(peso, tam):
    mapa = {"bold": "Inter-Bold.otf", "semi": "Inter-SemiBold.otf", "reg": "Inter-Regular.otf",
            "light": "Inter-Light.otf"}
    for c in [f"/usr/share/fonts/opentype/inter/{mapa[peso]}",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if peso in ("bold", "semi")
              else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]:
        if os.path.exists(c):
            return ImageFont.truetype(c, tam)
    return ImageFont.load_default()

def icone(tam):
    img = Image.new("RGBA", (tam, tam), (0, 0, 0, 0))
    m = Image.new("L", (tam, tam), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, tam - 1, tam - 1], radius=int(tam * .23), fill=255)
    g = Image.new("RGBA", (tam, tam)); gd = ImageDraw.Draw(g)
    for y in range(tam):
        t = y / tam
        gd.line([(0, y), (tam, y)], fill=(int(40 - 30 * t), int(130 - 90 * t), int(255 - 120 * t), 255))
    img.paste(g, (0, 0), m)
    d = ImageDraw.Draw(img); f = fonte("bold", int(tam * .62))
    bb = d.textbbox((0, 0), "N", font=f)
    d.text(((tam - bb[2] - bb[0]) / 2, (tam - bb[3] - bb[1]) / 2), "N", font=f, fill=(255, 255, 255))
    return img

def fundo(w, h, t):
    img = Image.new("RGB", (w, h)); d = ImageDraw.Draw(img)
    for y in range(h):
        k = y / h
        d.line([(0, y), (w, y)], fill=tuple(int(t["fa"][i] + (t["fb"][i] - t["fa"][i]) * k) for i in range(3)))
    return img.convert("RGBA")

def circuitos(w, h, t, s, semente=42):
    cam = Image.new("RGBA", (w, h), (0, 0, 0, 0)); c = ImageDraw.Draw(cam)
    rnd = random.Random(semente); passo = int(24 * s)
    # trilhas mais densas à direita
    for _ in range(int(380 * s * s)):
        x = int(w * (0.44 + 0.56 * rnd.random() ** 0.7)); y = rnd.randrange(0, h)
        x -= x % passo; y -= y % passo; pts = [(x, y)]
        for _ in range(rnd.randint(2, 6)):
            if rnd.random() < .5: x += rnd.choice([-1, 1]) * rnd.randint(2, 9) * passo
            else: y += rnd.choice([-1, 1]) * rnd.randint(2, 6) * passo
            pts.append((x, y))
        a = rnd.randint(t["a_min"], t["a_max"]); lw = max(1, int(2 * s))
        c.line(pts, fill=t["trilha"] + (a,), width=lw)
        for (px, py) in (pts[0], pts[-1]):
            r = int(4 * s)
            c.ellipse([px - r, py - r, px + r, py + r], outline=t["trilha"] + (min(255, a + 50),), width=lw)
    # componentes: pentes de memória e capacitores
    for i in range(4):
        x0 = int(w * .60) + i * int(38 * s); y0 = int(h * .08)
        c.rounded_rectangle([x0, y0, x0 + int(22 * s), y0 + int(300 * s)], radius=int(4 * s),
                            outline=t["trilha"] + (70,), width=max(1, int(2 * s)))
    for _ in range(int(14 * s)):
        cx, cy, r = rnd.randrange(int(w * .5), w), rnd.randrange(int(h * .55), h), int(rnd.randint(10, 22) * s)
        c.ellipse([cx - r, cy - r, cx + r, cy + r], outline=t["trilha"] + (60,), width=max(1, int(2 * s)))
        c.ellipse([cx - r // 3, cy - r // 3, cx + r // 3, cy + r // 3], fill=t["trilha"] + (50,))
    return cam

def chip(w, h, t, s):
    cam = Image.new("RGBA", (w, h), (0, 0, 0, 0)); c = ImageDraw.Draw(cam)
    lado = int(330 * s); cx, cy = int(w * .74), int(h * .52)
    x0, y0, x1, y1 = cx - lado // 2, cy - lado // 2, cx + lado // 2, cy + lado // 2
    # pinos
    n, pl = 14, int(26 * s)
    for i in range(n):
        p = x0 + int((i + .5) * lado / n)
        for (a, b) in [((p, y0 - pl), (p, y0)), ((p, y1), (p, y1 + pl))]:
            c.line([a, b], fill=t["chip_borda"] + (200,), width=max(2, int(4 * s)))
        q = y0 + int((i + .5) * lado / n)
        for (a, b) in [((x0 - pl, q), (x0, q)), ((x1, q), (x1 + pl, q))]:
            c.line([a, b], fill=t["chip_borda"] + (200,), width=max(2, int(4 * s)))
    # brilho
    gl = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(gl).rounded_rectangle([x0 - 30 * s, y0 - 30 * s, x1 + 30 * s, y1 + 30 * s],
                                         radius=int(40 * s), fill=t["chip_borda"] + (t["brilho"] + 30,))
    gl = gl.filter(ImageFilter.GaussianBlur(int(45 * s)))
    cam = Image.alpha_composite(gl, cam); c = ImageDraw.Draw(cam)
    c.rounded_rectangle([x0, y0, x1, y1], radius=int(28 * s), fill=t["chip"] + (255,),
                        outline=t["chip_borda"] + (255,), width=max(2, int(4 * s)))
    m = int(26 * s)
    c.rounded_rectangle([x0 + m, y0 + m, x1 - m, y1 - m], radius=int(18 * s),
                        outline=t["chip_borda"] + (110,), width=max(1, int(2 * s)))
    f1, f2 = fonte("bold", int(64 * s)), fonte("semi", int(22 * s))
    for txt, f, cor, dy in [("BenchOS", f1, t["texto"], -int(22 * s)), ("NOVA INFORMÁTICA", f2, t["destaque"], int(46 * s))]:
        bb = c.textbbox((0, 0), txt, font=f)
        c.text((cx - (bb[2] - bb[0]) / 2 - bb[0], cy + dy - (bb[3] - bb[1]) / 2 - bb[1]), txt, font=f, fill=cor)
    return cam

def desenhar_marca(img, w, h, t, s):
    d = ImageDraw.Draw(img); x = int(130 * s); y = int(h * .36)
    ic = icone(int(84 * s)); img.alpha_composite(ic, (x, y))
    d.text((x + int(104 * s), y + int(14 * s)), "NOVA INFORMÁTICA", font=fonte("bold", int(40 * s)), fill=t["texto"])
    d.text((x + int(104 * s), y + int(58 * s)), "Assistência Técnica Premium", font=fonte("reg", int(22 * s)), fill=t["sub"])
    d.text((x - int(6 * s), y + int(110 * s)), "BenchOS", font=fonte("bold", int(150 * s)), fill=t["destaque"])
    d.rounded_rectangle([x, y + int(300 * s), x + int(90 * s), y + int(306 * s)], radius=int(3 * s), fill=t["destaque"])
    d.text((x, y + int(326 * s)), "A tecnologia e você", font=fonte("light", int(34 * s)), fill=t["texto"])

def wallpaper(nome, t, w, h):
    s = w / 1920
    img = fundo(w, h, t)
    gl = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(gl).ellipse([int(w * .45), int(-h * .25), int(w * 1.2), int(h * 1.05)], fill=t["trilha"] + (t["brilho"],))
    img = Image.alpha_composite(img, gl.filter(ImageFilter.GaussianBlur(int(160 * s))))
    img = Image.alpha_composite(img, circuitos(w, h, t, s))
    img = Image.alpha_composite(img, chip(w, h, t, s))
    desenhar_marca(img, w, h, t, s)
    return img.convert("RGB")

for nome, t in TEMAS.items():
    pasta = os.path.join(WP, f"BenchOS-{nome}")
    os.makedirs(os.path.join(pasta, "contents", "images"), exist_ok=True)
    for (w, h) in TAMANHOS:
        wallpaper(nome, t, w, h).save(os.path.join(pasta, "contents", "images", f"{w}x{h}.png"), optimize=True)
    wallpaper(nome, t, 640, 360).save(os.path.join(pasta, "contents", "screenshot.png"))
    with open(os.path.join(pasta, "metadata.desktop"), "w", encoding="utf-8") as f:
        f.write(f"[Desktop Entry]\nName=BenchOS {nome}\nX-KDE-PluginInfo-Name=BenchOS-{nome}\n"
                f"X-KDE-PluginInfo-Author=Nova Informática\nX-KDE-PluginInfo-License=Todos os direitos reservados\n")

# Marca d'água da tela de inicialização (Plymouth)
os.makedirs(PLY, exist_ok=True)
wm = Image.new("RGBA", (520, 110), (0, 0, 0, 0)); d = ImageDraw.Draw(wm)
wm.alpha_composite(icone(80), (10, 15))
d.text((110, 14), "NOVA INFORMÁTICA", font=fonte("bold", 32), fill=(255, 255, 255))
d.text((110, 54), "BenchOS", font=fonte("bold", 40), fill=(110, 170, 255))
wm.save(os.path.join(PLY, "watermark.png"))
print("Wallpapers e marca d'água gerados.")
