-- COPLAND OS -- WezTerm config (macOS / Linux)
-- black, cold blue-gray, Departure Mono, no decoration.
-- launcher left (80%), panel right (20%). __ROOT__ is replaced by setup/macos.sh.
local wezterm = require 'wezterm'
local act = wezterm.action
local ROOT = '__ROOT__'
local COPLAND = ROOT .. '/00_System/copland'

local config = wezterm.config_builder()

config.font = wezterm.font_with_fallback { 'Departure Mono', 'JetBrains Mono', 'Menlo' }
config.font_size = 13
config.color_scheme = nil
config.colors = {
  background = '#000000',
  foreground = '#B8C4CE',
  cursor_bg = '#8CABC6', cursor_fg = '#000000', cursor_border = '#8CABC6',
  selection_bg = '#1C232A', selection_fg = '#B8C4CE',
  ansi    = { '#000000', '#C2848F', '#8CABC6', '#B8C4CE', '#8CABC6', '#8CABC6', '#8CABC6', '#B8C4CE' },
  brights = { '#4A5866', '#C2848F', '#8CABC6', '#B8C4CE', '#8CABC6', '#8CABC6', '#8CABC6', '#B8C4CE' },
}
config.window_padding = { left = 32, right = 16, top = 16, bottom = 16 }
config.enable_tab_bar = false
config.window_decorations = 'RESIZE'
config.enable_scroll_bar = false
config.audible_bell = 'Disabled'
config.set_environment_variables = { COPLAND_ROOT = ROOT }

-- launcher is the default program; the launcher itself skips the Windows-Terminal
-- pane split (no wt), so we open the panel as a right split here.
config.default_prog = { 'pwsh', '-NoLogo', '-NoExit', '-File', COPLAND .. '/copland.ps1' }

wezterm.on('gui-startup', function(cmd)
  local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
  pane:split {
    direction = 'Right',
    size = 0.2,
    args = { 'pwsh', '-NoLogo', '-NoProfile', '-File', COPLAND .. '/copland-panel.ps1' },
  }
  window:gui_window():perform_action(act.ActivatePaneDirection 'Left', pane)
end)

config.keys = {
  -- ^ = new launcher tab (as in the Windows setup), alt+left/right = switch tabs
  { key = '^', mods = 'NONE', action = act.SpawnCommandInNewTab { args = { 'pwsh', '-NoLogo', '-NoExit', '-File', COPLAND .. '/copland.ps1' } } },
  { key = 'LeftArrow',  mods = 'ALT', action = act.ActivateTabRelative(-1) },
  { key = 'RightArrow', mods = 'ALT', action = act.ActivateTabRelative(1) },
  -- alt+g: jump to the panel's graphics page (panel listens for g)
  { key = 'g', mods = 'ALT', action = act.Multiple { act.ActivatePaneDirection 'Right', act.SendString 'g', act.ActivatePaneDirection 'Left' } },
}

return config
