-- COPLAND OS -- WezTerm config (macOS / Linux)
-- black, cold blue-gray, Departure Mono, no decoration.
-- the launcher is the default program; it detects WezTerm itself and splits the
-- panel in on the right (20%) -- nothing to wire up here.
-- __ROOT__ and __PWSH__ are replaced by setup/install.ps1.
local wezterm = require 'wezterm'
local act = wezterm.action
local ROOT = '__ROOT__'
local PWSH = '__PWSH__'
local COPLAND = ROOT .. '/00_System/copland'

local config = wezterm.config_builder()

config.font = wezterm.font_with_fallback { 'Departure Mono', 'JetBrains Mono', 'Menlo' }
config.font_size = 13
config.line_height = 1.2
config.color_scheme = nil
config.colors = {
  background = '#000000',
  foreground = '#B8C4CE',
  cursor_bg = '#8CABC6', cursor_fg = '#000000', cursor_border = '#8CABC6',
  selection_bg = '#1C2731', selection_fg = '#B8C4CE',
  ansi    = { '#000000', '#A56A76', '#7C9A8E', '#A8A08B', '#6E8CA6', '#8688A6', '#7FA3B5', '#B8C4CE' },
  brights = { '#4A5866', '#C2848F', '#93B2A6', '#C0B8A2', '#8CABC6', '#A2A4C2', '#9CC0D2', '#E1E8EE' },
}
config.window_padding = { left = 32, right = 16, top = 16, bottom = 16 }
config.enable_tab_bar = false
config.window_decorations = 'RESIZE'
config.enable_scroll_bar = false
config.audible_bell = 'Disabled'
-- GUI apps on macOS start with a minimal PATH: make brew tools (pwsh, wezterm cli, claude) visible
config.set_environment_variables = {
  COPLAND_ROOT = ROOT,
  PATH = '/opt/homebrew/bin:/usr/local/bin:' .. (os.getenv('PATH') or ''),
}

-- launcher as default program (it spawns the panel via `wezterm cli split-pane`)
config.default_prog = { PWSH, '-NoLogo', '-NoExit', '-File', COPLAND .. '/copland.ps1' }

config.keys = {
  -- ^ = new launcher tab (as in the Windows setup), alt+left/right = switch tabs
  { key = '^', mods = 'NONE', action = act.SpawnCommandInNewTab { args = { PWSH, '-NoLogo', '-NoExit', '-File', COPLAND .. '/copland.ps1' } } },
  { key = 'LeftArrow',  mods = 'ALT', action = act.ActivateTabRelative(-1) },
  { key = 'RightArrow', mods = 'ALT', action = act.ActivateTabRelative(1) },
  -- alt+g: jump to the panel's graphics page (panel listens for g)
  { key = 'g', mods = 'ALT', action = act.Multiple { act.ActivatePaneDirection 'Right', act.SendString 'g', act.ActivatePaneDirection 'Left' } },
}

return config
