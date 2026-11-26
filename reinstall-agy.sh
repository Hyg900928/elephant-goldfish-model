#!/usr/bin/env bash
# Place this script in the root of the Elephant-Goldfish Model repository.
set -euo pipefail

PLUGIN_NAME="egm"
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
INSTALL_DIR="$HOME/.gemini/config/plugins/$PLUGIN_NAME"

fail() { printf '[agy] ERROR: %s\n' "$*" >&2; exit 1; }

command -v agy >/dev/null 2>&1 || fail 'agy is not on PATH.'
[[ -f "$PLUGIN_DIR/plugin.json" ]] || fail "Missing plugin.json in $PLUGIN_DIR"
for folder in skills agents resources docs; do
    [[ -d "$PLUGIN_DIR/$folder" ]] || fail "Missing directory: $folder"
done

# Avoid uninstalling the source itself if this script was misplaced.
if [[ -d "$INSTALL_DIR" && "$(cd "$INSTALL_DIR" && pwd -P)" == "$PLUGIN_DIR" ]]; then
    fail 'Run this script from the source repository, not the installed plugin directory.'
fi

# Validate the source before uninstalling the existing copy.
printf '[agy] Validating %s...\n' "$PLUGIN_DIR"
agy plugin validate "$PLUGIN_DIR"

if [[ -e "$INSTALL_DIR" || -L "$INSTALL_DIR" ]]; then
    printf '[agy] Uninstalling %s...\n' "$PLUGIN_NAME"
    agy plugin uninstall "$PLUGIN_NAME"
fi

printf '[agy] Installing %s from %s...\n' "$PLUGIN_NAME" "$PLUGIN_DIR"
agy plugin install "$PLUGIN_DIR"

printf '\n[agy] Installation complete. Open a new agy session.\n'
