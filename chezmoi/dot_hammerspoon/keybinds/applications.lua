--------------------------------------------------------------------------------
-- APPLICATION BINDINGS (mirror of hypr/keybinds/private_applications.lua)
--------------------------------------------------------------------------------

local bind     = hs_helper.bind
local exec_cmd = hs_helper.exec_cmd

-- Application launchers (Hyprland: mainMod + Return/D/B/M/G).
bind(mainMod, "return", exec_cmd(terminal))
bind(mainMod, "d",      exec_cmd(fileManager))
bind(mainMod, "b",      exec_cmd(browser))
bind(mainMod, "m",      exec_cmd(workMessenger))
bind(mainMod, "g",      exec_cmd(gitClient))

-- Hyprland mainMod + Space is `rofi -show drun`. macOS has no rofi; the native
-- app launcher is Spotlight (Cmd+Space) or Alfred (omniwm). Left unbound to
-- avoid shadowing those.

-- Power menu (Hyprland: mainMod + Delete). Uses the .settings powermenu.sh
-- stub on macOS; wire a real one there if desired.
bind(mainMod, "delete", exec_cmd(powerMenu))
