--------------------------------------------------------------------------------
-- SUBMAP MENUS (mirror of hypr/keybinds/private_submaps.lua)
--------------------------------------------------------------------------------
--
-- Only the non-window-management submaps are reproduced here. The resize/group
-- submaps are window management and belong to omniwm, so they are intentionally
-- omitted.
--
-- Each entry shells out to ~/.config/.settings/*.sh, exactly like Hyprland.
-- The audio/wifi/bluetooth/vpn menu scripts are no-op stubs on macOS today;
-- the keymaps are kept so muscle memory (and behaviour) carry over once macOS
-- implementations land.

local exec_cmd     = hs_helper.exec_cmd
local define_submap = hs_helper.define_submap
local s            = settingsDir

--------------------------------------------------------------------------------
-- "Rofi" menus submap — Hyprland: mainMod + altMod + Space
--------------------------------------------------------------------------------
define_submap("menus", altMod, "space", function(m)
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
