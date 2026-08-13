--------------------------------------------------------------------------------
-- Hammerspoon entry point
--------------------------------------------------------------------------------
--
-- macOS counterpart to the Hyprland keybinds. Window management is handled by
-- omniwm (~/.config/omniwm/settings.toml) on the Hyper key; this config only
-- mirrors the NON-window-management Hyprland binds:
--   * application launchers (keybinds/applications.lua)
--   * submap menus          (keybinds/submaps.lua)
-- both of which shell out to ~/.config/.settings/*.sh, exactly like Hyprland.

-- Shared helpers and program paths first (exposed as globals for the modules).
require("keybinds.helper")
require("keybinds.programs")

-- Keybinding modules.
require("keybinds.applications")
require("keybinds.submaps")

hs.alert.show("Hammerspoon config loaded")
