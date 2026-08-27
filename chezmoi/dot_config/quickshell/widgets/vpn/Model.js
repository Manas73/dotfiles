function parseList(raw) {
  var list = []
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (!line) continue
    var parts = line.split("\t")
    if (parts.length < 5) continue
    var conn
    if (parts.length >= 6) {
      conn = {
        uuid: String(parts[0] || ""),
        type: String(parts[1] || ""),
        kind: String(parts[2] || parts[1] || ""),
        active: parts[3] === "1",
        timestamp: parseInt(parts[4], 10) || 0,
        name: parts.slice(5).join("\t")
      }
    } else {
      conn = {
        uuid: String(parts[0] || ""),
        type: String(parts[1] || ""),
        kind: String(parts[1] || ""),
        active: parts[2] === "1",
        timestamp: parseInt(parts[3], 10) || 0,
        name: parts.slice(4).join("\t")
      }
    }
    list.push(conn)
  }
  list.sort(compareConnections)
  return list
}

function compareConnections(a, b) {
  if (a.active !== b.active) return a.active ? -1 : 1
  if (a.timestamp !== b.timestamp) return b.timestamp - a.timestamp
  var an = String(a.name || "").toLowerCase()
  var bn = String(b.name || "").toLowerCase()
  if (an < bn) return -1
  if (an > bn) return 1
  return 0
}

function activeConnections(list) {
  var out = []
  var values = Array.isArray(list) ? list : []
  for (var i = 0; i < values.length; i++) {
    if (values[i] && values[i].active) out.push(values[i])
  }
  return out
}

function mostRecent(list) {
  var values = Array.isArray(list) ? list : []
  var best = null
  for (var i = 0; i < values.length; i++) {
    var conn = values[i]
    if (!conn) continue
    if (!best || conn.timestamp > best.timestamp) best = conn
  }
  return best
}

function connectionByUuid(list, uuid) {
  var id = String(uuid || "")
  if (!id) return null
  var values = Array.isArray(list) ? list : []
  for (var i = 0; i < values.length; i++) {
    if (values[i] && String(values[i].uuid) === id) return values[i]
  }
  return null
}

function kindOf(conn) {
  if (!conn) return ""
  return String(conn.kind || conn.type || "")
}

function typeLabel(kind) {
  if (kind === "wireguard") return "WireGuard"
  if (kind === "openvpn") return "OpenVPN"
  if (kind === "openconnect") return "OpenConnect"
  if (kind === "l2tp") return "L2TP"
  if (kind === "pptp") return "PPTP"
  if (kind === "sstp") return "SSTP"
  if (kind === "vpnc") return "Cisco"
  if (kind === "strongswan") return "IPsec"
  if (kind === "vpn") return "VPN"
  return "VPN"
}

// OpenVPN is a key (certs); WireGuard is a locked shield. Same glyph on
// and off — connected state is color/opacity, not a different shape.
function glyph(kind) {
  if (kind === "wireguard") return "󰒃"
  if (kind === "openvpn") return "󰌹"
  return "󰖂"
}

function barGlyph(active) {
  var values = Array.isArray(active) ? active : []
  if (values.length === 0) return "󰦝"
  var kind = kindOf(values[0])
  for (var i = 1; i < values.length; i++) {
    if (kindOf(values[i]) !== kind) return "󰖂"
  }
  return glyph(kind)
}

function elideStatus(text) {
  var value = String(text || "").replace(/\s+/g, " ").trim()
  if (value.length <= 180) return value
  return value.slice(0, 177) + "…"
}

function connectedSummary(active) {
  var values = Array.isArray(active) ? active : []
  if (values.length === 0) return ""
  if (values.length === 1) return values[0].name || "Connected"
  return values[0].name + " +" + (values.length - 1)
}

if (typeof module !== "undefined") {
  module.exports = {
    parseList: parseList,
    compareConnections: compareConnections,
    activeConnections: activeConnections,
    mostRecent: mostRecent,
    connectionByUuid: connectionByUuid,
    kindOf: kindOf,
    typeLabel: typeLabel,
    glyph: glyph,
    barGlyph: barGlyph,
    elideStatus: elideStatus,
    connectedSummary: connectedSummary
  }
}
