-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices.

-- For example, changing the initial geometry for new windows:
config.initial_cols = 124
config.initial_rows = 44

-- or, changing the font size and color scheme.
config.font_size = 10

-- config.color_scheme = 'Squirrelsong Dark'
-- config.color_scheme = 'Catppuccin Frappe'
-- config.color_scheme = 'Catppuccin Latte'
-- config.color_scheme = 'Chalk (Gogh)'
-- config.color_scheme = 'Edge Dark (base16)'
config.color_scheme = 'Espresso'
-- config.color_scheme = 'Kanagawa (Gogh)'
-- config.color_scheme = 'Catppuccin Macchiato'
-- config.color_scheme = 'Espresso'
-- config.color_scheme = 'Espresso (Gogh)'
-- config.color_scheme = 'Eighties (dark) (terminal.sexy)'
-- config.color_scheme = 'Catppuccin Macchiato'
-- config.color_scheme = 'Catppuccin Macchiato (Gogh)'
-- config.color_scheme = 'Gruvbox Dark (Gogh)'
-- config.color_scheme = 'Afterglow (Gogh)'
config.window_background_opacity = 0.97
-- config.window_decorations = 'RESIZE|INTEGRATED_BUTTONS'
config.window_decorations = 'RESIZE'

-- === Lancer Zellij par défaut ===
config.default_prog = { "zellij" }
-- config.tab_bar_at_bottom = true
-- config.use_fancy_tab_bar = false
config.enable_tab_bar = false

-- Pass Ctrl+Tab and Ctrl+Shift+Tab through to Zellij
config.keys = {
  { key = 'Tab', mods = 'CTRL', action = wezterm.action.DisableDefaultAssignment },
  { key = 'Tab', mods = 'CTRL|SHIFT', action = wezterm.action.SendKey { key = 'b', mods = 'ALT' } },
  { key = 't', mods = 'CTRL|SHIFT', action = wezterm.action.SendKey { key = 'n', mods = 'ALT' } },
}
-- 
wezterm.on('update-status', function(window)
  local SOLID_LEFT_ARROW = utf8.char(0xe0b2)

  local color_scheme = window:effective_config().resolved_palette
  local bg = color_scheme.background
  local fg = color_scheme.foreground

  window:set_right_status(wezterm.format({
    { Background = { Color = 'none' } },
    { Foreground = { Color = bg } },
    { Text = SOLID_LEFT_ARROW },
    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Text = ' ' .. wezterm.hostname() .. ' ' },
  }))
end)

-- Finally, return the configuration to wezterm:
return config
