#!/usr/bin/env bash
# Installe Godot (éditeur headless) et, si INSTALL_TEMPLATES=1, les export templates.
# Usage : GODOT_VERSION=4.7.2 scripts/ci/setup_godot.sh   -> binaire dans $HOME/godot/godot
set -euo pipefail
V="${GODOT_VERSION:-4.7.2}"
BASE="https://github.com/godotengine/godot-builds/releases/download/${V}-stable"
DIR="${HOME}/godot"
mkdir -p "$DIR"
if [ ! -x "$DIR/godot" ]; then
  curl -fsSL -o "$DIR/godot.zip" "${BASE}/Godot_v${V}-stable_linux.x86_64.zip"
  unzip -q -o "$DIR/godot.zip" -d "$DIR"
  mv "$DIR/Godot_v${V}-stable_linux.x86_64" "$DIR/godot"
  chmod +x "$DIR/godot"
fi
if [ "${INSTALL_TEMPLATES:-0}" = "1" ]; then
  T="${HOME}/.local/share/godot/export_templates/${V}.stable"
  if [ ! -d "$T" ]; then
    curl -fsSL -o "$DIR/templates.tpz" "${BASE}/Godot_v${V}-stable_export_templates.tpz"
    mkdir -p "$T" "$DIR/tpl"
    unzip -q -o "$DIR/templates.tpz" -d "$DIR/tpl"
    mv "$DIR"/tpl/templates/* "$T"/
  fi
fi
"$DIR/godot" --headless --version
if [ -n "${GITHUB_PATH:-}" ]; then echo "$DIR" >> "$GITHUB_PATH"; fi
