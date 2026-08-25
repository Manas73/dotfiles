function monitorName(ws) {
  if (!ws) return ""
  if (ws.monitor && ws.monitor.name) return String(ws.monitor.name)
  var ipc = ws.lastIpcObject
  if (ipc && ipc.monitor) return String(ipc.monitor)
  return ""
}

function onScreen(ws, screen) {
  if (!screen) return true
  var name = monitorName(ws)
  return name === "" || name === screen
}

function activeId(screen, values, monitors, hyprland) {
  for (var m = 0; monitors && m < monitors.length; m++) {
    var monitor = monitors[m]
    if (!monitor || String(monitor.name || "") !== screen) continue
    var active = monitor.activeWorkspace || monitor.focusedWorkspace
    if (active && active.id > 0) return active.id
  }
  if (hyprland.focusedWorkspace && hyprland.focusedWorkspace.id > 0)
    return hyprland.focusedWorkspace.id
  for (var i = 0; i < values.length; i++) {
    if (values[i] && values[i].id > 0 && onScreen(values[i], screen))
      return values[i].id
  }
  return 0
}

function groupIndexForId(groups, id) {
  for (var g = 0; g < groups.length; g++) {
    var group = groups[g]
    if (Array.isArray(group) && group.indexOf(id) !== -1) return g
  }
  return -1
}

function persistentIds(screen, values, monitors, groups) {
  if (!Array.isArray(groups) || groups.length === 0) return []
  for (var i = 0; i < values.length; i++) {
    var ws = values[i]
    if (!ws || ws.id < 1 || !onScreen(ws, screen)) continue
    var idx = groupIndexForId(groups, ws.id)
    if (idx >= 0) return groups[idx]
  }
  return groups[0]
}

function collectIds(opts) {
  var values = opts.values || []
  var monitors = opts.monitors || []
  var screen = opts.screen || ""
  var ids = []
  var seen = ({})

  function addId(id) {
    var n = Number(id)
    if (!isFinite(n) || n < 1 || seen[n]) return
    seen[n] = true
    ids.push(n)
  }

  var current = activeId(screen, values, monitors, opts.hyprland)
  if (!opts.hideEmpty) {
    var persistent = persistentIds(screen, values, monitors, opts.persistentGroups)
    for (var p = 0; p < persistent.length; p++) addId(persistent[p])
  } else if (current > 0) {
    addId(current)
  }

  for (var i = 0; i < values.length; i++) {
    var ws = values[i]
    if (!ws || ws.id < 1) continue
    if (!opts.allOutputs && !onScreen(ws, screen)) continue
    var occupied = ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0
    if (opts.hideEmpty && !occupied && ws.id !== current) continue
    addId(ws.id)
  }

  if (opts.activeOnly)
    ids = ids.filter(function(id) { return id === current })

  ids.sort(function(a, b) { return a - b })
  return ids
}

function iconFor(map, id) {
  var key = String(id)
  if (map[key]) return map[key]
  if (id === 10 && map["0"]) return map["0"]
  return map["default"] || "󰒅"
}

function isUrgent(ws) {
  if (!ws) return false
  if (ws.urgent === true) return true
  var toplevels = ws.toplevels ? ws.toplevels.values : []
  for (var i = 0; i < toplevels.length; i++) {
    if (toplevels[i] && toplevels[i].urgent === true) return true
  }
  return false
}
