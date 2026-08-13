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

-- Settings-script dir, exposed as a global for the keybinding modules.
_G.settingsDir = os.getenv("HOME") .. "/.config/.settings"

-- Shared helpers first (defines hs_helper + mainMod).
require("keybinds.helper")

-- Keybinding modules.
require("keybinds.applications")
require("keybinds.submaps")

hs.alert.show("Hammerspoon config loaded")
