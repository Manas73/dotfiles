--------------------------------------------------------------------------------
-- APPLICATION BINDINGS (mirror of hypr/keybinds/private_applications.lua)
--------------------------------------------------------------------------------

local bind     = hs_helper.bind
local exec_cmd = hs_helper.exec_cmd
local s        = settingsDir

-- Application launchers (Hyprland: mainMod + Return/D/B/M/G).
bind(mainMod, "return", exec_cmd(s .. "/terminal.sh"))
bind(mainMod, "d",      exec_cmd(s .. "/file_manager.sh"))
bind(mainMod, "b",      exec_cmd(s .. "/browser.sh"))
bind(mainMod, "m",      exec_cmd(s .. "/work_messenger.sh"))
bind(mainMod, "g",      exec_cmd(s .. "/git_client.sh"))
bind(mainMod, "delete", exec_cmd(s .. "/powermenu.sh"))
