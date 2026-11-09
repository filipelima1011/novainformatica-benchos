#!/bin/bash
# ============================================================
#  Nova Informática BenchOS - build-iso.sh
#  Constrói a ISO do zero sobre o Ubuntu 24.04 LTS (noble).
#  Uso (como root, na raiz do repositório):
#      sudo bash build/build-iso.sh
#  No GitHub Actions isso é feito automaticamente.
# ============================================================
set -euo pipefail

VERSAO="${VERSAO:-1.0}"
NOME="NovaInformatica-BenchOS"
SUITE="noble"
MIRROR="http://archive.ubuntu.com/ubuntu/"
PROJETO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-/build}"
CHROOT="$WORK/chroot"
IMAGE="$WORK/image"
SAIDA="$PROJETO/releases"

msg() { echo; echo "==== $* ===="; }
[ "$(id -u)" -eq 0 ] || { echo "ERRO: execute como root (sudo)."; exit 1; }

desmontar() {
  for d in dev/pts dev proc sys; do umount -lf "$CHROOT/$d" 2>/dev/null || true; done
}

msg "1/8 Ferramentas de construção"
apt-get update
apt-get install -y debootstrap squashfs-tools xorriso grub-pc-bin \
  grub-efi-amd64-bin grub-common mtools dosfstools rsync

desmontar
rm -rf "$WORK"
mkdir -p "$CHROOT" "$IMAGE/casper" "$IMAGE/boot/grub" "$IMAGE/.disk" "$SAIDA"

msg "2/8 Base mínima do Ubuntu 24.04"
debootstrap --arch=amd64 "$SUITE" "$CHROOT" "$MIRROR"

mount --bind /dev     "$CHROOT/dev"
mount --bind /dev/pts "$CHROOT/dev/pts"
mount -t proc  proc   "$CHROOT/proc"
mount -t sysfs sys    "$CHROOT/sys"
trap desmontar EXIT

cp -L /etc/resolv.conf "$CHROOT/etc/resolv.conf"
echo "benchos" > "$CHROOT/etc/hostname"
cat > "$CHROOT/etc/apt/sources.list" <<EOF
deb $MIRROR $SUITE main restricted universe multiverse
deb $MIRROR $SUITE-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ $SUITE-security main restricted universe multiverse
EOF
printf '#!/bin/sh\nexit 101\n' > "$CHROOT/usr/sbin/policy-rc.d"
chmod +x "$CHROOT/usr/sbin/policy-rc.d"

msg "3/8 Kernel e sistema live"
chroot "$CHROOT" /bin/bash -c '
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y linux-generic
apt-get install -y ubuntu-standard casper discover laptop-detect os-prober \
  network-manager locales sudo wget ca-certificates gnupg software-properties-common
'

# Usuário do modo live
cat > "$CHROOT/etc/casper.conf" <<'EOF'
export USERNAME="tecnico"
export USERFULLNAME="Tecnico Nova Informatica"
export HOST="benchos"
export BUILD_SYSTEM="Ubuntu"
export FLAVOUR="BenchOS"
EOF

msg "4/8 Programas, configurações e tema"
rsync -a --exclude .git --exclude releases "$PROJETO/" "$CHROOT/tmp/benchos/"
chroot "$CHROOT" env BASE=/tmp/benchos \
  INSTALAR_JOGOS="${INSTALAR_JOGOS:-nao}" INSTALAR_NVIDIA="${INSTALAR_NVIDIA:-nao}" \
  bash /tmp/benchos/scripts/install.sh
cp "$CHROOT/var/log/benchos-instalacao.log" "$SAIDA/" || true

chroot "$CHROOT" update-initramfs -u -k all

msg "5/8 Limpeza"
rm -rf "$CHROOT/tmp/benchos" "$CHROOT/usr/sbin/policy-rc.d"
chroot "$CHROOT" apt-get clean
rm -rf "$CHROOT/var/lib/apt/lists/"* "$CHROOT/tmp/"*
truncate -s 0 "$CHROOT/etc/machine-id"
ln -sf ../run/systemd/resolve/stub-resolv.conf "$CHROOT/etc/resolv.conf"

msg "6/8 Kernel, initrd e Memtest86+"
cp "$(ls "$CHROOT"/boot/vmlinuz-* | sort -V | tail -1)" "$IMAGE/casper/vmlinuz"
cp "$(ls "$CHROOT"/boot/initrd.img-* | sort -V | tail -1)" "$IMAGE/casper/initrd"
cp "$CHROOT"/boot/memtest86+* "$IMAGE/boot/" 2>/dev/null || echo "AVISO: Memtest86+ não encontrado"

desmontar
trap - EXIT

msg "7/8 Compactando o sistema"
mksquashfs "$CHROOT" "$IMAGE/casper/filesystem.squashfs" \
  -comp xz -Xbcj x86 -b 1M -noappend
du -sx --block-size=1 "$CHROOT" | cut -f1 > "$IMAGE/casper/filesystem.size"
echo "Nova Informatica BenchOS $VERSAO - Ubuntu 24.04 LTS amd64" > "$IMAGE/.disk/info"

OPC="boot=casper locale=pt_BR.UTF-8 keyboard-configuration/layoutcode=br"
cat > "$IMAGE/boot/grub/grub.cfg" <<EOF
set default=0
set timeout=10
insmod all_video

menuentry "Nova Informatica BenchOS $VERSAO" {
  linux /casper/vmlinuz $OPC quiet splash ---
  initrd /casper/initrd
}
menuentry "BenchOS - Modo seguro de video (nomodeset)" {
  linux /casper/vmlinuz $OPC nomodeset ---
  initrd /casper/initrd
}
menuentry "BenchOS - Carregar tudo na memoria RAM (toram)" {
  linux /casper/vmlinuz $OPC toram quiet splash ---
  initrd /casper/initrd
}
if [ "\$grub_platform" = "efi" ]; then
  if [ -f /boot/memtest86+x64.efi ]; then
    menuentry "Teste de memoria RAM (Memtest86+)" {
      linux /boot/memtest86+x64.efi
    }
  fi
else
  if [ -f /boot/memtest86+x64.bin ]; then
    menuentry "Teste de memoria RAM (Memtest86+)" {
      linux16 /boot/memtest86+x64.bin
    }
  fi
fi
EOF

msg "8/8 Gerando a ISO (UEFI + BIOS Legacy)"
grub-mkrescue -o "$SAIDA/$NOME-$VERSAO.iso" "$IMAGE" -- -volid "BENCHOS" -compliance iso_9660_level=3
ls -lh "$SAIDA"
echo "ISO pronta: $SAIDA/$NOME-$VERSAO.iso"
