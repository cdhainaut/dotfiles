#!/usr/bin/env bash
# Test d'intégration: vérifie que tous les outils sont installés et fonctionnels
set -euo pipefail

# Charger nvm si présent (claude est installé via npm/nvm)
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" 2>/dev/null || true

PASS=0
FAIL=0

check() {
  local name="$1" cmd="$2"
  local output
  if output=$(timeout 5 bash -c "$cmd" 2>/dev/null | head -n1); then
    printf "\033[1;32m  ✓ %-15s\033[0m %s\n" "$name" "$output"
    PASS=$((PASS + 1))
  else
    printf "\033[1;31m  ✗ %-15s\033[0m not found\n" "$name"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Test d'intégration dotfiles ==="
echo ""

# Shell
check "zsh"          "zsh --version"
check "oh-my-zsh"    "test -d \$HOME/.oh-my-zsh"

# Editeurs
check "helix"        "hx --version"
check "neovim"       "nvim --version"

# Terminal tools
check "zellij"       "zellij --version"
check "yazi"         "yazi --version"
check "lazygit"      "lazygit --version"
check "lazydocker"   "lazydocker --version"

# CLI utils
check "ripgrep"      "rg --version"
check "fzf"          "fzf --version"
check "fd"           "fd --version"
check "bat"          "bat --version"
check "eza"          "eza --version"
check "shfmt"        "shfmt --version"
check "yamlfmt"      "yamlfmt --version"
check "wmctrl"       "wmctrl --version || which wmctrl"

# Langages / runtimes
check "rust"         "rustc --version"
check "cargo"        "cargo --version"
check "conda"        "conda --version || test -f \$HOME/miniconda/bin/conda"
check "uv"           "uv --version"
check "pyright"      "pyright --version"
check "ruff"         "ruff --version"
check "claude"       "claude --version"
check "gh"           "gh --version"

# Configs chezmoi appliquées
echo ""
echo "--- Configs ---"
check "helix-config"    "test -f \$HOME/.config/helix/config.toml"
check "helix-langs"     "test -f \$HOME/.config/helix/languages.toml"
check "zellij-config"   "test -f \$HOME/.config/zellij/config.kdl"
check "lazygit-config"  "test -f \$HOME/.config/lazygit/config.yml"
check "yazi-config"     "test -f \$HOME/.config/yazi/yazi.toml"
check "wezterm-config"  "test -f \$HOME/.wezterm.lua"
check "zshrc"           "test -f \$HOME/.zshrc"
check "gitconfig"       "test -f \$HOME/.gitconfig"

echo ""
echo "=== Résultat: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
