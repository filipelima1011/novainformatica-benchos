# Nova Informática BenchOS — Documento técnico para revisão

Versão do projeto: 1.0 (pré-lançamento, ainda **não construído nem testado**)
Objetivo deste documento: permitir que outra pessoa ou IA revise a arquitetura
e encontre bugs, conflitos ou omissões. O código completo está no repositório
(arquivo ZIP `novainformatica-benchos`), que deve ser enviado junto.

---

## 1. Visão geral

- Distribuição Linux de bancada para assistência técnica (diagnóstico, benchmark,
  stress, recuperação de dados, manutenção, eletrônica, office, rede).
- Base: **Ubuntu 24.04 LTS (noble), amd64**, kernel `linux-generic` (6.8 da série 24.04).
- Ambiente gráfico: **KDE Plasma 5.27** (metapacote `kubuntu-desktop`), sessão X11 padrão.
- Idioma pt-BR, teclado ABNT2, fuso `America/Fortaleza`.
- Uso principal: **ISO live via Ventoy**, com opção de instalar em HD/SSD pelo Calamares.
- Discos alvo: GPT (UEFI) e MBR (BIOS Legacy). Máquinas Intel e AMD.

## 2. Como a ISO é construída

Construção do zero, sem Cubic, rodando no **GitHub Actions** (`ubuntu-24.04`):

1. Workflow `.github/workflows/gerar-iso.yml` libera espaço no runner e executa
   `sudo -E bash build/build-iso.sh`. Entradas manuais: versão, jogos (sim/não),
   driver NVIDIA (sim/não). Também dispara em push para `main` nas pastas
   build, packages, scripts, branding, installer, ferramentas.
2. `build/build-iso.sh`:
   - instala `debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin grub-common mtools dosfstools rsync`;
   - `debootstrap --arch=amd64 noble /build/chroot http://archive.ubuntu.com/ubuntu/`;
   - monta /dev, /dev/pts, /proc, /sys; copia resolv.conf; sources.list com
     main restricted universe multiverse (+updates, +security);
   - `policy-rc.d` com `exit 101` (impede serviços de iniciar no build);
   - instala `linux-generic`, `ubuntu-standard casper discover laptop-detect os-prober network-manager locales sudo wget ca-certificates gnupg software-properties-common`;
   - grava `/etc/casper.conf` (usuário live `tecnico`, host `benchos`);
   - copia o repositório para `/tmp/benchos` no chroot e executa `scripts/install.sh`;
   - `update-initramfs -u -k all`; limpeza (apt clean, remove listas do apt,
     zera machine-id, resolv.conf vira link para o stub do systemd-resolved);
   - copia vmlinuz, initrd e Memtest86+ para a imagem;
   - `mksquashfs` (xz, BCJ x86, bloco 1M) **incluindo /boot** (necessário para a instalação);
   - gera `grub.cfg` e cria a ISO com **`grub-mkrescue`** (`-volid BENCHOS -iso-level 3`).
3. Artefatos: ISO (retenção 7 dias, sem compressão) e log `benchos-instalacao.log`.

## 3. Estrutura do repositório

```
build/build-iso.sh
packages/*.list                      (listas de pacotes por categoria)
scripts/install.sh                   (instalação e configuração no chroot)
scripts/nova-opcionais               (instaladores opcionais, menu whiptail)
scripts/nova-tema                    (alterna tema escuro/claro)
scripts/nova-drivers-auto            (detecção de drivers Wi-Fi no boot)
branding/themes/tema-macos.sh        (WhiteSur + pacote look-and-feel)
branding/themes/look-and-feel/layout.js
branding/identidade.sh               (wallpapers, SDDM, bloqueio, Plymouth, automount)
branding/gerar-wallpapers.py         (gera wallpapers e marca d'água)
branding/gerar-imagens-instalador.py (gera slides e logo provisória do instalador)
branding/wallpapers/BenchOS-Escuro|Claro/
branding/plymouth/watermark.png
installer/calamares/                 (settings.conf, modules/, branding/benchos/)
ferramentas/                         (vai para /opt/nova-ferramentas)
.github/workflows/gerar-iso.yml
```

