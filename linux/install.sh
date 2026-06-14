#!/bin/bash
set -e

SELF="$(readlink -f "$0")"
HERE="$(dirname "$SELF")"
APP_ID="io.github.KwasiAsante.PokeTeamDex"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

mkdir -p "$DATA_HOME/icons/hicolor/256x256/apps" "$DATA_HOME/applications"

cp "$HERE/$APP_ID.png" "$DATA_HOME/icons/hicolor/256x256/apps/$APP_ID.png"

sed "s|Exec=poke_team_dex|Exec=$HERE/poke_team_dex|" \
  "$HERE/$APP_ID.desktop" > "$DATA_HOME/applications/$APP_ID.desktop"

gtk-update-icon-cache "$DATA_HOME/icons/hicolor" 2>/dev/null || true

printf 'Installed! Launch PokeTeamDex from your app menu, or run:\n  %s/poke_team_dex\n' "$HERE"
