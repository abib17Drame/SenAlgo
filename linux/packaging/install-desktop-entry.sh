#!/usr/bin/env bash
# Intègre SenAlgo au bureau : entrée dans le menu des applications et icône
# dans le dock.
#
# Pourquoi ce script est nécessaire : sous GNOME, l'icône affichée dans le
# dock et le sélecteur de fenêtres ne provient pas de l'appel GTK
# `gtk_window_set_default_icon`. GNOME rattache la fenêtre à un fichier
# .desktop via l'identifiant d'application ; sans ce fichier, il affiche une
# icône générique, quelle que soit l'icône posée par le programme.
#
# Usage :
#   ./install-desktop-entry.sh [chemin/vers/le/bundle]
#
# Sans argument, le bundle release construit localement est utilisé.

set -euo pipefail

APP_ID="io.github.abib17drame.SenAlgo"
RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE="${1:-$RACINE/build/linux/x64/release/bundle}"
BINAIRE="$BUNDLE/senalgo"

if [[ ! -x "$BINAIRE" ]]; then
  echo "Exécutable introuvable : $BINAIRE" >&2
  echo "Construire d'abord avec :  flutter build linux --release" >&2
  exit 1
fi

DEST_APPS="$HOME/.local/share/applications"
DEST_ICONES="$HOME/.local/share/icons/hicolor"

# L'icône est installée dans plusieurs tailles : le thème hicolor choisit la
# plus proche du besoin, et une seule taille donnerait un rendu flou ailleurs.
for taille in 16 32 48 64 128 256; do
  mkdir -p "$DEST_ICONES/${taille}x${taille}/apps"
  if command -v convert >/dev/null 2>&1; then
    convert "$RACINE/assets/icon/icon.png" -resize "${taille}x${taille}" \
      "$DEST_ICONES/${taille}x${taille}/apps/$APP_ID.png"
  else
    python3 -c "
from PIL import Image
Image.open('$RACINE/assets/icon/icon.png').convert('RGB').resize(
    ($taille, $taille), Image.LANCZOS).save(
    '$DEST_ICONES/${taille}x${taille}/apps/$APP_ID.png')"
  fi
done

mkdir -p "$DEST_APPS"
sed "s|@EXEC@|$BINAIRE|" \
  "$RACINE/linux/packaging/$APP_ID.desktop" > "$DEST_APPS/$APP_ID.desktop"
chmod 644 "$DEST_APPS/$APP_ID.desktop"

# Sans rafraîchissement des caches, GNOME continue d'afficher l'ancien état.
command -v update-desktop-database >/dev/null 2>&1 &&
  update-desktop-database "$DEST_APPS" || true
command -v gtk-update-icon-cache >/dev/null 2>&1 &&
  gtk-update-icon-cache -f -t "$DEST_ICONES" 2>/dev/null || true

echo "Installé :"
echo "  entrée   $DEST_APPS/$APP_ID.desktop"
echo "  icônes   $DEST_ICONES/{16,32,48,64,128,256}x*/apps/$APP_ID.png"
echo "  exécute  $BINAIRE"
