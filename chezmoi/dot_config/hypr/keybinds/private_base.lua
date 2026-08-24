-----------------
-- KEYBINDINGS --
-----------------

-- See https://wiki.hypr.land/Configuring/Basics/Binds/

_G.mainMod = "SUPER" -- "Windows" key as main modifier
_G.altMod = "ALT"

-- Core window actions
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + End", hl.dsp.exec_cmd("hyprlock"))

-- Layouts
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.group.toggle())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))

-- Screenshot
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("flameshot gui"))

-- Quickshell
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("killall quickshell; ~/.config/quickshell/bin/launch"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("omarchy-shell notifications showHistory"))

-- Laptop multimedia keys for volume (OSD lives in the shell)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("omarchy-audio-output-volume raise"), { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("omarchy-audio-output-volume lower"), { repeating = true, locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("omarchy-audio-output-volume mute-toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
