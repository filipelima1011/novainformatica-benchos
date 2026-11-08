# NOVA INFORMÁTICA BENCHOS
**A tecnologia e você — Assistência Técnica Premium**

Distribuição Linux de bancada da Nova Informática, construída do zero sobre o
Ubuntu 24.04 LTS com KDE Plasma. A ISO é gerada na nuvem pelo GitHub e roda
pelo Ventoy, em UEFI e BIOS Legacy.

## Situação do projeto

| Etapa | Conteúdo | Situação |
|---|---|---|
| 1 | ISO base, KDE em português, pacotes, tema estilo macOS, opcionais | **Implementada, aguardando primeiro build** |
| 1b | Instalador gráfico profissional (Calamares) com apresentação BenchOS | **Implementado, aguardando primeiro build** |
| 2 | Wallpapers escuro/claro, tela de boot, login e bloqueio | **Implementado com logo provisória** |
| 3 | Nova BenchOS Launcher | A fazer |
| 4 | Hardware Center, Teste de Notebook e Tech Report | A fazer |
| 5 | GPU Manager | A fazer |
| 6 | Data Recovery Center (somente leitura por padrão) | A fazer |
| 7 | Electronics Lab, Rede, PC Repair | Pacotes já incluídos; interfaces a fazer |
| 8 | Testes automáticos e manual | A fazer |

Nada aqui foi testado em hardware real ainda. Cada item validado na bancada
será marcado neste arquivo.

## Estrutura

```
build/build-iso.sh        Constrói a ISO do zero
packages/*.list           Programas pré-instalados, por categoria
scripts/install.sh        Instala programas e configurações dentro da ISO
scripts/nova-opcionais    Instaladores opcionais (OCCT, R-Studio, Geekbench...)
branding/themes/          Tema estilo macOS (WhiteSur) e layout com dock
installer/calamares/      Instalador gráfico: etapas, visual e apresentação
branding/gerar-imagens-instalador.py  Gera os slides e a logo provisória do instalador
ferramentas/              Programas livres extras que vão para /opt/nova-ferramentas
.github/workflows/        Geração automática da ISO no GitHub
releases/                 Saída da ISO e do log (não vai para o repositório)
```

Para incluir ou tirar um programa, edite o arquivo da categoria em `packages/`.
Se um pacote não existir, o build continua e o nome aparece no log.

## Como gerar a ISO

1. No GitHub, crie um repositório **público** chamado `novainformatica-benchos`.
2. Clique em **uploading an existing file** e arraste todo o conteúdo desta pasta
   (incluindo `.github`). Clique em **Commit changes**.
3. Aba **Actions** → habilite os workflows → **Gerar ISO Nova Informatica BenchOS**
   → **Run workflow**. Escolha versão, jogos e driver NVIDIA.
4. Aguarde de 1h30 a 3h. Em **Artifacts**, baixe a ISO e o log.
5. Extraia o ZIP e copie o `.iso` para o pendrive com Ventoy.

Secure Boot: por enquanto, desative na BIOS ou registre a chave do Ventoy.

## Modo live

- Usuário: `tecnico` (sem senha, com acesso de administrador).
- Menu de boot: normal, modo seguro de vídeo, carregar na RAM e Memtest86+.
- Idioma pt-BR, teclado ABNT2, fuso America/Fortaleza.

## Instalador gráfico

No modo live, use o ícone **Instalar Nova Informática BenchOS** (área de
trabalho ou primeiro ícone da dock). Etapas: boas-vindas, idioma e fuso,
teclado, particionamento (apagar disco, lado a lado ou manual; ext4, btrfs
ou xfs), usuário e resumo. Durante a cópia, uma apresentação mostra as
centrais da BenchOS. Funciona em UEFI (GPT) e BIOS Legacy (MBR); em UEFI
instala o GRUB assinado do Ubuntu para Secure Boot. No sistema instalado, o
instalador e o modo live são removidos automaticamente.

A logo do instalador é provisória: ao receber a logo oficial, substitua
`logo.png`, `icon.png` e `welcome.png` em `installer/calamares/branding/benchos/`.

## Identidade visual

- Wallpapers **BenchOS-Escuro** (padrão) e **BenchOS-Claro**, em Full HD e 2K,
  com o nome do sistema, chip e circuitos. Gerados por `branding/gerar-wallpapers.py`.
- O mesmo wallpaper vai para a tela de bloqueio e a tela de login.
- Tela de inicialização (Plymouth) com a marca BenchOS.
- Menu **Nova Informática → Tema Escuro / Tema Claro** troca cores, janelas,
  ícones, programas e wallpaper de uma vez (comando `nova-tema escuro|claro`).

## Wi-Fi, Bluetooth e drivers

- Placas Intel, Realtek, MediaTek, Atheros/Qualcomm e Broadcom com driver aberto
  funcionam direto (kernel + linux-firmware).
- Broadcom BCM43xx que precisa do driver "wl": o serviço `nova-drivers-auto`
  detecta a placa na inicialização e instala o driver guardado na ISO, sem
  internet. Log em `/var/log/benchos-drivers.log`.
- Adaptadores USB Realtek 8812AU/8821AU: driver `rtl8812au-dkms` pré-compilado.
- Wi-Fi e Bluetooth bloqueados por software são liberados a cada boot.
- Bluetooth com áudio (PipeWire), modems 3G/4G USB, VPN OpenVPN e L2TP.

## Outras funções

- Monitores de CPU e memória na barra superior.
- Memória comprimida (zram) para máquinas com pouca RAM.
- Microcódigo Intel e AMD para estabilidade.
- Impressoras e scanners (CUPS, HPLIP, SANE) para testar periféricos.
- Discos nunca são montados automaticamente (proteção na recuperação de dados).

## Tema

Estilo macOS com os temas abertos WhiteSur (GPL-3): barra superior com menu
global e relógio, dock inferior centralizada, botões das janelas à esquerda e
variante escura. Para fixar um app na dock: botão direito no ícone →
"Fixar no gerenciador de tarefas".

## Instaladores opcionais

Menu **Nova Informática → Instaladores Opcionais**. Abre o site oficial de
cada programa (nenhum link é inventado) e instala o arquivo baixado:
OCCT, Geekbench, R-Studio, FurMark 2, GpuTest, Unigine Superposition,
y-cruncher, mprime, Autopsy, HardInfo2, OpenSuperClone, Ventoy, balenaEtcher,
RustDesk e Arduino IDE 2. Boot-Repair, PlatformIO e GreenWithEnvy são
instalados automaticamente. No modo live sem persistência, o que for
instalado se perde ao desligar.

## Limitações conhecidas

- A ISO em si (modo live) ainda não inicia com Secure Boot ligado; o sistema
  instalado em UEFI usa o GRUB assinado. Inicialização da ISO com Secure Boot
  fica para uma próxima entrega.
- Instalação a partir da opção "carregar na RAM (toram)" não foi prevista;
  use a opção normal para instalar.
- Os nomes dos temas WhiteSur são detectados no build; se o projeto mudar,
  o sistema usa o Breeze escuro como alternativa.
- Ícones fixados na dock que não existirem (ex.: nome de atalho diferente)
  simplesmente não aparecem.
- Gravador RT809H e 3DMark não têm versão Linux.
- Driver Broadcom "wl" e rtl8812au ainda não validados em placas reais.
- O ícone de CPU/memória na barra depende dos widgets do KDE 5.27; se não
  aparecerem, podem ser adicionados manualmente.
