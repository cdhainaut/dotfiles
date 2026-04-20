#!/usr/bin/env bash
set -euo pipefail

# Setup Plank dock configuration via dconf/gsettings
# This script runs once after chezmoi apply.

log() { printf "\n\033[1;36m%s\033[0m\n" "👉 $*"; }
ok()  { printf "\033[1;32m%s\033[0m\n" "✅ $*"; }
skip(){ printf "\033[0;33m%s\033[0m\n" "⏭️  $*"; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

if ! need_cmd plank; then
    skip "Plank not installed, skipping dock configuration."
    exit 0
fi

if ! need_cmd gsettings; then
    skip "gsettings not available, skipping dock configuration."
    exit 0
fi

DOCK_PATH="/net/launchpad/plank/docks/dock1/"

log "Configuring Plank dock at $DOCK_PATH"

# Apply all settings for dock1
# Using gsettings with explicit path
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" alignment 'center'
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" auto-pinning true
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" current-workspace-only false
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" dock-items "['thunderbird.dockitem', 'firefox.dockitem', 'org.wezfurlong.wezterm.dockitem']"
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" hide-delay 0
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" hide-mode 'intelligent'
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" icon-size 48
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" items-alignment 'center'
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" lock-items false
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" monitor ''
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" offset 0
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" pinned-only false
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" position 'bottom'
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" pressure-reveal false
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" show-dock-item false
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" theme 'Monterey - Dark'
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" tooltips-enabled true
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" unhide-delay 0
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" zoom-enabled true
gsettings set net.launchpad.plank.dock.settings:"$DOCK_PATH" zoom-percent 200

ok "Plank dock configuration applied successfully."

# Also ensure the theme files are present (they are managed via chezmoi dot_local/share/plank/themes/)
# No further action needed.

log "You may need to restart plank or log out/in for changes to take full effect."
log "To restart plank: killall plank && plank &"