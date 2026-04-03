# Dotfiles

Terminal-centric development environment for Linux Mint / Ubuntu 24.04, managed with [chezmoi](https://www.chezmoi.io/).

## The stack

```
WezTerm  →  Zellij  →  Helix
terminal    mux        editor
```

| Tool | Role | Config |
|---|---|---|
| [WezTerm](https://wezfurlong.org/wezterm/) | Terminal emulator (GPU-accelerated) | `.wezterm.lua` |
| [Zellij](https://zellij.dev/) | Multiplexer (tabs, panes, layouts) | `.config/zellij/` |
| [Helix](https://helix-editor.com/) | Modal editor (built-in LSP, tree-sitter) | `.config/helix/` |
| [Yazi](https://yazi-rs.github.io/) | File manager (integrated in Helix via Ctrl+Y) | `.config/yazi/` |
| [Lazygit](https://github.com/jesseduffield/lazygit) | Git TUI (integrated in Helix via Ctrl+G) | `.config/lazygit/` |

Supporting tools: ripgrep, fzf, fd, bat, eza, glow, lazydocker, neovim (backup editor).

## Installation

```bash
# Fresh Ubuntu 24.04 / Linux Mint
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply cdhainaut
```

The `run_once_install.sh` bootstrap script installs everything from scratch: zsh, Helix (from source), Zellij (via cargo), Neovim (from source), Rust, Miniconda, and all CLI tools.

Headless mode (no WezTerm):

```bash
HEADLESS=1 chezmoi apply
```

### Docker

```bash
# Build l'image (inclut tous les outils)
docker build -t dotfiles .

# Lancer les tests (identique à la CI)
docker run --rm dotfiles bash -c '
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    chezmoi init --apply github.com/cdhainaut/dotfiles
    bash "$HOME/.local/share/chezmoi/test_install.sh"
'

# Terminal interactif avec toute la stack
docker run --rm -it dotfiles bash -c '
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    chezmoi init --apply github.com/cdhainaut/dotfiles
    exec zsh
'

# Terminal interactif (config locale, pas besoin de GitHub)
docker run --rm -it -v ~/.local/share/chezmoi:/tmp/dotfiles-src:ro dotfiles bash -c '
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    chezmoi init --apply --source /tmp/dotfiles-src
    exec zsh
'
```

CI runs on every push via `.github/workflows/test-dotfiles.yml`.

## Keybinding philosophy

Modifier keys are split by tool to avoid conflicts:

| Modifier | Owner |
|---|---|
| `Ctrl+<key>` | Helix actions |
| `Alt+<key>` | Zellij actions |
| `Ctrl+Shift+<key>` | WezTerm → Zellij pass-through |

Key combos:

| Binding | Action |
|---|---|
| `Ctrl+G` | Open Lazygit (from Helix) |
| `Ctrl+Y` | Open Yazi file picker (from Helix) |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Next / prev Zellij tab |
| `Ctrl+Shift+T` | New Zellij tab |
| `Alt+h/j/k/l` | Move focus between panes |
| `Alt+p` | Zellij pane mode |
| `Alt+t` | Zellij tab mode |

## Helix

Theme: `dark_plus` (custom `carbon` theme also available).

Language servers configured:

| Language | LSP | Extras |
|---|---|---|
| Python | pyright (basic) + ruff | auto-format |
| C/C++ | clangd | clang-tidy, clang-format |
| Markdown | - | auto-format |
| YAML | yamlfmt | auto-format |

AI assistance: helix-gpt + helix-assist (Anthropic API).

Diagnostics display: gutter signs + underlines only (no inline text). Navigate with `]d` / `[d`, details with `Space+d`.

## Zellij

Theme: `catppuccin-latte`. Pane frames disabled. Scroll buffer: 5000 lines.

Layouts in `.config/zellij/layouts/`:

- `helix.kdl` — Helix + shell side-by-side
- `helix-ide.kdl` — Yazi sidebar + Helix + terminal
- `engineering.kdl` — Full engineering workspace (editor + build + tests + git + monitor tabs)

## WezTerm

Scheme: `Espresso`. Opacity: 0.97. Tab bar disabled (Zellij handles tabs). Launches Zellij on startup.

## Shell

Zsh + Oh My Zsh (`robbyrussell` theme).

Key aliases:

| Alias | Command |
|---|---|
| `ca` | `conda activate` |
| `lg` | `lazygit` |
| `ld` | `lazydocker` |
| `zj` | `zellij` |
| `ide` | `zellij -l helix-ide.kdl` |
| `pj` | Jump to project (fzf in work dir) |
| `y` | Yazi with cwd tracking |
| `cpwd` | Copy current path to clipboard |
| `mute-claude` | Mute Claude Code notification sounds |
| `unmute-claude` | Unmute Claude Code notification sounds |

## Claude Code

Config: `.claude/settings.json`. Notification hook: `.claude/hooks/notify.sh`.

### Notification hook features

- **Filtered**: `auth_success` silenced (noise reduction)
- **Sound per type**: `dialog-question` (permission), `notification` (idle), `dialog-information` (question)
- **Zellij context**: shows `session > tab` in notification body
- **Click to focus**: "Aller au terminal" button focuses WezTerm window + switches to correct Zellij tab
- **Persistent**: stays in Cinnamon notification tray (`Super+N`)
- **Mutable**: `mute-claude` / `unmute-claude` aliases toggle sound

## System health monitoring

Weekly automated check via systemd timer (`system-monitor.timer`, Mon 9h).

Script: `bin/system-monitor.sh`. Reports: `~/system-health/latest.md`.

Monitors:

- NVMe SMART (health, integrity errors, unsafe shutdowns, spare, temperature)
- EXT4 filesystem state
- Disk space (alert > 90%)
- CPU / GPU / NVMe temperatures (alert > 85°C)
- Kernel errors (filtered for known ThinkPad ACPI noise)
- Failed systemd services
- SysRq status

Desktop notification only when alerts detected. Silent otherwise.

Setup script (`run_once_setup-system-monitor.sh`) installs smartmontools, enables SysRq (`kernel.sysrq = 1`), and creates the systemd timer.

## Backup strategy

Three layers of redundancy, each independent:

### 1. External disk (`~/bin/emergency-backup.sh`)

Full backup to USB external drive (Toshiba 2 To, NTFS). NTFS-safe rsync (no permissions, `--modify-window=1`).

```bash
~/bin/emergency-backup.sh
```

Backs up:

| Phase | Content | Destination |
|-------|---------|-------------|
| 1 | SSH/GPG keys, credentials, Claude Code, documents, downloads, conda envs | `backup/home-YYYY-MM-DD/` |
| 2 | Chezmoi repo verification + copy | `backup/home-YYYY-MM-DD/chezmoi-repo/` |
| 3 | Git dirty repos scan (warnings only) | stdout |
| 4 | /mnt/data (Work, Personnal, Admin, Software, Media) | `backup/{dir}/` |
| 5 | Thunderbird, Firefox, Signal | `backup/home-YYYY-MM-DD/apps/` |

Recovery guide on the external disk: `RECOVERY.md`.

### 2. AWS S3 Glacier (`~/bin/backup-s3.sh`)

Offsite backup, ~$1/mois for ~250 Go.

```bash
~/bin/backup-s3.sh
```

| Bucket | Content |
|--------|---------|
| `s3://cd-work/` | /mnt/data/Work (hors vidéos) |
| `s3://dhainach-backup/data/` | Personnal, Administrative, Software |
| `s3://dhainach-backup/home/` | Credentials (tar.gz), Claude Code, Documents, chezmoi, conda envs, system health |

### 3. Git (chezmoi + GitHub)

All dotfiles, scripts, and configs are versioned in `cdhainaut/dotfiles` and deployed via `chezmoi apply`. CI validates every push.

### What goes where

| Data | Chezmoi | External disk | S3 Glacier |
|------|---------|---------------|------------|
| Dotfiles / configs | Source of truth | Copy | Copy |
| SSH/GPG keys | No | Yes | Yes (tar.gz) |
| Claude Code settings + hooks | Yes | Yes | Yes |
| Claude Code projects/memory | No | Yes | Yes |
| /mnt/data/Work | No | Yes | Yes |
| /mnt/data/Media (259 Go) | No | Yes | No (trop gros) |
| /mnt/data/.private | No | Yes | No |
| Conda envs (YAML) | No | Yes | Yes |
| Thunderbird / Firefox / Signal | No | Yes | No |
| Tool installation | run_once scripts | No | No |

### Recovery priority

1. **chezmoi** — `sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply cdhainaut` — installs all tools + configs
2. **External disk** — full data restore (see `RECOVERY.md` on the disk)
3. **S3** — offsite fallback if external disk lost

## Git

User: Charles Dhainaut. Git LFS enabled. Global ignore: `.claude/settings.local.json`.

## File structure

```
.
├── README.md
├── dockerfile                          # Docker testing
├── test_install.sh                     # Integration tests
├── run_once_install.sh.tmpl            # Bootstrap (packages, tools)
├── run_once_setup-system-monitor.sh    # System monitor setup
├── bin/
│   ├── executable_system-monitor.sh    # Weekly health monitoring
│   ├── executable_backup-s3.sh         # S3 Glacier backup
│   └── executable_emergency-backup.sh  # External disk backup
├── dot_wezterm.lua                     # WezTerm
├── dot_zshrc                           # Zsh
├── dot_zshenv                          # Zsh env (cargo)
├── dot_bashrc                          # Bash
├── dot_profile                         # Shared profile (aliases, PATH, env)
├── dot_gitconfig                       # Git
├── dot_claude/
│   ├── settings.json                   # Claude Code config
│   └── hooks/
│       └── executable_notify.sh        # Notification hook
├── dot_config/
│   ├── git/ignore                      # Global gitignore
│   ├── glow/glow.yml                   # Markdown viewer
│   ├── helix/
│   │   ├── config.toml                 # Editor config + keybindings
│   │   ├── languages.toml              # LSP + formatters
│   │   └── themes/carbon.toml          # Custom theme
│   ├── lazygit/config.yml              # Git TUI
│   ├── nvim/
│   │   ├── init.lua                    # Neovim (minimal, backup editor)
│   │   └── vimrc.vim                   # Clipboard config
│   ├── yazi/
│   │   ├── yazi.toml                   # File manager
│   │   └── open-in-helix.sh           # Helix integration
│   └── zellij/
│       ├── config.kdl                  # Multiplexer config
│       └── layouts/
│           ├── helix.kdl               # Editor + shell
│           ├── helix-ide.kdl           # Yazi + editor + terminal
│           ├── helix-minimal.kdl       # Minimal
│           └── engineering.kdl         # Full workspace
└── dot_local/
    └── share/plank/themes/             # Dock theme (Monterey Dark)
```
