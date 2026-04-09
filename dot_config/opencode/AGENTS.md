# Instructions globales — Charles Dhainaut

## Profil

- Charles Dhainaut, auto-entrepreneur (SIRET 83451260000018) en France
- Domaine : hydrodynamique navale/aéro, CFD, VPP, consulting ingénierie voile
- Clients historiques : F4E, L2O/Grain de Sail, Alinghi (AC37), Charal, BanquePop, Malizia, WDS, ENSTA
- Langues : français (natif), anglais
- Préfère les outils CLI aux GUIs
- Répertoire de travail : /mnt/data/Work avec convention CD### pour les projets

## Stack terminal

- **Terminal** : WezTerm → **Multiplexer** : Zellij → **Éditeur** : Helix
- **Fichiers** : Yazi (Ctrl+Y dans Helix)
- **Git** : Lazygit (Ctrl+G dans Helix)
- **Séparation touches** : Ctrl = actions Helix, Alt = actions Zellij
- **Onglets Zellij** : Ctrl+Tab / Ctrl+Shift+Tab (remappés via WezTerm → Alt+b/Alt+n)
- **Dotfiles** : chezmoi (repo cdhainaut/dotfiles sur GitHub)
- Yazi a des bugs d'affichage dans Zellij (limitation Sixel)
- Shell : zsh avec oh-my-zsh

## Règles critiques

### JAMAIS casser Helix (hx)

hx est l'IDE principal — le perdre bloque tout le travail. Après TOUT changement touchant cargo, PATH, ou ~/.local/bin/ :

- Vérifier `which hx` fonctionne
- Le binaire est à ~/src/helix/target/opt/hx, symlink dans ~/.local/bin/hx
- Ne jamais supprimer le guard `need_cmd hx` dans les scripts d'install

### rustup update efface les binaires cargo

`rustup update` reconstruit ~/.cargo/bin/ et supprime les binaires tiers (zellij, etc.). Après tout rustup update :

- Réinstaller : `cargo install --locked zellij`
- Vérifier : `which zellij && which hx`

### Workflow chezmoi

- Éditer le fichier live d'abord, puis `chezmoi add --force <fichier>` pour synchroniser
- Pour les fichiers .tmpl : éditer le template source directement, puis `chezmoi apply`
- Ne JAMAIS éditer manuellement les deux (live + source)
- Toujours tester localement + Docker avant de push chezmoi

### Markdown

- Toujours mettre une ligne vide avant les listes markdown (sinon le rendu casse)

### Helix diagnostics

- Pas de texte diagnostic inline dans Helix (trop intrusif)
- Uniquement underlines + gutter signs ; détails via Space+d ou ]d/[d
- Pyright en mode `typeCheckingMode = "basic"` (config globale dans languages.toml)

## Contexte projets

### Sortie WDS

- CDI depuis jan 2026, période d'essai. Départ en cours.
- Non-concurrence limitée au contrôle temps-réel uniquement
- NomAD = IP pré-existante (7 ans, publication JST 2025)
- Contact LDA pré-existant (avant WDS)
- Plans d'action dans CDXXX-Admin

### Monitoring système

- Script `~/bin/system-monitor.sh` — timer systemd hebdomadaire (lundi 09:00)
- Reports dans `~/system-health/`, baseline NVMe = 23 Media Integrity Errors
- Si erreurs > 23, alerter immédiatement

### Backup S3

- Script `~/bin/backup-s3.sh` — timer systemd hebdomadaire
- Stockage GLACIER sauf personal-ip-backup (STANDARD_IA)
- Exclusions : .venv, node_modules, target, build, dist, .git, __pycache__, *.nc, *.grb, *.dll, *.exe
