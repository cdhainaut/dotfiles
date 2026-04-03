#!/bin/bash
INPUT=$(cat)

TYPE=$(echo "$INPUT" | grep -oP '"notification_type"\s*:\s*"\K[^"]+')
MESSAGE=$(echo "$INPUT" | grep -oP '"message"\s*:\s*"\K[^"]+')
: "${TYPE:=unknown}"
: "${MESSAGE:=Notification}"

# Ignorer les notifs de faible interet
case "$TYPE" in
    auth_success) exit 0 ;;
esac

# .disable = pas de notifs du tout, .mute = pas de son
[ -f ~/.claude/hooks/.disable ] && exit 0

case "$TYPE" in
    permission_prompt)  LABEL="Permission requise" ; TIMEOUT=15000 ;;
    idle_prompt)        LABEL="Tache terminee"     ; TIMEOUT=8000  ;;
    elicitation_dialog) LABEL="Question"           ; TIMEOUT=15000 ;;
    *)                  LABEL="Notification"        ; TIMEOUT=8000  ;;
esac

# Contexte Zellij/WezTerm
PANE_INFO=""
if [ -n "$ZELLIJ_SESSION_NAME" ]; then
    TAB_NAME=$(zellij action dump-layout 2>/dev/null | grep 'tab name=.*focus=true' | grep -oP 'tab name="\K[^"]+')
    : "${TAB_NAME:=?}"
    PANE_INFO="\n$ZELLIJ_SESSION_NAME > $TAB_NAME"
fi

TITLE="Claude Code - $LABEL"
BODY="${MESSAGE}${PANE_INFO}"

# Dismiss l'ancienne notif si elle existe encore
NOTIF_ID_FILE="/tmp/claude-notify-id"
OLD_ID=0
[ -f "$NOTIF_ID_FILE" ] && OLD_ID=$(cat "$NOTIF_ID_FILE")

# Capturer les env vars pour le sous-process
_WEZTERM_PANE="${WEZTERM_PANE:-0}"
_WEZTERM_SOCK="$WEZTERM_UNIX_SOCKET"
_ZELLIJ_SESSION="$ZELLIJ_SESSION_NAME"
_TAB_NAME="${TAB_NAME:-}"
_MUTED=0
[ -f ~/.claude/hooks/.mute ] && _MUTED=1

(
    if [ "$_MUTED" = "1" ]; then
        # Mode mute: gdbus pour envoyer la notif sans son
        RESULT=$(gdbus call --session \
            --dest=org.freedesktop.Notifications \
            --object-path=/org/freedesktop/Notifications \
            --method=org.freedesktop.Notifications.Notify \
            "Claude Code" "$OLD_ID" "" "$TITLE" "$BODY" \
            '["focus", "Aller au terminal"]' \
            '{"suppress-sound": <true>}' \
            "$TIMEOUT")
        NOTIF_ID=$(echo "$RESULT" | grep -oP '\d+')
        echo "$NOTIF_ID" > "$NOTIF_ID_FILE"
    else
        # Mode normal: notify-send avec son Cinnamon natif
        REPLACE_ARG=""
        [ "$OLD_ID" != "0" ] && REPLACE_ARG="--replace-id=$OLD_ID"
        ACTION=$(notify-send \
            --urgency=normal \
            --expire-time="$TIMEOUT" \
            --print-id \
            $REPLACE_ARG \
            --app-name="Claude Code" \
            -A "focus=Aller au terminal" \
            "$TITLE" \
            "$BODY")

        NOTIF_ID=$(echo "$ACTION" | head -1)
        CLICKED=$(echo "$ACTION" | tail -1)
        echo "$NOTIF_ID" > "$NOTIF_ID_FILE"

        if [ "$CLICKED" = "focus" ]; then
            wmctrl -a "${_ZELLIJ_SESSION:-perso}" 2>/dev/null || true
            if [ -n "$_TAB_NAME" ]; then
                zellij -s "$_ZELLIJ_SESSION" action go-to-tab-name "$_TAB_NAME" 2>/dev/null || true
            fi
            if [ -n "$_WEZTERM_SOCK" ]; then
                WEZTERM_UNIX_SOCKET="$_WEZTERM_SOCK" \
                    wezterm cli activate-pane --pane-id "$_WEZTERM_PANE" 2>/dev/null || true
            fi
        fi
    fi
) &
disown
