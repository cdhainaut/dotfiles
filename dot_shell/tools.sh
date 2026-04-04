# ~/.shell/tools.sh — tool functions

# fp : fuzzy find fichiers -> copie les paths absolus dans le clipboard (Tab = multi-select)
fp() {
  local sel
  sel=$(fd --type f --hidden --follow --exclude .git --absolute-path | \
    fzf --multi --preview 'bat -n --color=always --line-range :50 {}' \
        --height=60% --reverse --bind 'ctrl-a:select-all,ctrl-d:deselect-all')
  [ -n "$sel" ] && echo "$sel" | xclip -selection clipboard && echo "$sel"
}

# dp : fuzzy find dossiers -> copie les paths absolus dans le clipboard (Tab = multi-select)
dp() {
  local sel
  sel=$(fd --type d --hidden --follow --exclude .git --absolute-path | \
    fzf --multi --preview 'ls --color=always -la {} | head -20' \
        --height=60% --reverse --bind 'ctrl-a:select-all,ctrl-d:deselect-all')
  [ -n "$sel" ] && echo "$sel" | xclip -selection clipboard && echo "$sel"
}

# y : yazi with cwd tracking
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

# Conda wrapper (add conda-specific helpers here)
