------------------------
-- WORKSPACE BINDINGS --
------------------------

-- Right-monitor workspaces 1..5 via mainMod + [1-5]
for i = 1, 5 do
  hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. i,
          hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Left-monitor workspaces 6..10 via altMod + [1-5]
local altWs = { [1] = 6, [2] = 7, [3] = 8, [4] = 9, [5] = 10 }
for k, ws in pairs(altWs) do
  hl.bind(altMod .. " + " .. k,
          hl.dsp.focus({ workspace = ws }))
  hl.bind(altMod .. " + SHIFT + " .. k,
          hl.dsp.window.move({ workspace = ws, follow = false }))
end

-- Jump to previous (last-focused) workspace via mainMod + Tab
hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "previous_per_monitor" }))

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic", follow = false }))
