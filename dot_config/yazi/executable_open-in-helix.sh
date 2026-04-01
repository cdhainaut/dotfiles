#!/bin/bash
# Open a file in the Helix pane (to the right of Yazi sidebar)
file_path="$1"

# Focus the Helix pane
zellij action move-focus right

# Escape to normal mode, then :open
zellij action write 27
sleep 0.05
zellij action write-chars ":open $file_path"
zellij action write 13

# Return focus to Yazi
zellij action move-focus left