## 4. Inicialização

Menu GRUB da ISO:
1. Nova Informatica BenchOS (`boot=casper locale=pt_BR.UTF-8 keyboard-configuration/layoutcode=br quiet splash`)
2. Modo seguro de vídeo (`nomodeset`)
3. Carregar na RAM (`toram`)
4. Memtest86+ (`linux /boot/memtest86+x64.efi` em UEFI; `linux16 /boot/memtest86+x64.bin` em BIOS)

**Secure Boot — situação atual (ponto crítico):**
- A **ISO live NÃO inicia com Secure Boot ligado**: `grub-mkrescue` gera um GRUB
  não assinado. Hoje é preciso desligar o Secure Boot para dar boot no pendrive.
- O **sistema instalado em UEFI** recebe `shim-signed` + `grub-efi-amd64-signed`
  (do Ubuntu) durante a instalação, portanto deve iniciar com Secure Boot (a validar).
- Módulos DKMS (`rtl8812au-dkms`, `bcmwl-kernel-source`, NVIDIA via DKMS) **não são
  assinados**: com Secure Boot ligado eles não carregam sem registrar uma chave MOK.

## 5. Programas pré-instalados (resumo por lista)

Instalação tolerante a falhas: cada pacote é instalado individualmente; se não
existir, é registrado em "FALHOU" no log e o build continua. Se um pacote deixar
o dpkg travado, ele é removido (`purge` ou `--force-remove-reinstreq`).

- **00-base-kde:** kubuntu-desktop, language-pack-pt, language-pack-kde-pt,
  hunspell-pt-br, firefox + firefox-l10n-pt-br (repositório oficial Mozilla,
  snap bloqueado por pin -10), flatpak + Discover flatpak, Kvantum, htop, btop,
  filelight, ksystemlog, kate, konsole.
- **10-recuperacao-dados:** testdisk (inclui photorec), gddrescue, ddrescueview,
  ddrutility, foremost, scalpel, magicrescue, recoverjpeg, extundelete, ext4magic,
  sleuthkit, safecopy, dc3dd, dcfldd, guymager, hashdeep, dislocker, clonezilla,
  partclone, gparted, partitionmanager, nwipe.
- **20-sistemas-arquivos:** ntfs-3g, exfatprogs, dosfstools, mtools, btrfs-progs,
  xfsprogs, f2fs-tools, hfsprogs, hfsplus, apfs-fuse, lvm2, mdadm, cryptsetup.
- **30-benchmark-cpu-ram:** stress-ng, s-tui, sysbench, phoronix-test-suite, 7zip,
  memtest86+, memtester, stressapptest.
- **40-gpu:** mesa-utils, mesa-vulkan-drivers, vulkan-tools, libvulkan1, glmark2
  (x11/es2/wayland), vkmark, nvtop, radeontop, intel-gpu-tools, corectrl,
  ubuntu-drivers-common, linux-firmware.
- **50-discos:** smartmontools, gsmartcontrol, nvme-cli, hdparm, sdparm, fio,
  kdiskmark, gnome-disk-utility, e2fsprogs (badblocks).
- **60-hardware:** cpu-x, inxi, lshw, hwinfo, dmidecode, lm-sensors, psensor,
  fancontrol, pciutils, usbutils, i2c-tools (decode-dimms), edid-decode, hw-probe,
  upower, acpi, powertop, fwupd, evtest, guvcview, pavucontrol, alsa-utils.
- **70-pc-repair:** efibootmgr, os-prober, grub-customizer, timeshift, chkrootkit,
  rkhunter, clamav, clamtk, chntpw, xorriso, genisoimage, lnav.
- **80-eletronica:** pulseview, sigrok-cli, gtkwave, kicad, fritzing, arduino,
  minicom, screen, picocom, cutecom, flashrom, avrdude, pipx.
