# Recovery Guide — ThinkPad E16 Gen 3

Guide pour repartir d'une config propre en cas de remplacement du NVMe ou réinstallation.

> Ce fichier est versionné dans chezmoi (`cdhainaut/dotfiles`) et copié sur le disque externe.
> Pour la doc de la stack : voir [README.md](README.md).
> Pour la stratégie de backup : voir la section "Backup strategy" du README.

## Hardware

- **Machine** : Lenovo ThinkPad E16 Gen 3 (AMD)
- **CPU** : AMD Ryzen (16 threads)
- **RAM** : 29 Gio (1x32 Go SO-DIMM)
- **Disque** : Kioxia KBG6AZNT1T02 1 To NVMe (S/N: 5FVPSNAAZ2B7)

## Schéma de partitionnement

Le disque a 3 partitions. Reproduire ce layout sur le nouveau NVMe :

| Partition | Taille | Type | Montage | Usage |
|-----------|--------|------|---------|-------|
| nvme0n1p1 | 512 Mo | FAT32 (EFI) | /boot/efi | Bootloader |
| nvme0n1p2 | ~200 Go | EXT4 | / | Système + home |
| nvme0n1p3 | ~750 Go | EXT4 | /mnt/data | Données (Work, Media, etc.) |

Le swap est un fichier `/swapfile` sur la partition root (pas de partition swap).

### fstab

Après installation, éditer `/etc/fstab` pour monter /mnt/data :

```
UUID=<uuid-partition-3> /mnt/data ext4 defaults,x-gvfs-hide 0 2
```

Le `x-gvfs-hide` cache la partition dans le file manager (elle est montée mais pas visible comme un disque externe).

## Étape 1 — Installation de Linux Mint / Ubuntu 24.04

1. Booter sur clé USB Linux Mint (ou Ubuntu 24.04 LTS)
2. Installer avec le partitionnement manuel décrit ci-dessus
3. Utilisateur : `charles`, hostname : `charles-ThinkPad-E16-Gen-3`

## Étape 2 — Restaurer /mnt/data

Monter le disque externe et copier les données :

```bash
sudo mkdir -p /mnt/data
# Ajouter la ligne fstab ci-dessus, puis :
sudo mount /mnt/data

# Brancher le disque externe (il monte automatiquement sur /media/charles/Dhainach)
sudo rsync -rltD --info=progress2 /media/charles/Dhainach/backup/Work/ /mnt/data/Work/
sudo rsync -rltD --info=progress2 /media/charles/Dhainach/backup/Media/ /mnt/data/Media/
sudo rsync -rltD --info=progress2 /media/charles/Dhainach/backup/Personnal/ /mnt/data/Personnal/
sudo rsync -rltD --info=progress2 /media/charles/Dhainach/backup/Administrative/ /mnt/data/Administrative/
sudo rsync -rltD --info=progress2 /media/charles/Dhainach/backup/Software/ /mnt/data/Software/
sudo chown -R charles:charles /mnt/data
```

## Étape 3 — Installer chezmoi + dotfiles

Chezmoi installe tout l'environnement de dev (Helix, Zellij, WezTerm, Lazygit, Yazi, Rust, Conda, etc.) :

```bash
# Installer chezmoi et appliquer les dotfiles
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply cdhainaut
```

Cela va :
- Installer tous les paquets et outils (via `run_once_install.sh`) : Helix, Zellij, WezTerm, Lazygit, Lazydocker, Yazi, Rust, Conda, Claude Code, GitHub CLI
- Déployer toutes les configs (helix, zellij, wezterm, lazygit, yazi, git, zsh, claude hooks, etc.)
- Installer smartmontools + activer le monitoring système (via `run_once_setup-system-monitor.sh`)
- Configurer SysRq

Changer le shell par défaut :

```bash
chsh -s $(which zsh)
```

Puis fermer/rouvrir le terminal.

## Étape 4 — Restaurer les clés et credentials

Depuis le backup home sur le disque externe :

```bash
BACKUP="/media/charles/Dhainach/backup/home-<DATE>"

# SSH
cp -r "$BACKUP/.ssh" ~/.ssh
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519

# GPG
cp -r "$BACKUP/.gnupg" ~/.gnupg
chmod 700 ~/.gnupg

# GitHub CLI
mkdir -p ~/.config/gh
cp -r "$BACKUP/.config/gh/"* ~/.config/gh/

# Docker
cp -r "$BACKUP/.docker" ~/.docker 2>/dev/null

# API credentials
cp "$BACKUP/.cdsapirc" ~/ 2>/dev/null
```

## Étape 5 — Restaurer Claude Code

```bash
# Copier les settings, projets, mémoires, hooks
cp -r "$BACKUP/.claude" ~/.claude
chmod +x ~/.claude/hooks/notify.sh
```

Vérifier que le hook de notification fonctionne :

```bash
echo '{"notification_type":"idle_prompt","message":"test"}' | ~/.claude/hooks/notify.sh
```

## Étape 6 — Restaurer les apps

```bash
# Thunderbird (mails, contacts, calendriers)
cp -r "$BACKUP/apps/thunderbird" ~/.thunderbird

# Firefox (profil, bookmarks, extensions)
cp -r "$BACKUP/apps/mozilla" ~/.mozilla

# Signal
mkdir -p ~/.config/Signal
cp -r "$BACKUP/apps/Signal/"* ~/.config/Signal/
```

