----------------------------
-- WINDOWS AND WORKSPACES --
----------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- See https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/ for workspace rules

-- Ignore maximize requests from all apps. You'll probably like this.
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

-- Hyprland-run windowrule
hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move = { "20", "monitor_h-120" },
	float = true,
})

-- Flameshot Window Rules
hl.window_rule({
	name = "proper-flameshot-handling",
	match = { class = "flameshot" },
	animation = "fade",
	rounding = 0,
	border_size = 0,
	fullscreen_state = "0 0",
	float = true,
	pin = true,
	monitor = "DP-1",
	move = { "0", "0" },
	size = { "monitor_w*2", "monitor_h" },
})

-- Workspace specific settings
hl.window_rule({
	name = "jetbrains-pycharm-ws",
	match = { class = "jetbrains-pycharm" },
	workspace = "2 silent",
})

hl.window_rule({
	name = "jetbrains-webstorm-ws",
	match = { class = "jetbrains-webstorm" },
	workspace = "2 silent",
})

hl.window_rule({
	name = "gitkraken-ws",
	match = { class = "gitkraken" },
	workspace = "3 silent",
})

hl.window_rule({
	name = "slack-ws",
	match = { class = "slack" },
	workspace = "4 silent",
})

hl.window_rule({
	name = "rambox-ws",
	match = { class = "rambox" },
	workspace = "5 silent",
})

hl.window_rule({
	name = "spotify-ws",
	match = { class = "Spotify" },
	workspace = "8 silent",
})

-- Application Rules
hl.window_rule({
	name = "steam-settings-float",
	match = { class = "steam", title = "Steam Settings" },
	float = true,
})

-- Zoom rules
hl.window_rule({
	name = "zoom-workspace",
	match = { class = "zoom" },
	workspace = "7 silent",
})

-- Float all zoom windows by default
hl.window_rule({
	name = "zoom-default-float",
	match = { class = "zoom" },
	float = true,
	group = "unset barred",
})

hl.window_rule({
	name = "zoom-menu-stayfocused",
	match = { class = "zoom", initial_title = "menu window" },
	stay_focused = true,
})

-- These three are tiled and grouped together
hl.window_rule({
	name = "zoom-ws-main",
	match = { class = "zoom", initial_title = "Zoom Workplace - Licensed account" },
	float = false,
	group = "set always invade always",
})

hl.window_rule({
	name = "zoom-ws-meeting",
	match = { class = "zoom", initial_title = "Meeting" },
	float = false,
	group = "set always invade always",
})

hl.window_rule({
	name = "zoom-chat-bubble",
	match = { class = "zoom", initial_title = "Zoom Workplace", title = "Zoom Workplace" },
	float = true,
	group = "unset deny",
})

hl.window_rule({
	name = "copyq-floating",
	match = { class = "com.github.hluk.copyq" },
	opacity = 0.8,
	float = true,
	center = true,
	size = { 600, 600 },
})