- **85-office:** libreoffice (+ pt-BR, ajuda, integração KDE), pdfarranger, okular,
  evince, skanlite, ark, p7zip-full, unrar, zip, unzip.
- **90-rede:** wireshark (setuid habilitado), nmap, iperf3, netcat-openbsd,
  traceroute, mtr-tiny, ethtool, bind9-dnsutils, whois, speedtest-cli, net-tools,
  iftop, nload.
- **92-wifi-bluetooth:** linux-firmware, wireless-regdb, iw, wireless-tools, rfkill,
  wpasupplicant, bluez, bluez-obexd, bluedevil, libspa-0.2-bluetooth, modemmanager,
  usb-modeswitch, network-manager-openvpn, network-manager-l2tp.
- **93-impressoras-scanner:** cups, printer-driver-all, hplip, print-manager,
  system-config-printer, sane-utils, sane-airscan, ipp-usb.
- **94-desempenho:** intel-microcode, amd64-microcode, systemd-zram-generator.
- **95-instalador:** calamares, módulos QML (qtquick2, window2, controls2),
  grub-pc-bin, grub-efi-amd64-bin, grub2-common, efibootmgr.
- **97-drivers-dkms (instalados por último):** dkms, linux-headers-generic,
  rtl8812au-dkms. Depois: `dkms autoinstall -k <kernel da ISO>`.
- **Opcionais no build:** jogos (steam-installer, lutris, gamemode, mangohud,
  arquitetura i386) e nvidia-driver-550.

Pacotes guardados na ISO (não instalados no live):
- `/var/cache/benchos-debs/`: grub-pc, grub-efi-amd64, grub-efi-amd64-signed,
  shim-signed, mokutil (usados pelo instalador).
- `/opt/nova-ferramentas/drivers/`: bcmwl-kernel-source (instalado só se a placa for detectada).

## 6. Configurações do sistema

- `/etc/default/locale` LANG=pt_BR.UTF-8; `/etc/default/keyboard` br/abnt2;
  `/etc/localtime` → America/Fortaleza.
- zram: `zram-size = min(ram / 2, 8192)`, zstd.
- Flathub adicionado como remoto do flatpak.
- Bluetooth habilitado; serviço `nova-drivers-auto` habilitado.
- Montagem automática de discos desativada (`kded_device_automounterrc` no /etc/skel).
- Menu "Nova Informática" (categoria X-Nova) com atalhos que abrem
  `konsole --hold -e sudo <ferramenta>`: TestDisk, PhotoRec, Clonezilla,
  saúde SMART (`nova-smart`), nwipe, s-tui, stressapptest, nvtop, inxi,
  Instaladores Opcionais, log de drivers, Tema Escuro, Tema Claro.

## 7. Tema e identidade visual

- Temas WhiteSur (GPL-3, de vinceliuice), clonados do GitHub no build
  (`git clone --depth 1`, sem versão fixada): WhiteSur-kde, WhiteSur-icon-theme,
  WhiteSur-cursors, WhiteSur-gtk-theme e tema SDDM, instalados em /usr/share.
- Nomes detectados automaticamente após a instalação; se faltar algo, usa Breeze escuro.
- Pacote look-and-feel próprio `org.novainformatica.benchos` com `layout.js`:
  - barra superior: kickoff, menu global (appmenu), espaçador, monitores de CPU e
    memória, bandeja, relógio com data;
  - dock inferior centralizada, flutuante, 60% da largura, `icontasks` com
    lançadores fixados (Instalar BenchOS, Instaladores Opcionais, Dolphin, Firefox,
    Konsole, GParted, PhotoRec, GSmartControl, KDiskMark, CPU-X, s-tui, Writer,
    Configurações), separador e lixeira;
  - wallpaper padrão BenchOS-Escuro.
- `/etc/skel/.config`: kdeglobals, plasmarc, kwinrc (botões à esquerda XIA),
  kcminputrc, Kvantum, gtk-3.0/gtk-4.0, kscreenlockerrc.
