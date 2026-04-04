# ~/.shell/aliases.sh — shell aliases

# Conda
alias ca="conda activate"

# Dev tools
alias lg="lazygit"
alias ld="lazydocker"
alias zj="zellij"

# RDP (credentials dans ~/.private_keys)
alias rdp-dmg='xfreerdp /v:"$RDP_DMG_HOST" /u:"$RDP_DMG_USER" /sec:rdp /gfx /network:lan /dynamic-resolution /microphone:off /p:"$RDP_DMG_PASS"'
alias rdp-rhino='xfreerdp /v:"$RDP_RHINO_HOST" /u:"$RDP_RHINO_USER" /gfx /network:lan /dynamic-resolution /microphone:off /p:"$RDP_RHINO_PASS"'

# Clipboard
alias cpwd='pwd | xclip -selection clipboard'

# StarCCM+
alias star13="/opt/CD-adapco/13.04.011-R8/STAR-CCM+13.04.011-R8/star/bin/starccm+"
