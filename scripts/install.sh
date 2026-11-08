#!/bin/bash
# ============================================================
#  Nova Informática BenchOS - install.sh
#  Instala os programas e aplica as configurações do sistema.
#  Roda DENTRO do sistema em construção (chroot), chamado pelo
#  build/build-iso.sh. Pode ser executado de novo sem duplicar nada.
# ============================================================
set -u
export DEBIAN_FRONTEND=noninteractive

BASE="${BASE:-/tmp/benchos}"
LOG=/var/log/benchos-instalacao.log
INSTALAR_JOGOS="${INSTALAR_JOGOS:-nao}"
INSTALAR_NVIDIA="${INSTALAR_NVIDIA:-nao}"
FALHAS=()

msg() { echo "[BenchOS] $*" | tee -a "$LOG"; }

[ -d "$BASE/packages" ] || { echo "ERRO: pasta de pacotes não encontrada em $BASE"; exit 1; }
msg "Início: $(date '+%d/%m/%Y %H:%M')  jogos=$INSTALAR_JOGOS  nvidia=$INSTALAR_NVIDIA"

# ------------------------------------------------------------
# Repositórios
# ------------------------------------------------------------
apt-get update >>"$LOG" 2>&1
apt-get install -y wget ca-certificates gnupg software-properties-common >>"$LOG" 2>&1

# Snap não funciona durante a construção: bloqueado.
# O Firefox vem do repositório oficial da Mozilla (pacote .deb).
mkdir -p /etc/apt/preferences.d /etc/apt/keyrings
cat > /etc/apt/preferences.d/benchos-sem-snap <<'EOF'
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF
cat > /etc/apt/preferences.d/benchos-mozilla <<'EOF'
Package: firefox*
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
if [ ! -s /etc/apt/keyrings/packages.mozilla.org.asc ]; then
  wget -q -O /etc/apt/keyrings/packages.mozilla.org.asc \
    https://packages.mozilla.org/apt/repo-signing-key.gpg \
    || msg "AVISO: não foi possível baixar a chave da Mozilla"
fi
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
  > /etc/apt/sources.list.d/mozilla.list

[ "$INSTALAR_JOGOS" = "sim" ] && dpkg --add-architecture i386

# Respostas automáticas para pacotes que fazem perguntas
debconf-set-selections <<'EOF'
wireshark-common wireshark-common/install-setuid boolean true
steam steam/question select I AGREE
steam steam/license note
EOF

apt-get update >>"$LOG" 2>&1

# ------------------------------------------------------------
# Instalação dos programas (packages/*.list)
# ------------------------------------------------------------
instalar_lista() {
  local arq="$1" nome p
  nome=$(basename "$arq" .list)
  msg ">> $nome"
  for p in $(sed 's/#.*//' "$arq"); do
    if dpkg -s "$p" >/dev/null 2>&1; then
      echo "   já instalado $p" >>"$LOG"
    elif apt-get install -y "$p" >>"$LOG" 2>&1; then
      msg "   OK      $p"
    else
      msg "   FALHOU  $p"
      FALHAS+=("$nome: $p")
      # Se o pacote deixou o sistema de pacotes travado, remove ele
      if ! dpkg --configure -a >>"$LOG" 2>&1; then
        apt-get -y purge "$p" >>"$LOG" 2>&1 || dpkg --remove --force-remove-reinstreq "$p" >>"$LOG" 2>&1
        dpkg --configure -a >>"$LOG" 2>&1
        msg "   (removido $p para manter o sistema íntegro)"
      fi
    fi
  done
}

