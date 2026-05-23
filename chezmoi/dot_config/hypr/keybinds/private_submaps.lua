-------------------
-- SUBMAP MENUS --
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Binds/ (submap section).
-- The 2-arg form of `hl.define_submap("name", "reset", fn)` auto-exits to the
-- "reset" submap after any bind in `fn` fires — replacing the old hyprlang
-- pattern of binding the same key twice (action + submap reset).

local home = os.getenv("HOME")

--------------------------------------------------------------------------------
-- Resize submap (Super + R) — entry point lives in keybinds/window-mgmt.lua
--------------------------------------------------------------------------------
-- Resize keeps you in the submap while pressing j/k/l/; (no auto-exit),
-- and Escape exits.
hl.define_submap("resize", function()
  hl.bind("J",         hl.dsp.window.resize({ x = -20, y = 0,   relative = true }), { repeating = true })
  hl.bind("Semicolon", hl.dsp.window.resize({ x =  20, y = 0,   relative = true }), { repeating = true })
  hl.bind("K",         hl.dsp.window.resize({ x = 0,   y = -20, relative = true }), { repeating = true })
  hl.bind("L",         hl.dsp.window.resize({ x = 0,   y =  20, relative = true }), { repeating = true })
  hl.bind("escape",    hl.dsp.submap("reset"))
end)

--------------------------------------------------------------------------------
-- Rofi menus submap (Super + Alt + Space)
--------------------------------------------------------------------------------
hl.bind(mainMod .. " + " .. altMod .. " + Space", hl.dsp.submap("rofi_menus"))

hl.define_submap("rofi_menus", "reset", function()
  hl.bind("A", hl.dsp.exec_cmd(home .. "/.config/.settings/audio_menu.sh"))
  hl.bind("M", hl.dsp.exec_cmd(home .. "/.config/.settings/microphone_menu.sh"))
  hl.bind("B", hl.dsp.exec_cmd(home .. "/.config/.settings/bluetooth_menu.sh"))
  hl.bind("C", hl.dsp.exec_cmd(home .. "/.config/.settings/clipboard-wayland.sh"))
  hl.bind("V", hl.dsp.exec_cmd(home .. "/.config/.settings/vpn_menu.sh"))
  hl.bind("W", hl.dsp.exec_cmd(home .. "/.config/.settings/wifi_menu.sh"))
  hl.bind("escape", hl.dsp.submap("reset"))
end)

--------------------------------------------------------------------------------
-- IDE submap (Super + C, then 1/2/3/4)
--------------------------------------------------------------------------------
hl.bind("SUPER + C", hl.dsp.submap("ide"))

hl.define_submap("ide", "reset", function()
  hl.bind("1", hl.dsp.exec_cmd(home .. "/.config/.settings/ide.sh"))
  hl.bind("2", hl.dsp.exec_cmd(home .. "/.config/.settings/ide-alt.sh"))
  hl.bind("3", hl.dsp.exec_cmd("cursor"))
  hl.bind("4", hl.dsp.exec_cmd(home .. "/.config/.settings/editor.sh"))
  hl.bind("escape", hl.dsp.submap("reset"))
end)

--------------------------------------------------------------------------------
-- Group submap (Super + W)
--------------------------------------------------------------------------------
hl.bind(mainMod .. " + W", hl.dsp.submap("group"))

hl.define_submap("group", "reset", function()
  -- Toggle group on active window (create/destroy group)
  hl.bind("G", hl.dsp.group.toggle())

  -- Smart move: into neighbor group if one exists, out of group if pressing
  -- toward nothing while in a group, otherwise behaves as movewindow.
  hl.bind("J",         hl.dsp.window.move({ into_or_create_group = "l" }))
  hl.bind("K",         hl.dsp.window.move({ into_or_create_group = "d" }))
  hl.bind("L",         hl.dsp.window.move({ into_or_create_group = "u" }))
  hl.bind("Semicolon", hl.dsp.window.move({ into_or_create_group = "r" }))

  -- Move out of group (Detach) — only works if active window is in a group
  hl.bind("D", hl.dsp.window.move({ out_of_group = true }))

  -- Lock group
  hl.bind("W", hl.dsp.group.lock_active({ action = "toggle" }))

  hl.bind("escape", hl.dsp.submap("reset"))
end)