## Étape 7 — Post-install

Claude Code et GitHub CLI sont installés par chezmoi. Reste à :

```bash
# Authentification GitHub CLI
gh auth login

# Authentification Claude Code
claude

# Dépendances système pour le monitoring et les notifications
sudo apt install -y lm-sensors wmctrl

# AWS CLI (pour les backups S3)
pip install awscli
# ou: sudo apt install -y awscli

# Docker (si besoin)
# https://docs.docker.com/engine/install/ubuntu/
```

## Étape 8 — Restaurer les environnements conda

Les exports YAML sont sur le disque externe dans `backup/conda-envs/` :

```bash
# Installer miniconda (fait par chezmoi, mais au cas où)
curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o /tmp/miniconda.sh
bash /tmp/miniconda.sh -b -p $HOME/miniconda
~/miniconda/bin/conda init zsh

# Restaurer chaque environnement
CONDA_DIR="/media/charles/Dhainach/backup/conda-envs"
for yml in "$CONDA_DIR"/*.yml; do
    env_name=$(basename "$yml" .yml)
    [ "$env_name" = "base" ] && continue
    echo "Restauration de $env_name..."
    conda env create -f "$yml"
done
```

Environnements sauvegardés :

| Env | Packages | Usage |
|-----|----------|-------|
| aero-model | 70 | Modèle aérodynamique |
| cq311 | 287 | CadQuery 3D |
| katrain | 179 | KaTrain (Go AI) |
| latest | 425 | Env principal |
| py311 | 71 | Python 3.11 minimal |
| py38 | 104 | Python 3.8 legacy |
| wds | 197 | Projet WDS |

## Étape 9 — Cloner les repos de travail

Les repos git sont dans `/mnt/data/Work/` via le backup. Vérifier les remotes :

```bash
cd /mnt/data/Work
find . -maxdepth 3 -name ".git" -type d -exec dirname {} \; | while read repo; do
    echo "--- $repo ---"
    git -C "$repo" remote -v | head -2
    git -C "$repo" status --short | head -5
done
```

## Étape 10 — Vérifications finales

```bash
# Test 1 : outils installés (chezmoi)
bash ~/.local/share/chezmoi/test_install.sh

# Test 2 : credentials, données, services (post-recovery)
~/bin/verify-recovery.sh

# Test 3 : monitoring système
sudo ~/bin/system-monitor.sh
cat ~/system-health/latest.md

# Test 4 : notifications Claude
echo '{"notification_type":"idle_prompt","message":"Setup terminé !"}' | ~/.claude/hooks/notify.sh

# Vérifier SysRq
cat /proc/sys/kernel/sysrq  # doit être 1
```

## Checklist post-install

- [ ] /mnt/data monté et peuplé
- [ ] Chezmoi appliqué (helix, zellij, wezterm, lazygit, yazi)
- [ ] Clés SSH/GPG restaurées
- [ ] `gh auth login` fait
- [ ] Claude Code installé + hooks fonctionnels
- [ ] Thunderbird/Firefox/Signal restaurés
- [ ] `test_install.sh` passe
- [ ] Monitoring système actif (`systemctl status system-monitor.timer`)
- [ ] SysRq = 1
- [ ] Shell = zsh

## Source alternative : S3

Si le disque externe est indisponible, les données sont aussi sur AWS S3 (Glacier, eu-west-3) :

```bash
# Installer aws cli (si pas fait à l'étape 7)
pip install awscli
aws configure  # Access Key + Secret Key (eu-west-3)

# Restaurer Work
aws s3 sync s3://cd-work/ /mnt/data/Work/

# Restaurer le reste
aws s3 sync s3://dhainach-backup/data/ /mnt/data/
aws s3 sync s3://dhainach-backup/home/ ~/restore-home/
```

Note : Glacier nécessite une restauration préalable (quelques heures). Utiliser `aws s3api restore-object` ou la console AWS.

## Fichiers sur ce disque externe

```
/media/charles/Dhainach/
├── RECOVERY.md              ← Ce fichier
├── backup/
│   ├── backup.sh            ← Script de backup rsync
│   ├── exclude-list.txt     ← Exclusions rsync
│   ├── Administrative/      ← Backup /mnt/data/Administrative
│   ├── Media/               ← Backup /mnt/data/Media
│   ├── Personnal/           ← Backup /mnt/data/Personnal
│   ├── Software/            ← Backup /mnt/data/Software
│   ├── Work/                ← Backup /mnt/data/Work
│   ├── conda-envs/          ← Export YAML des envs conda
│   └── home-YYYY-MM-DD/     ← Backup du home
│       ├── .ssh/
│       ├── .gnupg/
│       ├── .claude/
│       ├── .config/gh/
│       ├── .docker/
│       ├── Documents/
│       ├── Téléchargements/
│       ├── Images/
│       ├── Zotero/
│       ├── chezmoi-repo/
│       ├── loose-files/      ← PDFs, scripts en vrac de ~/
│       ├── system-health/
│       └── apps/
│           ├── thunderbird/
│           ├── mozilla/
│           └── Signal/
```