- `/etc/benchos/tema.conf` guarda nomes escuro/claro para o `nova-tema`.
- Wallpapers BenchOS-Escuro e BenchOS-Claro (1920x1080 e 2560x1440) em /usr/share/wallpapers.
- SDDM: tema WhiteSur com `theme.conf.user` apontando para o wallpaper escuro.
- Plymouth: tema `benchos` derivado do `spinner`, cores 0x03060c→0x091832, marca d'água própria.
- **Logo provisória** (ícone "N" + texto) até receber a logo oficial.

## 8. Instalador gráfico (Calamares)

`/etc/calamares/settings.conf` — sequência:
- Telas: welcome → locale → keyboard → partition → users → summary
- Execução: partition → mount → unpackfs → machineid → fstab → locale → keyboard →
  localecfg → shellprocess@limpeza → users → displaymanager → networkcfg → hwclock →
  shellprocess@grub → bootloader → shellprocess@finalizar → umount
- Final: finished (reiniciar marcado pelo usuário)

Configurações principais:
- welcome: exige 30 GB de disco e 2 GB de RAM; verifica energia, root e tela.
- locale: America/Fortaleza. keyboard: grava /etc/default/keyboard.
- partition: ESP em `/boot/efi` (recomendado 512 MiB, mínimo 300 MiB), swap
  nenhum/pequeno/arquivo (padrão arquivo), padrão "apagar disco", ext4 (btrfs e xfs opcionais).
- unpackfs: `/cdrom/casper/filesystem.squashfs` → raiz.
- users: grupos adm, sudo, plugdev, dialout, lpadmin, disk, wireshark; sem senha
  de root; senhas fracas permitidas (mínimo 4); hostname `benchos-${cpu}`.
- displaymanager: sddm. bootloader: grub, `efiBootloaderId: ubuntu`, fallback EFI.
- shellprocess@limpeza: remove o atalho "Instalar" do /etc/skel e do menu.
- shellprocess@grub: em UEFI instala `grub-efi-amd64`, `grub-efi-amd64-signed`,
  `mokutil`, `shim-signed` (dpkg -i, offline); em BIOS instala `grub-pc`.
- shellprocess@finalizar: `apt-get purge calamares casper`, remove caches,
  `update-initramfs -u -k all`, `update-grub`.
- Visual: janela 1100x700, barra lateral preta/azul, stylesheet.qss, 5 slides
  (slideshowAPI 2, troca a cada 7 s), logo/ícone/boas-vindas provisórios.
- Atalho no live: `Exec=sudo -E calamares` (área de trabalho e dock).

## 9. Drivers e Wi-Fi/Bluetooth

- Intel, Realtek (rtw88/rtw89), MediaTek, Atheros/Qualcomm e Broadcom com driver
  aberto: kernel + linux-firmware.
- `nova-drivers-auto` (systemd oneshot, a cada boot): `rfkill unblock wifi/bluetooth`;
  para cada .deb em /opt/nova-ferramentas/drivers lê o campo `Modaliases`, compara
  com /sys/bus/pci e /sys/bus/usb `modalias` e instala só se houver placa compatível
  (`apt-get install ./pacote.deb`, offline). Log: /var/log/benchos-drivers.log.
- USB Realtek 8812AU/8821AU: rtl8812au-dkms compilado no build.
- NVIDIA: apenas se escolhido no build (nvidia-driver-550). GPU Manager ainda não implementado.

## 10. Instaladores opcionais (`nova-opcionais`)

Menu whiptail (roda com sudo no Konsole). Para programas pagos ou sem licença de
redistribuição, abre o site oficial com `xdg-open` como o usuário, depois lista
os arquivos recentes da pasta de downloads e instala conforme o tipo (.deb via apt,
.AppImage em /opt com atalho, .tar/.zip extraídos em /opt, .run executado).
Sites: OCCT, Geekbench, R-Studio, FurMark 2, GpuTest, Unigine Superposition,
y-cruncher, mprime, Autopsy, HardInfo2, OpenSuperClone, Ventoy, balenaEtcher,
RustDesk, Arduino IDE 2. Automáticos: Boot-Repair (PPA yannubuntu), PlatformIO
(pipx), GreenWithEnvy (Flathub).

