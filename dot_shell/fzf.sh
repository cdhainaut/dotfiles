# ~/.shell/fzf.sh — FZF configuration
# Raccourcis :
#   Ctrl-T  -> chercher un fichier, coller le path sur la ligne de commande
#   Ctrl-R  -> recherche fuzzy dans l'historique
#   Alt-C   -> cd dans un dossier
#   fp      -> chercher fichier(s) -> copie path(s) absolu(s) dans le clipboard
#   dp      -> chercher dossier(s) -> copie path(s) absolu(s) dans le clipboard
#   Tab     -> multi-select, Ctrl-A -> tout selectionner, Ctrl-D -> tout deselectionner

export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height=60% --reverse --border --bind ctrl-a:select-all,ctrl-d:deselect-all'

export FZF_CTRL_T_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_OPTS='--preview "bat -n --color=always --line-range :50 {}"'

export FZF_CTRL_R_OPTS='--preview "echo {}" --preview-window=down:3:wrap'

export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_ALT_C_OPTS='--preview "ls --color=always -la {} | head -20"'

if [[ $- == *i* ]]; then
  [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
  [ -f /usr/share/doc/fzf/examples/completion.zsh ]   && source /usr/share/doc/fzf/examples/completion.zsh
  autoload -Uz compinit
  compinit -C
fi
