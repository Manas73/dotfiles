-----------------
-- KEYBINDINGS --
-----------------

-- See https://wiki.hypr.land/Configuring/Basics/Binds/

_G.mainMod = "SUPER" -- "Windows" key as main modifier
_G.altMod  = "ALT"

-- Core window actions
hl.bind(mainMod .. " + Q",   hl.dsp.window.close())
hl.bind(mainMod .. " + End", hl.dsp.exec_cmd("hyprlock"))

-- Layouts
hl.bind(mainMod .. " + SHIFT + W",     hl.dsp.group.toggle())
hl.bind(mainMod .. " + F",             hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))

-- Screenshot
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("flameshot gui"))

-- Waybar and SwayNC
hl.bind(mainMod .. " + SHIFT + R",
  hl.dsp.exec_cmd("/home/ms-garuda/.config/waybar/scripts/launch.sh"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t"))

-- Laptop multimedia keys for volume and LCD brightness
local function vol(args)
  return hl.dsp.exec_cmd(
    "swayosd-client " .. args ..
    " --monitor \"$(hyprctl monitors -j | jq -r '.[] | select(.focused == true).name')\""
  )
end

hl.bind("XF86AudioRaiseVolume", vol("--output-volume 2"),           { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume", vol("--output-volume -2"),          { repeating = true, locked = true })
hl.bind("XF86AudioMute",        vol("--output-volume mute-toggle"), { repeating = true, locked = true })

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
