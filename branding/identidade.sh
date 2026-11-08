#!/bin/bash
# ============================================================
#  Nova Informática BenchOS - identidade visual
#  Wallpapers (escuro padrão e claro), tela de bloqueio, tela de
#  login, tela de inicialização (Plymouth) e proteção de discos.
#  Roda dentro do chroot, depois do tema-macos.sh.
# ============================================================
set -u
export DEBIAN_FRONTEND=noninteractive
LOG=/var/log/benchos-instalacao.log
DIR="$(cd "$(dirname "$0")" && pwd)"
SKEL=/etc/skel/.config
WP=/usr/share/wallpapers
ESCURO="$WP/BenchOS-Escuro/contents/images/1920x1080.png"

msg() { echo "[Identidade] $*" | tee -a "$LOG"; }

# ---------- Wallpapers ----------
for t in BenchOS-Escuro BenchOS-Claro; do
  rm -rf "${WP:?}/$t"
  cp -r "$DIR/wallpapers/$t" "$WP/$t"
done
msg "Wallpapers instalados (escuro como padrão)"

# ---------- Tela de bloqueio ----------
mkdir -p "$SKEL"
cat > "$SKEL/kscreenlockerrc" <<EOF
[Greeter][Wallpaper][org.kde.image][General]
Image=file://$ESCURO
PreviewImage=file://$ESCURO
EOF

# ---------- Tela de login (SDDM) ----------
TEMA_SDDM=$(sed -n 's/^Current=//p' /etc/sddm.conf.d/benchos.conf 2>/dev/null)
if [ -n "$TEMA_SDDM" ] && [ -d "/usr/share/sddm/themes/$TEMA_SDDM" ]; then
  printf '[General]\nbackground=%s\n' "$ESCURO" > "/usr/share/sddm/themes/$TEMA_SDDM/theme.conf.user"
  msg "Fundo da tela de login: $TEMA_SDDM"
else
  for t in breeze; do
    [ -d "/usr/share/sddm/themes/$t" ] && printf '[General]\nbackground=%s\n' "$ESCURO" \
      > "/usr/share/sddm/themes/$t/theme.conf.user"
  done
fi

# ---------- Tela de inicialização (Plymouth) ----------
apt-get install -y plymouth plymouth-theme-spinner >>"$LOG" 2>&1
BASEPLY=/usr/share/plymouth/themes/spinner
PLY=/usr/share/plymouth/themes/benchos
if [ -f "$BASEPLY/spinner.plymouth" ]; then
  rm -rf "$PLY"; cp -r "$BASEPLY" "$PLY"
  mv "$PLY/spinner.plymouth" "$PLY/benchos.plymouth"
  sed -i -e 's/^Name=.*/Name=Nova Informatica BenchOS/' \
         -e 's#/themes/spinner#/themes/benchos#g' \
         -e 's/^BackgroundStartColor=.*/BackgroundStartColor=0x03060c/' \
         -e 's/^BackgroundEndColor=.*/BackgroundEndColor=0x091832/' \
         "$PLY/benchos.plymouth"
  cp "$DIR/plymouth/watermark.png" "$PLY/watermark.png"
  update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
    "$PLY/benchos.plymouth" 200 >>"$LOG" 2>&1
  update-alternatives --set default.plymouth "$PLY/benchos.plymouth" >>"$LOG" 2>&1 \
    && msg "Tela de inicialização BenchOS ativada" || msg "AVISO: Plymouth não ativado"
else
  msg "AVISO: tema base do Plymouth não encontrado"
fi

# ---------- Proteção de discos ----------
# Nenhum disco é montado sozinho: importante na recuperação de dados,
# para não gravar nada no disco do cliente sem o técnico decidir.
cat > "$SKEL/kded_device_automounterrc" <<'EOF'
[General]
AutomountEnabled=false
AutomountOnLogin=false
AutomountOnPlugin=false
EOF
msg "Montagem automática de discos desativada"
