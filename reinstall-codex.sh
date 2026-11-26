#!/usr/bin/env bash
# Place this script in the root of the Elephant-Goldfish Model repository.
set -euo pipefail

PLUGIN_NAME="egm"
MARKETPLACE_NAME="egm"
PLUGIN_ID="${PLUGIN_NAME}@${MARKETPLACE_NAME}"
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

fail() { printf '[codex] ERROR: %s\n' "$*" >&2; exit 1; }

command -v codex >/dev/null 2>&1 || fail 'codex is not on PATH.'
command -v python3 >/dev/null 2>&1 || fail 'python3 is required to read CLI JSON output.'

# Check local sources before changing the installed plugin.
python3 - "$PLUGIN_DIR" "$PLUGIN_NAME" "$MARKETPLACE_NAME" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
plugin_name, marketplace_name = sys.argv[2:]
try:
    marketplace = json.loads((root / '.agents/plugins/marketplace.json').read_text())
    manifest = json.loads((root / '.codex-plugin/plugin.json').read_text())
    assert marketplace['name'] == marketplace_name, 'Unexpected marketplace name'
    assert any(p['name'] == plugin_name for p in marketplace['plugins']), 'Missing EGM marketplace entry'
    assert manifest['name'] == plugin_name, 'Unexpected plugin name'
    for folder in ('skills', 'agents', 'resources', 'docs'):
        assert (root / folder).is_dir(), f'Missing directory: {folder}'
except (OSError, ValueError, KeyError, TypeError, AssertionError) as exc:
    sys.exit(f'[codex] Invalid EGM source at {root}: {exc}')
PY

remove_if_installed() {
    local listing installed
    listing="$(codex plugin list --marketplace "$MARKETPLACE_NAME" --json)"
    installed="$(printf '%s\n' "$listing" | python3 -c '
import json, sys
items = json.load(sys.stdin)["installed"]
print("yes" if any(p.get("pluginId") == sys.argv[1] or
    (p.get("name") == sys.argv[2] and p.get("marketplaceName") == sys.argv[3])
    for p in items) else "no")
' "$PLUGIN_ID" "$PLUGIN_NAME" "$MARKETPLACE_NAME")"
    if [[ "$installed" == yes ]]; then
        printf '[codex] Uninstalling %s...\n' "$PLUGIN_ID"
        codex plugin remove "$PLUGIN_ID"
    fi
}

# Adding the same local marketplace is idempotent. A different source with
# the same name (e.g. the original GitHub repository) must be removed first.
printf '[codex] Registering local marketplace: %s\n' "$PLUGIN_DIR"
if result="$(codex plugin marketplace add "$PLUGIN_DIR" 2>&1)"; then
    printf '%s\n' "$result"
else
    printf '%s\n' "$result" >&2
    if [[ "$result" == *"already added from a different source"* ]]; then
        printf '[codex] Switching the existing %s marketplace to local source...\n' "$MARKETPLACE_NAME"
        remove_if_installed
        codex plugin marketplace remove "$MARKETPLACE_NAME"
        codex plugin marketplace add "$PLUGIN_DIR"
    else
        fail 'Could not register the local marketplace; no reinstall performed.'
    fi
fi

remove_if_installed
printf '[codex] Installing %s from local source...\n' "$PLUGIN_ID"
codex plugin add "$PLUGIN_ID"

printf '\n[codex] Installation complete. Open a new Codex session.\n'