for arq in "$BASE"/packages/*.list; do
  case "$(basename "$arq")" in
    jogos.list)  [ "$INSTALAR_JOGOS"  = "sim" ] || continue ;;
    nvidia.list) [ "$INSTALAR_NVIDIA" = "sim" ] || continue ;;
  esac
  instalar_lista "$arq"
done

# Compila os drivers DKMS para o kernel que vai na ISO
KVER=$(ls /lib/modules | sort -V | tail -1)
if command -v dkms >/dev/null 2>&1 && [ -n "$KVER" ]; then
  dkms autoinstall -k "$KVER" >>"$LOG" 2>&1 && msg "Drivers DKMS compilados para $KVER" \
    || msg "AVISO: algum driver DKMS não compilou (veja o log)"
fi

# Drivers Wi-Fi instalados só se a placa existir (Broadcom BCM43xx "wl")
mkdir -p /opt/nova-ferramentas/drivers
chown _apt /opt/nova-ferramentas/drivers 2>/dev/null || true
(cd /opt/nova-ferramentas/drivers && apt-get download bcmwl-kernel-source >>"$LOG" 2>&1) \
  && msg "OK      driver Broadcom guardado para detecção automática" \
  || { msg "FALHOU  driver Broadcom"; FALHAS+=("wifi: bcmwl-kernel-source"); }
chown -R root:root /opt/nova-ferramentas/drivers

flatpak remote-add --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo >>"$LOG" 2>&1 || true

# ------------------------------------------------------------
# Idioma, teclado ABNT2 e fuso horário (Fortaleza)
# ------------------------------------------------------------
locale-gen pt_BR.UTF-8 >>"$LOG" 2>&1
echo 'LANG=pt_BR.UTF-8' > /etc/default/locale
cat > /etc/default/keyboard <<'EOF'
XKBMODEL="abnt2"
XKBLAYOUT="br"
XKBVARIANT=""
XKBOPTIONS=""
EOF
ln -sf /usr/share/zoneinfo/America/Fortaleza /etc/localtime
echo "America/Fortaleza" > /etc/timezone

# ------------------------------------------------------------
# Ferramentas extras e instaladores opcionais
# ------------------------------------------------------------
mkdir -p /opt/nova-ferramentas
cp -r "$BASE/ferramentas/." /opt/nova-ferramentas/ 2>/dev/null || true
install -m 755 "$BASE/scripts/nova-opcionais" /usr/local/bin/nova-opcionais
install -m 755 "$BASE/scripts/nova-tema" /usr/local/bin/nova-tema
install -m 755 "$BASE/scripts/nova-drivers-auto" /usr/local/sbin/nova-drivers-auto

cat > /etc/systemd/system/nova-drivers-auto.service <<'EOF'
[Unit]
Description=Nova Informatica BenchOS - libera Wi-Fi/Bluetooth e detecta drivers
After=local-fs.target systemd-modules-load.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/nova-drivers-auto
TimeoutStartSec=600

[Install]
WantedBy=multi-user.target
EOF
systemctl enable nova-drivers-auto.service >>"$LOG" 2>&1
systemctl enable bluetooth.service >>"$LOG" 2>&1 || true

# Memória comprimida (zram): mais fôlego em máquinas com pouca RAM
mkdir -p /etc/systemd
cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
EOF

cat > /usr/local/bin/nova-smart <<'EOF'
#!/bin/bash
# Saúde rápida de todos os discos
for d in /dev/sd? /dev/nvme?n1; do
  [ -e "$d" ] || continue
  echo "===================== $d ====================="
  smartctl -H -i "$d"
done
EOF
chmod +x /usr/local/bin/nova-smart

# ------------------------------------------------------------
# Menu "Nova Informática" (ferramentas que rodam no terminal)
# ------------------------------------------------------------
mkdir -p /usr/share/desktop-directories /etc/xdg/menus/applications-merged
cat > /usr/share/desktop-directories/nova.directory <<'EOF'
[Desktop Entry]
Type=Directory
Name=Nova Informática
Icon=applications-system
EOF
cat > /etc/xdg/menus/applications-merged/nova.menu <<'EOF'
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN" "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
<Menu>
  <Name>Applications</Name>
  <Menu>
    <Name>Nova Informática</Name>
    <Directory>nova.directory</Directory>
    <Include><Category>X-Nova</Category></Include>
  </Menu>
</Menu>
EOF

atalho() {   # atalho "Nome" "comando" "ícone"
  local id
  id=$(echo "$1" | tr ' A-Z' '-a-z' | tr -cd 'a-z0-9-')
  cat > "/usr/share/applications/nova-$id.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$1
Exec=konsole --hold -e sudo $2
Icon=$3
Terminal=false
Categories=X-Nova;
EOF
}
atalho "TestDisk - Recuperar Particao"   "testdisk"       "drive-harddisk"
atalho "PhotoRec - Recuperar Arquivos"   "photorec"       "folder-documents"
atalho "Clonezilla - Clonar Disco"       "clonezilla"     "drive-harddisk"
atalho "Saude dos Discos (SMART)"        "nova-smart"     "drive-harddisk"
atalho "nwipe - Apagar Disco"            "nwipe"          "edit-delete"
atalho "Stress de CPU (s-tui)"           "s-tui"          "utilities-system-monitor"
atalho "Stress de Memoria (stressapptest)" "stressapptest -s 600" "media-flash"
atalho "Monitor de GPU (nvtop)"          "nvtop"          "video-display"
atalho "Informacoes do Sistema (inxi)"   "inxi -Fxz"      "computer"
atalho "Instaladores Opcionais (OCCT e outros)" "nova-opcionais" "system-software-install"
atalho "Log de Drivers Wi-Fi e Bluetooth" "less /var/log/benchos-drivers.log" "network-wireless"

tema_atalho() {   # sem sudo: o tema é do usuário
  cat > "/usr/share/applications/nova-tema-$1.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Tema $2
Comment=Aplicar o tema $2 da BenchOS
Exec=nova-tema $1
Icon=$3
Terminal=false
Categories=X-Nova;
EOF
}
tema_atalho escuro "Escuro" "weather-clear-night"
tema_atalho claro  "Claro"  "weather-clear"

# ------------------------------------------------------------
# Instalador gráfico (Calamares) com a identidade BenchOS
# ------------------------------------------------------------
rm -rf /etc/calamares
mkdir -p /etc/calamares
cp -r "$BASE/installer/calamares/." /etc/calamares/

# Pacotes do GRUB guardados na ISO: o instalador escolhe o certo
# (UEFI com Secure Boot ou BIOS Legacy) sem precisar de internet
rm -rf /var/cache/benchos-debs
mkdir -p /var/cache/benchos-debs
chown _apt /var/cache/benchos-debs 2>/dev/null || true
(cd /var/cache/benchos-debs && apt-get download grub-pc grub-efi-amd64 \
  grub-efi-amd64-signed shim-signed mokutil >>"$LOG" 2>&1) \
  && msg "OK      pacotes do GRUB para o instalador" \
  || { msg "FALHOU  pacotes do GRUB para o instalador"; FALHAS+=("instalador: pacotes do GRUB"); }

cat > /usr/share/applications/benchos-instalar.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Instalar Nova Informática BenchOS
Comment=Instalar o sistema no HD ou SSD deste computador
Exec=sudo -E calamares
Icon=/etc/calamares/branding/benchos/icon.png
Terminal=false
Categories=System;X-Nova;
EOF
mkdir -p /etc/skel/Desktop
install -m 755 /usr/share/applications/benchos-instalar.desktop /etc/skel/Desktop/benchos-instalar.desktop

# ------------------------------------------------------------
# Tema estilo macOS com dock
# ------------------------------------------------------------
bash "$BASE/branding/themes/tema-macos.sh" || msg "AVISO: o tema não foi aplicado por completo"
bash "$BASE/branding/identidade.sh"        || msg "AVISO: a identidade visual não foi aplicada por completo"

# ------------------------------------------------------------
# Resumo
# ------------------------------------------------------------
apt-get clean
msg "Fim: $(date '+%d/%m/%Y %H:%M')"
if [ ${#FALHAS[@]} -gt 0 ]; then
  msg "Pacotes não instalados (${#FALHAS[@]}):"
  printf '   - %s\n' "${FALHAS[@]}" | tee -a "$LOG"
else
  msg "Todos os pacotes foram instalados."
fi
exit 0
