#!/usr/bin/env python3
"""Integra HowToPlayView ao MainMenuView existente, sem reescrever o menu.

Uso, na raiz do repositorio DeckSpawn:
    python3 /caminho/para/add_how_to_play.py .

Deixe HowToPlayView.swift ao lado deste script.
"""
from pathlib import Path
import shutil
import sys

if len(sys.argv) != 2:
    sys.exit("Uso: python3 add_how_to_play.py /caminho/para/DeckSpawn")

root = Path(sys.argv[1]).expanduser().resolve()
menu = root / "Features" / "Main" / "Views" / "MainMenuView.swift"
new_view = Path(__file__).resolve().with_name("HowToPlayView.swift")
destination = menu.with_name("HowToPlayView.swift")

if not menu.is_file():
    sys.exit(f"Nao encontrei o MainMenuView.swift em: {menu}")
if not new_view.is_file():
    sys.exit(f"Nao encontrei o HowToPlayView.swift ao lado deste script: {new_view}")

src = menu.read_text(encoding="utf-8")
if "showingHowToPlay" in src:
    sys.exit("A integracao ja parece existir. Nenhuma alteracao foi feita.")

changes = [
    (
        '    @State private var showingCollection = false',
        '    @State private var showingCollection = false\n\n'
        '    @State private var showingHowToPlay = false',
    ),
    (
        '        .sheet(isPresented: $showingSettings) {\n',
        '        .sheet(isPresented: $showingHowToPlay) {\n'
        '            HowToPlayView()\n'
        '        }\n\n'
        '        .sheet(isPresented: $showingSettings) {\n',
    ),
    (
        '            menuButton(\n\n'
        '                title: "CONFIGURAÇÕES",',
        '            menuButton(\n\n'
        '                title: LocalizedStringKey(\n'
        '                    DeckSpawnL10n.languageCode.hasPrefix("pt") ? "COMO JOGAR" : "HOW TO PLAY"\n'
        '                ),\n'
        '                subtitle: LocalizedStringKey(\n'
        '                    DeckSpawnL10n.languageCode.hasPrefix("pt")\n'
        '                        ? "Aprenda as regras e domine as batalhas"\n'
        '                        : "Learn the rules and master the battles"\n'
        '                ),\n'
        '                icon: "book.closed.fill",\n'
        '                accent: violet,\n'
        '                action: { showingHowToPlay = true }\n\n'
        '            )\n\n'
        '            menuButton(\n\n'
        '                title: "CONFIGURAÇÕES",',
    ),
]

for old, new in changes:
    count = src.count(old)
    if count != 1:
        sys.exit(f"Estrutura diferente da versao publica do menu (ancora com {count} ocorrencias): {old!r}. Nenhum arquivo foi alterado.")
    src = src.replace(old, new, 1)

if destination.exists() and destination.read_bytes() != new_view.read_bytes():
    sys.exit(f"Ja existe um HowToPlayView.swift diferente em {destination}. Nenhum arquivo foi alterado.")

backup = menu.with_suffix(".swift.before_how_to_play.bak")
if backup.exists():
    sys.exit(f"Ja existe um backup em {backup}; alteracoes nao aplicadas para evitar sobrescrita.")
shutil.copy2(menu, backup)
menu.write_text(src, encoding="utf-8")
shutil.copy2(new_view, destination)
print(f"OK: MainMenuView.swift atualizado: {menu}")
print(f"OK: HowToPlayView.swift adicionado: {destination}")
print(f"Backup: {backup}")
print("Abra o Xcode e confirme que o novo Swift file pertence ao target CardArenaAR.")
