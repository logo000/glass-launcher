# Glass Launcher

Ein Launchpad-artiger App-Starter für KDE Plasma 6, gebaut für Liquid-Glass-Effekte
(z. B. Better Blur mit Refraction). Das Fenster ist ein Plasma-Dialog ohne
Theme-Füllung, damit der KWin-Blur sichtbar bleibt.

## Funktionen

- Raster mit Seiten, Wischen per Touchpad (seitlich und hoch/runter), Mausrad und Ziehen
- Suche mit Sortierung nach Treffergüte
- Leiste mit „Alle“, „Zuletzt“, eigenen Seiten und allen Kategorien – scrollbar, Reihenfolge per Ziehen änderbar
- Eigene Seiten anlegen („+“), umbenennen und löschen; Apps per Rechtsklick hinzufügen
- Tastatur: Pfeile, Enter, Tab, Bild↑/↓, Esc
- Einstellungen: Spalten, Zeilen, Symbolgröße, Glas-Tönung, Eckenradius, Animationen

## Installation

```bash
git clone https://github.com/logo000/glass-launcher.git
kpackagetool6 --type Plasma/Applet --install glass-launcher
```

Danach per Rechtsklick auf ein Panel → „Widgets hinzufügen…“ → „Glass Launcher“.

Aktualisieren:

```bash
cd glass-launcher && git pull
kpackagetool6 --type Plasma/Applet --upgrade .
systemctl --user restart plasma-plasmashell
```

## Voraussetzungen

- KDE Plasma 6 (getestet mit 6.3, X11)
- Für den Glas-Look: ein KWin-Blur-Effekt, z. B. Better Blur

## Lizenz

GPL-2.0-or-later
