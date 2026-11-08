#!/bin/bash
# ============================================================
#  Nova Informática BenchOS - Tema estilo macOS
#  Usa os temas WhiteSur (código aberto, GPL-3, de vinceliuice)
#  para KDE, GTK, ícones e cursores, com variante escura,
#  botões das janelas à esquerda e layout com dock.
#  Roda dentro do chroot (chamado pelo scripts/install.sh).
# ============================================================
set -u
export DEBIAN_FRONTEND=noninteractive
LOG=/var/log/benchos-instalacao.log
DIR="$(cd "$(dirname "$0")" && pwd)"
LNF_ID="org.novainformatica.benchos"
LNF_DIR="/usr/share/plasma/look-and-feel/$LNF_ID"
SKEL=/etc/skel/.config

msg() { echo "[Tema] $*" | tee -a "$LOG"; }

apt-get install -y git sassc libglib2.0-dev-bin qt5-style-kvantum >>"$LOG" 2>&1

TMP=$(mktemp -d)
instalar_tema() {   # instalar_tema <repositório> [argumentos]
  local repo="$1"; shift
  if git clone --depth 1 "https://github.com/vinceliuice/$repo.git" "$TMP/$repo" >>"$LOG" 2>&1; then
    (cd "$TMP/$repo" && bash ./install.sh "$@" >>"$LOG" 2>&1) \
      && msg "OK      $repo" || msg "FALHOU  $repo (instalação)"
  else
    msg "FALHOU  $repo (download)"
  fi
}

instalar_tema WhiteSur-kde
instalar_tema WhiteSur-icon-theme
instalar_tema WhiteSur-cursors
instalar_tema WhiteSur-gtk-theme

# Tela de login (SDDM), se o tema trouxer instalador próprio
SDDM_INST=$(find "$TMP/WhiteSur-kde" -path '*sddm*' -name install.sh 2>/dev/null | head -1)
[ -n "$SDDM_INST" ] && (cd "$(dirname "$SDDM_INST")" && bash ./install.sh >>"$LOG" 2>&1)
rm -rf "$TMP"

# ------------------------------------------------------------
# Detecta os nomes instalados (com alternativa Breeze escuro)
# ------------------------------------------------------------
achar() { ls -1 "$1" 2>/dev/null | grep -iE "$2" | head -1; }
PLASMA=$(achar /usr/share/plasma/desktoptheme 'whitesur.*dark')
CORES=$(achar /usr/share/color-schemes 'whitesur.*dark' | sed 's/\.colors$//')
AURORAE=$(achar /usr/share/aurorae/themes 'whitesur.*dark')
KVANTUM=$(achar /usr/share/Kvantum 'whitesur.*dark')
ICONES=$(achar /usr/share/icons '^whitesur-dark$')
CURSOR=$(achar /usr/share/icons '^whitesur-cursors$')
GTK=$(achar /usr/share/themes '^whitesur-dark$')
SDDM=$(achar /usr/share/sddm/themes 'whitesur')

PLASMA=${PLASMA:-breeze-dark}
CORES=${CORES:-BreezeDark}
ICONES=${ICONES:-breeze-dark}
CURSOR=${CURSOR:-breeze_cursors}
GTK=${GTK:-Breeze}
if [ -n "$KVANTUM" ]; then ESTILO=kvantum-dark; else ESTILO=Breeze; fi
msg "plasma=$PLASMA cores=$CORES janelas=${AURORAE:-breeze} kvantum=${KVANTUM:-nenhum} icones=$ICONES cursor=$CURSOR gtk=$GTK sddm=${SDDM:-padrao}"

# ------------------------------------------------------------
# Pacote de aparência "Nova Informática BenchOS" (com o layout)
# ------------------------------------------------------------
rm -rf "$LNF_DIR"
mkdir -p "$LNF_DIR/contents/layouts"
cp "$DIR/look-and-feel/layout.js" "$LNF_DIR/contents/layouts/org.kde.plasma.desktop-layout.js"
cat > "$LNF_DIR/metadata.desktop" <<EOF
[Desktop Entry]
Name=Nova Informática BenchOS
Comment=Tema estilo macOS com barra superior e dock
Type=Service
X-KDE-ServiceTypes=Plasma/LookAndFeel
X-KDE-PluginInfo-Name=$LNF_ID
X-KDE-PluginInfo-Author=Nova Informática
X-KDE-PluginInfo-Version=1.0
X-KDE-PluginInfo-License=GPL
X-Plasma-MainScript=defaults
EOF

