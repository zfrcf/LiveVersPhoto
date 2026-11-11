#!/usr/bin/env bash
# Installe sur ce PC Linux les outils qui compilent, signent et installent l'app :
#   - Swift (via swiftly, l'installateur officiel de swift.org)
#   - xtool (remplaçant d'Xcode pour Linux), dans ~/.local/bin
# Rien n'est installé en root. À lancer une seule fois :  bash installer-outils.sh
set -euo pipefail

ARCH="$(uname -m)"
mkdir -p "$HOME/.local/bin"

echo "== 1/2  xtool =="
if [ ! -x "$HOME/.local/bin/xtool" ]; then
    curl -fL --progress-bar "https://github.com/xtool-org/xtool/releases/latest/download/xtool-${ARCH}.AppImage" \
         -o "$HOME/.local/bin/xtool.part"
    mv "$HOME/.local/bin/xtool.part" "$HOME/.local/bin/xtool"
    chmod +x "$HOME/.local/bin/xtool"
fi

echo "== 2/2  Swift (swiftly) =="
if ! command -v swift >/dev/null 2>&1; then
    TMP="$(mktemp -d)"
    ( cd "$TMP"
      curl -fLO "https://download.swift.org/swiftly/linux/swiftly-${ARCH}.tar.gz"
      tar zxf "swiftly-${ARCH}.tar.gz"
      # --platform : nécessaire sur les dérivés d'Ubuntu que swiftly ne reconnaît pas.
      ./swiftly init --assume-yes --quiet-shell-followup --skip-install --platform ubuntu24.04 )
    rm -rf "$TMP"
    # shellcheck disable=SC1091
    . "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"
    swiftly install 6.4 --use --assume-yes   # version attendue par xtool
fi
swift --version

cat <<'FIN'

Outils installés. Si swiftly a affiché une commande « sudo apt-get install … »
(bibliothèques manquantes), lancez-la. Si xtool refuse de démarrer (FUSE),
lancez :  sudo apt-get install libfuse2

Ouvrez un NOUVEAU terminal, puis suivez LISEZMOI.md à partir de l'étape 2.
FIN
