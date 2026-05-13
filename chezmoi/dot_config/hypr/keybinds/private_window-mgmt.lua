-----------------------
-- WINDOW MANAGEMENT --
-----------------------

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + J",         hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + Semicolon", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + K",         hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. " + L",         hl.dsp.focus({ direction = "u" }))

-- Resize Submap (definition lives in keybinds/submaps.lua)
hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))

-- Move Windows
hl.bind(mainMod .. " + SHIFT + J",         hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + Semicolon", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + K",         hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + L",         hl.dsp.window.move({ direction = "u" }))

-- Groups
-- Tab navigation (Super + Alt + direction)
hl.bind(mainMod .. " + " .. altMod .. " + J",         hl.dsp.group.prev())
hl.bind(mainMod .. " + " .. altMod .. " + Semicolon", hl.dsp.group.next())

-- Moving Tabs
hl.bind(mainMod .. " + " .. altMod .. " + SHIFT + J",         hl.dsp.group.move_window({ forward = false }))
hl.bind(mainMod .. " + " .. altMod .. " + SHIFT + Semicolon", hl.dsp.group.move_window({ forward = true  }))
