#!/bin/bash
INPUT=$(cat)

TYPE=$(echo "$INPUT" | grep -oP '"notification_type"\s*:\s*"\K[^"]+')
MESSAGE=$(echo "$INPUT" | grep -oP '"message"\s*:\s*"\K[^"]+')
: "${TYPE:=unknown}"
: "${MESSAGE:=Notification}"

# Ignorer les notifs de faible intérêt
case "$TYPE" in
    auth_success) exit 0 ;;
esac

SOUNDS=/usr/share/sounds/LinuxMint/stereo
case "$TYPE" in
    permission_prompt)  LABEL="Permission requise" ; URGENCY="critical" ; SOUND="$SOUNDS/dialog-question.ogg" ;;
    idle_prompt)        LABEL="Tache terminee"     ; URGENCY="normal"   ; SOUND=/usr/share/mint-artwork/sounds/notification.oga ;;
    elicitation_dialog) LABEL="Question"           ; URGENCY="normal"   ; SOUND="$SOUNDS/dialog-information.ogg" ;;
    *)                  LABEL="Notification"        ; URGENCY="normal"   ; SOUND=/usr/share/mint-artwork/sounds/notification.oga ;;
esac

# Contexte Zellij/WezTerm
PANE_INFO=""
if [ -n "$ZELLIJ_SESSION_NAME" ]; then
    TAB_NAME=$(zellij action dump-layout 2>/dev/null | grep 'tab name=.*focus=true' | grep -oP 'tab name="\K[^"]+')
    : "${TAB_NAME:=?}"
    PANE_INFO="\n$ZELLIJ_SESSION_NAME > $TAB_NAME"
fi

# Son (mute si ~/.claude/hooks/.mute existe)
[ ! -f ~/.claude/hooks/.mute ] && paplay "$SOUND" 2>/dev/null &

# Capturer les env vars pour le sous-process
_WEZTERM_PANE="${WEZTERM_PANE:-0}"
_WEZTERM_SOCK="$WEZTERM_UNIX_SOCKET"
_ZELLIJ_SESSION="$ZELLIJ_SESSION_NAME"
_TAB_NAME="${TAB_NAME:-}"

# Lancer la notif cliquable en background (--wait bloque sinon)
(
    ACTION=$(notify-send \
        --urgency="$URGENCY" \
        --app-name="Claude Code" \
        --hint=int:transient:0 \
        -A "focus=Aller au terminal" \
        "Claude Code - $LABEL" \
        "${MESSAGE}${PANE_INFO}")

    if [ "$ACTION" = "focus" ]; then
        # Focus la fenêtre WezTerm (titre = nom de session Zellij)
        wmctrl -a "${_ZELLIJ_SESSION:-perso}" 2>/dev/null || true
        # Switch vers le bon tab Zellij
        if [ -n "$_TAB_NAME" ]; then
            zellij -s "$_ZELLIJ_SESSION" action go-to-tab-name "$_TAB_NAME" 2>/dev/null || true
        fi
        if [ -n "$_WEZTERM_SOCK" ]; then
            WEZTERM_UNIX_SOCKET="$_WEZTERM_SOCK" \
                wezterm cli activate-pane --pane-id "$_WEZTERM_PANE" 2>/dev/null || true
        fi
    fi
) &
disown
