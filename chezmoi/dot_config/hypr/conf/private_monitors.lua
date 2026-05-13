--------------
-- MONITORS --
--------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/

local leftMonitor  = "DP-1"
local rightMonitor = "DP-2"

hl.monitor({ output = leftMonitor,  mode = "2560x1440@165", position = "0x0",    scale = 1 })
hl.monitor({ output = rightMonitor, mode = "2560x1440@165", position = "2560x0", scale = 1 })

-- Right-monitor workspaces 1..5 (1 is persistent/default)
for _, ws in ipairs({ 1, 2, 3, 4, 5 }) do
  hl.workspace_rule({
    workspace  = tostring(ws),
    monitor    = rightMonitor,
    persistent = (ws == 1) or nil,
    default    = (ws == 1) or nil,
  })
end

-- Left-monitor workspaces 6..10 (6 is persistent/default)
for _, ws in ipairs({ 6, 7, 8, 9, 10 }) do
  hl.workspace_rule({
    workspace  = tostring(ws),
    monitor    = leftMonitor,
    persistent = (ws == 6) or nil,
    default    = (ws == 6) or nil,
  })
end
