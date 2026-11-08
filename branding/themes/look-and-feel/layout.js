// ============================================================
//  Nova Informática BenchOS - layout estilo macOS
//  Barra superior (menu, menu global, bandeja, relógio)
//  + dock inferior centralizada com os aplicativos fixados.
//  Para fixar outro app na dock: clique com o botão direito
//  nele e escolha "Fixar no gerenciador de tarefas".
// ============================================================

// ---------- Wallpaper padrão (escuro) ----------
var areas = desktops();
for (var i = 0; i < areas.length; i++) {
    areas[i].wallpaperPlugin = "org.kde.image";
    areas[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    areas[i].writeConfig("Image", "file:///usr/share/wallpapers/BenchOS-Escuro/contents/images/1920x1080.png");
}

// ---------- Barra superior ----------
var topo = new Panel;
topo.location = "top";
topo.height = Math.round(gridUnit * 1.6);
topo.addWidget("org.kde.plasma.kickoff");
topo.addWidget("org.kde.plasma.appmenu");
topo.addWidget("org.kde.plasma.panelspacer");
topo.addWidget("org.kde.plasma.systemmonitor.cpu");
topo.addWidget("org.kde.plasma.systemmonitor.memory");
topo.addWidget("org.kde.plasma.systemtray");
var relogio = topo.addWidget("org.kde.plasma.digitalclock");
relogio.currentConfigGroup = ["Appearance"];
relogio.writeConfig("showDate", true);

// ---------- Dock inferior ----------
var dock = new Panel;
dock.location = "bottom";
dock.height = Math.round(gridUnit * 3.6);
dock.alignment = "center";
dock.floating = true;
var tela = screenGeometry(dock.screen);
var largura = Math.round(tela.width * 0.6);
dock.minimumLength = largura;
dock.maximumLength = largura;

var tarefas = dock.addWidget("org.kde.plasma.icontasks");
tarefas.currentConfigGroup = ["General"];
tarefas.writeConfig("launchers", [
    "applications:benchos-instalar.desktop",
    "applications:nova-instaladores-opcionais-occt-e-outros.desktop",
    "applications:org.kde.dolphin.desktop",
    "applications:firefox.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:gparted.desktop",
    "applications:nova-photorec-recuperar-arquivos.desktop",
    "applications:gsmartcontrol.desktop",
    "applications:kdiskmark.desktop",
    "applications:cpu-x.desktop",
    "applications:nova-stress-de-cpu-s-tui.desktop",
    "applications:libreoffice-writer.desktop",
    "applications:systemsettings.desktop"
]);
tarefas.writeConfig("showOnlyCurrentDesktop", false);

dock.addWidget("org.kde.plasma.marginsseparator");
dock.addWidget("org.kde.plasma.trash");
