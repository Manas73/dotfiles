--------------------------------------------------------------------------------
-- SUBMAP MENUS (mirror of hypr/keybinds/private_submaps.lua)
--------------------------------------------------------------------------------
local exec_cmd     = hs_helper.exec_cmd
local define_submap = hs_helper.define_submap
local s            = settingsDir

--------------------------------------------------------------------------------
-- "Rofi" menus submap — Hyprland: mainMod + altMod + Space
--------------------------------------------------------------------------------
define_submap("menus", mainMod, "space", function(m)
  m:entry("a", "audio",      exec_cmd(s .. "/audio_menu.sh"))
  m:entry("m", "microphone", exec_cmd(s .. "/microphone_menu.sh"))
  m:entry("b", "bluetooth",  exec_cmd(s .. "/bluetooth_menu.sh"))
  m:entry("c", "clipboard",  exec_cmd(s .. "/clipboard-wayland.sh"))
  m:entry("v", "vpn",        exec_cmd(s .. "/vpn_menu.sh"))
  m:entry("w", "wifi",       exec_cmd(s .. "/wifi_menu.sh"))
end)

--------------------------------------------------------------------------------
-- IDE submap — Hyprland: SUPER + C, then 1/2  (=> Hyper+C)
--------------------------------------------------------------------------------
define_submap("ide", mainMod, "c", function(m)
  m:entry("1", "editor", exec_cmd(s .. "/editor.sh"))
  m:entry("2", "ide",    exec_cmd(s .. "/ide.sh"))
end)
