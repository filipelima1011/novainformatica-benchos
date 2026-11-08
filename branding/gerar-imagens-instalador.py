#!/usr/bin/env python3
"""
Nova Informática BenchOS - gera as imagens da tela de instalação.
Saída: installer/calamares/branding/benchos/
A logo aqui é PROVISÓRIA (texto). Quando a logo oficial chegar,
basta substituir logo.png, icon.png e welcome.png por versões oficiais.
Uso: python3 branding/gerar-imagens-instalador.py
"""
import os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAIDA = os.path.join(RAIZ, "installer", "calamares", "branding", "benchos")
os.makedirs(SAIDA, exist_ok=True)

AZUL = (30, 111, 255)
AZUL_CLARO = (120, 175, 255)
BRANCO = (255, 255, 255)
FUNDO_A = (4, 7, 14)
FUNDO_B = (10, 26, 52)

def fonte(peso, tam):
    opcoes = {
        "bold": ["/usr/share/fonts/opentype/inter/Inter-Bold.otf",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"],
        "semi": ["/usr/share/fonts/opentype/inter/Inter-SemiBold.otf",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"],
        "reg":  ["/usr/share/fonts/opentype/inter/Inter-Regular.otf",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"],
    }[peso]
    for c in opcoes:
        if os.path.exists(c):
            return ImageFont.truetype(c, tam)
    return ImageFont.load_default()

def fundo(w, h, semente=1):
    img = Image.new("RGB", (w, h), FUNDO_A)
    d = ImageDraw.Draw(img)
    for y in range(h):                       # degradê diagonal suave
        t = y / h
        cor = tuple(int(FUNDO_A[i] + (FUNDO_B[i] - FUNDO_A[i]) * t) for i in range(3))
        d.line([(0, y), (w, y)], fill=cor)
    # trilhas de circuito
    camada = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    c = ImageDraw.Draw(camada)
    rnd = random.Random(semente)
    for _ in range(int(w * h / 9000)):
        x, y = rnd.randrange(w // 2, w), rnd.randrange(0, h)
        x, y = x - x % 20, y - y % 20
        pts = [(x, y)]
        for _ in range(rnd.randint(2, 5)):
            if rnd.random() < 0.5:
                x += rnd.choice([-1, 1]) * rnd.randint(2, 8) * 20
            else:
                y += rnd.choice([-1, 1]) * rnd.randint(2, 6) * 20
            pts.append((x, y))
        alfa = rnd.randint(25, 70)
        c.line(pts, fill=AZUL + (alfa,), width=2)
        ex, ey = pts[-1]
        c.ellipse([ex - 4, ey - 4, ex + 4, ey + 4], outline=AZUL + (alfa + 40,), width=2)
    # brilho azul no canto direito
    brilho = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(brilho).ellipse([int(w * .55), int(-h * .3), int(w * 1.3), int(h * .9)], fill=AZUL + (45,))
    brilho = brilho.filter(ImageFilter.GaussianBlur(120))
    img = Image.alpha_composite(img.convert("RGBA"), brilho)
    return Image.alpha_composite(img, camada)

def icone(tam):
    img = Image.new("RGBA", (tam, tam), (0, 0, 0, 0))
    m = Image.new("L", (tam, tam), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, tam - 1, tam - 1], radius=int(tam * .23), fill=255)
    grad = Image.new("RGBA", (tam, tam))
    gd = ImageDraw.Draw(grad)
    for y in range(tam):
        t = y / tam
        gd.line([(0, y), (tam, y)], fill=(int(40 - 30 * t), int(130 - 90 * t), int(255 - 120 * t), 255))
    img.paste(grad, (0, 0), m)
    d = ImageDraw.Draw(img)
    f = fonte("bold", int(tam * .62))
    bb = d.textbbox((0, 0), "N", font=f)
    d.text(((tam - (bb[2] - bb[0])) / 2 - bb[0], (tam - (bb[3] - bb[1])) / 2 - bb[1]), "N", font=f, fill=BRANCO)
    return img

def logo(w, h, com_fundo=False):
    img = fundo(w, h, 7) if com_fundo else Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ic = icone(int(h * .62))
    y0 = (h - ic.height) // 2
    img.alpha_composite(ic, (int(h * .12), y0))
    x = int(h * .12) + ic.width + int(h * .14)
    d.text((x, y0 - int(h * .02)), "NOVA INFORMÁTICA", font=fonte("bold", int(h * .2)), fill=BRANCO)
    d.text((x, y0 + int(h * .24)), "BenchOS", font=fonte("bold", int(h * .3)), fill=AZUL_CLARO)
    return img

def slide(n, titulo, linhas, rotulo):
    w, h = 1280, 720
    img = fundo(w, h, n * 13)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([80, 120, 80 + 8, 120 + 64], radius=4, fill=AZUL)
    d.text((110, 112), rotulo.upper(), font=fonte("semi", 26), fill=AZUL_CLARO)
    d.text((108, 150), titulo, font=fonte("bold", 64), fill=BRANCO)
    y = 270
    for l in linhas:
        d.ellipse([112, y + 14, 124, y + 26], fill=AZUL)
        d.text((145, y), l, font=fonte("reg", 32), fill=(215, 225, 240))
        y += 58
    d.line([(80, h - 90), (w - 80, h - 90)], fill=(40, 60, 95), width=1)
    d.text((80, h - 70), "NOVA INFORMÁTICA  •  Assistência Técnica Premium", font=fonte("semi", 24), fill=(170, 185, 210))
    f = fonte("reg", 24)
    s = "A tecnologia e você"
    d.text((w - 80 - d.textlength(s, font=f), h - 70), s, font=f, fill=AZUL_CLARO)
    img.convert("RGB").save(os.path.join(SAIDA, f"slide{n}.png"), optimize=True)

SLIDES = [
    ("Bem-vindo à BenchOS", ["Sistema de bancada da Nova Informática",
     "Diagnóstico, testes e recuperação em um só lugar",
     "Baseado no Ubuntu 24.04 LTS com KDE Plasma"], "Instalação"),
    ("Diagnóstico de Hardware", ["Processador, memória, placa-mãe e BIOS",
     "Temperaturas, ventoinhas e sensores em tempo real",
     "Teste completo de notebooks e bateria"], "Hardware Center"),
    ("Recuperação de Dados", ["TestDisk, PhotoRec, ddrescue e Autopsy",
     "Discos com BitLocker, NTFS, ext4, exFAT e HFS+",
     "Proteção do disco de origem por padrão"], "Data Recovery Center"),
    ("Benchmark e Stress", ["CPU, memória RAM, placa de vídeo e SSD",
     "stress-ng, s-tui, glmark2, fio, KDiskMark e OCCT",
     "Memtest86+ direto no menu de inicialização"], "Benchmark Center"),
    ("Pronto para a bancada", ["Manutenção de Windows e Linux",
     "Eletrônica, gravação de BIOS e rede",
     "Relatórios técnicos com a sua marca"], "Nova Informática"),
]

for i, (t, ls, r) in enumerate(SLIDES, 1):
    slide(i, t, ls, r)
icone(256).save(os.path.join(SAIDA, "icon.png"))
logo(620, 140).save(os.path.join(SAIDA, "logo.png"))
logo(1000, 300, com_fundo=True).convert("RGB").save(os.path.join(SAIDA, "welcome.png"))
print("Imagens geradas em", SAIDA)
