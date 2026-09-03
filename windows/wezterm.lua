-- RootCellar display driver.
-- WezTerm is the window the cellar looks out of: it speaks the kitty
-- graphics protocol, which is what makes yazi thumbnails, chafa, and
-- mpv --vo=kitty work inside the deskbottom.
--
-- Install: copy to %USERPROFILE%\.wezterm.lua (or
-- %USERPROFILE%\.config\wezterm\wezterm.lua) and set the default profile
-- to the rootcellar WSL distro.

local wezterm = require("wezterm")

local config = wezterm.config_builder()

-- Boot straight into the cellar.
config.default_domain = "WSL:rootcellar"

-- Progressive keyboard enhancement; Zellij and modern TUIs use this.
config.enable_kitty_keyboard = true

-- Advertise a modern TERM so kitty-graphics-capable apps engage.
config.term = "wezterm"

-- Typography. Fallback list degrades gracefully if fonts are missing.
config.font = wezterm.font_with_fallback({
	"JetBrains Mono",
	"Cascadia Code",
	"Consolas",
})
config.font_size = 11.0

-- Looks: dim the glass, keep the chrome minimal.
config.color_scheme = "Catppuccin Mocha"
config.window_background_opacity = 0.97
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = false
config.window_padding = {
	left = 8,
	right = 8,
	top = 4,
	bottom = 4,
}

-- Scrollback generous enough for heavy builds.
config.scrollback_lines = 10000

-- Alt+arrow / Alt+hjkl pane navigation: WezTerm does not bind Alt chords by
-- default, so they pass straight through to Zellij (see config.kdl). Add any
-- global WezTerm-side overrides here; keep them rare so the cellar owns the
-- keyboard.
config.keys = {}

return config
