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
-- config.color_scheme = 'Espresso (Gogh)'
-- config.color_scheme = 'Eighties (dark) (terminal.sexy)'
-- config.color_scheme = 'Catppuccin Macchiato'
-- config.color_scheme = 'Catppuccin Macchiato (Gogh)'
-- config.color_scheme = 'Gruvbox Dark (Gogh)'
-- config.color_scheme = 'Afterglow (Gogh)'
config.window_background_opacity = 0.97
-- config.window_decorations = 'RESIZE|INTEGRATED_BUTTONS'
config.window_decorations = 'RESIZE'

-- config.tab_bar_at_bottom = true
-- config.use_fancy_tab_bar = false
-- 
wezterm.on('update-status', function(window)
  -- Grab the utf8 character for the "powerline" left facing
  -- solid arrow.
  local SOLID_LEFT_ARROW = utf8.char(0xe0b2)

  -- Grab the current window's configuration, and from it the
  -- palette (this is the combination of your chosen colour scheme
  -- including any overrides).
  local color_scheme = window:effective_config().resolved_palette
  local bg = color_scheme.background
  local fg = color_scheme.foreground

  window:set_right_status(wezterm.format({
    -- First, we draw the arrow...
    { Background = { Color = 'none' } },
    { Foreground = { Color = bg } },
    { Text = SOLID_LEFT_ARROW },
    -- Then we draw our text
    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Text = ' ' .. wezterm.hostname() .. ' ' },
  }))
end)
-- Finally, return the configuration to wezterm:
return config