DECOR_LIB="org.kde.breeze"; DECOR_TEMA="Breeze"
if [ -n "$AURORAE" ]; then DECOR_LIB="org.kde.kwin.aurorae"; DECOR_TEMA="__aurorae__svg__$AURORAE"; fi

cat > "$LNF_DIR/contents/defaults" <<EOF
[kdeglobals][KDE]
widgetStyle=$ESTILO

[kdeglobals][General]
ColorScheme=$CORES

[kdeglobals][Icons]
Theme=$ICONES

[plasmarc][Theme]
name=$PLASMA

[kcminputrc][Mouse]
cursorTheme=$CURSOR

[kwinrc][org.kde.kdecoration2]
library=$DECOR_LIB
theme=$DECOR_TEMA
EOF

# ------------------------------------------------------------
# Padrões para todo usuário novo (inclui o usuário do modo live)
# ------------------------------------------------------------
mkdir -p "$SKEL/Kvantum" "$SKEL/gtk-3.0" "$SKEL/gtk-4.0"

cat > "$SKEL/kdeglobals" <<EOF
[General]
ColorScheme=$CORES

[Icons]
Theme=$ICONES

[KDE]
LookAndFeelPackage=$LNF_ID
widgetStyle=$ESTILO
EOF

cat > "$SKEL/plasmarc" <<EOF
[Theme]
name=$PLASMA
EOF

cat > "$SKEL/kwinrc" <<EOF
[org.kde.kdecoration2]
ButtonsOnLeft=XIA
ButtonsOnRight=
library=$DECOR_LIB
theme=$DECOR_TEMA
EOF

cat > "$SKEL/kcminputrc" <<EOF
[Mouse]
cursorTheme=$CURSOR
EOF

[ -n "$KVANTUM" ] && printf '[General]\ntheme=%s\n' "$KVANTUM" > "$SKEL/Kvantum/kvantum.kvconfig"

for v in gtk-3.0 gtk-4.0; do
  cat > "$SKEL/$v/settings.ini" <<EOF
[Settings]
gtk-theme-name=$GTK
gtk-icon-theme-name=$ICONES
gtk-cursor-theme-name=$CURSOR
gtk-application-prefer-dark-theme=true
EOF
done

# Tela de login
mkdir -p /etc/sddm.conf.d
{
  echo "[Theme]"
  [ -n "$SDDM" ] && echo "Current=$SDDM"
  echo "CursorTheme=$CURSOR"
} > /etc/sddm.conf.d/benchos.conf

# ------------------------------------------------------------
# Nomes dos temas escuro e claro para o alternador "nova-tema"
# ------------------------------------------------------------
claro() { ls -1 "$1" 2>/dev/null | grep -iE "$2" | grep -viE 'dark|alt|opaque|solid|sharp|nord' | head -1; }
WP=/usr/share/wallpapers
mkdir -p /etc/benchos
cat > /etc/benchos/tema.conf <<EOF
# Gerado no build pelo tema-macos.sh
ESCURO_CORES="$CORES"
ESCURO_PLASMA="$PLASMA"
ESCURO_ICONES="$ICONES"
ESCURO_AURORAE="$AURORAE"
ESCURO_KVANTUM="$KVANTUM"
ESCURO_GTK="$GTK"
ESCURO_WALLPAPER="$WP/BenchOS-Escuro/contents/images/1920x1080.png"
CLARO_CORES="$(claro /usr/share/color-schemes '^whitesur' | sed 's/\.colors$//')"
CLARO_PLASMA="$(claro /usr/share/plasma/desktoptheme '^whitesur')"
CLARO_ICONES="$(claro /usr/share/icons '^whitesur$')"
CLARO_AURORAE="$(claro /usr/share/aurorae/themes '^whitesur')"
CLARO_KVANTUM="$(claro /usr/share/Kvantum '^whitesur')"
CLARO_GTK="$(claro /usr/share/themes '^whitesur')"
CLARO_WALLPAPER="$WP/BenchOS-Claro/contents/images/1920x1080.png"
EOF
# Alternativa Breeze caso o WhiteSur claro não exista
sed -i 's/^CLARO_CORES=""/CLARO_CORES="BreezeLight"/; s/^CLARO_PLASMA=""/CLARO_PLASMA="default"/; s/^CLARO_ICONES=""/CLARO_ICONES="breeze"/' /etc/benchos/tema.conf

msg "Tema estilo macOS aplicado."
