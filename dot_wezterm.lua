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

config.color_scheme = 'Afterglow (Gogh)'
config.window_background_opacity = 0.95
config.window_decorations = 'INTEGRATED_BUTTONS'

config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false

-- Finally, return the configuration to wezterm:
return config
