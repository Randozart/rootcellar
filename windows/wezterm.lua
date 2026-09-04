-- RootCellar display driver.
-- WezTerm is the window the cellar looks out of: it speaks the kitty
-- graphics protocol, which is what makes yazi thumbnails, chafa, and
-- mpv --vo=kitty work inside the deskbottom.
--
-- Identity: docs/BRANDING.md — white / turnip purple / Nix blues on
-- cellar plum-black. Tab sigil is Raddix.
--
-- Install: copy to %USERPROFILE%\.wezterm.lua (or
-- %USERPROFILE%\.config\wezterm\wezterm.lua) and set the default profile
-- to the RootCellar WSL distro.

local wezterm = require("wezterm")

local config = wezterm.config_builder()

-- Boot straight into the cellar.
config.default_domain = "WSL:RootCellar"

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

-- The RootCellar palette (docs/BRANDING.md).
local palette = {
	white = "#F5F3F1",
	purple = "#A06BE0",
	dblue = "#5277C3",
	lblue = "#7EBAE5",
	bg = "#191622",
	black = "#2A2438",
	dim = "#6F6785",
	rose = "#D0879A",
	sea = "#6FBFAD",
	sand = "#D8C77A",
}

config.colors = {
	foreground = palette.white,
	background = palette.bg,
	cursor_bg = palette.purple,
	cursor_fg = palette.bg,
	cursor_border = palette.purple,
	selection_bg = palette.dblue,
	selection_fg = palette.white,
	split = palette.dblue,
	scrollbar_thumb = palette.black,
	ansi = {
		palette.black, -- black
		palette.rose, -- red (muted rose, in-family)
		palette.sea, -- green (muted sea-glass)
		palette.sand, -- yellow (muted sand)
		palette.lblue, -- blue
		palette.purple, -- magenta
		palette.lblue, -- cyan
		palette.dim, -- white
	},
	brights = {
		"#453D5C", -- bright black
		"#E08CA0", -- bright red
		"#8FD8C5", -- bright green
		"#E8D89A", -- bright yellow
		"#9CC4F0", -- bright blue
		"#C09AF0", -- bright magenta
		"#8AD8D2", -- bright cyan
		palette.white, -- bright white
	},
}

-- Looks: dim the glass, keep the chrome in the family.
config.window_background_opacity = 0.97
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = false
config.window_padding = {
	left = 8,
	right = 8,
	top = 4,
	bottom = 4,
}
config.colors.tab_bar = {
	background = palette.bg,
	active_tab = {
		bg_color = palette.bg,
		fg_color = palette.purple,
		intensity = "Bold",
	},
	inactive_tab = {
		bg_color = palette.black,
		fg_color = palette.dim,
	},
	inactive_tab_hover = {
		bg_color = palette.black,
		fg_color = palette.lblue,
	},
	new_tab = {
		bg_color = palette.black,
		fg_color = palette.lblue,
	},
	new_tab_hover = {
		bg_color = palette.dblue,
		fg_color = palette.white,
	},
}

-- Scrollback generous enough for heavy builds.
config.scrollback_lines = 10000

-- Tab titles: Raddix sigil + the tab's own name.
wezterm.on("format-tab-title", function(tab)
	local title = tab.tab_title
	if not title or title == "" then
		local pane = tab.active_pane
		title = pane.title
	end
	local sigil = tab.is_active and " ⟨◠( '' )◡⟩ " or " ⟨◠◡⟩ "
	return {
		{ Background = { Color = tab.is_active and palette.bg or palette.black } },
		{ Text = sigil .. title },
	}
end)

-- Right status: the tail wiggles, the clock ticks.
wezterm.on("update-right-status", function(window)
	local time = wezterm.strftime("%H:%M")
	window:set_right_status(wezterm.format({
		{ Foreground = { Color = palette.purple } },
		{ Text = "⌣~ " },
		{ Foreground = { Color = palette.lblue } },
		{ Text = time .. " " },
	}))
end)

-- Alt+arrow / Alt+hjkl pane navigation: WezTerm does not bind Alt chords by
-- default, so they pass straight through to Zellij (see config.kdl). The
-- bindings below are the only WezTerm-side overrides: paste on Ctrl+V (the
-- Windows habit; Ctrl+Shift+V also works), and Ctrl+C that copies only when
-- text is selected, otherwise passing the interrupt through untouched.
config.keys = {
	{ key = "V", mods = "CTRL", action = wezterm.action.PasteFromClipboard },
	{
		key = "C",
		mods = "CTRL",
		action = wezterm.action.Callback(function(window, pane)
			local selected = window:get_selection_text_for_pane(pane)
			if selected and selected ~= "" then
				window:perform_action(wezterm.action.CopyTo("ClipboardAndPrimarySelection"), pane)
			else
				window:perform_action(wezterm.action.SendKey({ key = "C", mods = "CTRL" }), pane)
			end
		end),
	},
}

return config