## 11. Segurança

- Snap bloqueado; Firefox do repositório oficial da Mozilla com chave própria.
- Montagem automática de discos desligada.
- Usuário live `tecnico` com sudo sem senha (padrão do casper).
- Usuário instalado no grupo `disk` (acesso direto a discos sem sudo: prático
  para o técnico, mas reduz a segurança).
- ClamAV, rkhunter, chkrootkit incluídos.
- Secure Boot: ver seção 4.

## 12. Riscos e possíveis bugs que eu mesmo já identifiquei

1. **ISO sem Secure Boot** (grub-mkrescue não assinado). Correção prevista: montar
   a ISO com `shimx64.efi.signed` + `gcdx64.efi.signed` do Ubuntu e xorriso manual.
2. **DKMS sem assinatura** com Secure Boot ligado (rtl8812au, wl, NVIDIA DKMS).
   Alternativa para NVIDIA: `linux-modules-nvidia-550-generic` (pré-assinado).
3. `kubuntu-desktop` pode depender (e não só recomendar) de `snapd`; com o pin -10
   a instalação falharia. Verificar no primeiro build.
4. Espaço no runner do GitHub: chroot (~15–18 GB) + squashfs + ISO pode passar de
   30 GB; foi liberado espaço, mas pode ficar justo com jogos ativados.
5. Tempo de build: limite de 6 h do GitHub; estimado 1h30–3h.
6. Temas WhiteSur sem versão fixada: uma mudança no projeto pode alterar nomes
   (há fallback para Breeze).
7. Propriedades do painel no layout.js (`floating`, `minimumLength`) e widgets de
   CPU/memória dependem do Plasma 5.27; não validados.
8. `unpackfs` usa `/cdrom/casper/filesystem.squashfs`: não testado com Ventoy nem
   com a opção `toram`.
9. `nova-opcionais`: `xdg-open` executado via `sudo -u` pode não achar a sessão
   (DBus/DISPLAY) e não abrir o navegador.
10. Pacotes que podem não existir no 24.04 (tolerados): hfsplus, apfs-fuse,
    ddrutility, glmark2-wayland, network-manager-l2tp, grub-customizer.
11. Calamares com "apagar disco" como padrão: risco de apagar o disco errado.
12. Grupo `disk` e senhas fracas permitidas no instalador.

## 13. Ainda não implementado (etapas futuras)

- Nova BenchOS Launcher (painel principal com status e versão de cada ferramenta).
- Nova Hardware Center, Teste de Notebook e Nova Tech Report (PDF/TXT).
- Nova GPU Manager (detecção, driver recomendado, restauração).
- Nova Data Recovery Center com montagem somente leitura e escolha guiada de
  origem/destino (hoje só a montagem automática está desligada).
- Electronics Lab e central de rede com interface própria.
- Secure Boot na ISO live.
- Testes automáticos (boot da ISO em QEMU/OVMF no GitHub Actions) e manual completo.
- Logo oficial.

## 14. Sugestão de pedido para revisão

"Revise este projeto de distribuição Linux (Ubuntu 24.04, KDE Plasma 5.27,
casper, Calamares, construído com debootstrap no GitHub Actions). Envio o
documento técnico e o código completo em ZIP. Procure: erros de script bash,
nomes de pacotes inexistentes no Ubuntu 24.04, conflitos entre pacotes,
problemas com Secure Boot e boot UEFI/GPT, erros de configuração do Calamares
3.3, problemas no layout.js do Plasma 5.27, riscos de segurança e qualquer coisa
que impeça a ISO de ser gerada, iniciar ou instalar."
