// weather.json holds a home location plus optional extra place tabs:
//   {"name", "latitude", "longitude", "places": [...], "activePlaceId"}
// omarchy-weather-location owns the home fields. Missing, blank, or
// unparseable means the home tab auto-detects from the IP address.
function newPlaceId() {
  return "p" + Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36)
}

function normalizePlace(place, fallbackId) {
  if (!place || typeof place !== "object") return null
  var latitude = parseFloat(place.latitude)
  var longitude = parseFloat(place.longitude)
  var hasCoordinates = !isNaN(latitude) && !isNaN(longitude)
  var id = typeof place.id === "string" ? place.id.replace(/^\s+|\s+$/g, "") : ""
  return {
    id: id || fallbackId || newPlaceId(),
    name: typeof place.name === "string" ? place.name.replace(/^\s+|\s+$/g, "") : "",
    latitude: hasCoordinates ? latitude : null,
    longitude: hasCoordinates ? longitude : null
  }
}

function emptyPlacesState() {
  var home = { id: "home", name: "", latitude: null, longitude: null }
  return { name: "", latitude: null, longitude: null, places: [home], activePlaceId: "home" }
}

function parseLocationFile(raw) {
  var unset = emptyPlacesState()
  try {
    var data = JSON.parse(String(raw || ""))
    if (!data || typeof data !== "object") return unset

    var home = normalizePlace({
      id: "home",
      name: data.name,
      latitude: data.latitude,
      longitude: data.longitude
    }, "home")
    var places = []
    var listed = data.places
    if (listed && listed.length) {
      for (var i = 0; i < listed.length; i++) {
        var place = normalizePlace(listed[i], i === 0 ? "home" : newPlaceId())
        if (place) places.push(place)
      }
    }
    if (!places.length) places = [home]

    var active = typeof data.activePlaceId === "string" ? data.activePlaceId : ""
    if (!findPlace(places, active)) active = places[0].id

    return {
      name: places[0].name,
      latitude: places[0].latitude,
      longitude: places[0].longitude,
      places: places,
      activePlaceId: active
    }
  } catch (e) {
    return unset
  }
}

function serializeLocationFile(state) {
  var places = state && state.places && state.places.length ? state.places : emptyPlacesState().places
  var first = places[0]
  var out = {
    name: first.name || "",
    places: places,
    activePlaceId: state && state.activePlaceId ? state.activePlaceId : first.id
  }
  if (first.latitude !== null && first.longitude !== null) {
    out.latitude = first.latitude
    out.longitude = first.longitude
  }
  return JSON.stringify(out, null, 2)
}

function findPlace(places, id) {
  var list = places || []
  var key = String(id || "")
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].id === key) return list[i]
  }
  return null
}

function placeLabel(place) {
  var name = place && place.name ? String(place.name) : ""
  return name || "Auto"
}

function placeIndex(places, id) {
  var list = places || []
  var key = String(id || "")
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].id === key) return i
  }
  return 0
}

function replacePlace(places, next) {
  var list = (places || []).slice()
  if (!next) return list
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].id === next.id) {
      list[i] = next
      return list
    }
  }
  list.push(next)
  return list
}

function removePlace(places, id) {
  var list = places || []
  if (list.length <= 1) return list.slice()
  var out = []
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].id !== id) out.push(list[i])
  }
  return out.length ? out : list.slice()
}

function neighborPlaceId(places, id, delta) {
  var list = places || []
  if (!list.length) return ""
  var index = placeIndex(list, id)
  var next = (index + (delta || 0) + list.length) % list.length
  return list[next].id
}

// linecast --location: exact coordinates when both are present, else the
// place name, else empty (IP auto-detect).
function linecastLocationArg(state) {
  if (!state) return ""
  var lat = parseFloat(String(state.latitude))
  var lon = parseFloat(String(state.longitude))
  if (!isNaN(lat) && !isNaN(lon)) return lat + "," + lon
  return String(state.name || "").replace(/^\s+|\s+$/g, "")
}

function linecastCommand(binary, view, opts) {
  var cmd = [String(binary || "omarchy-linecast"), String(view || "weather")]
  opts = opts || {}
  if (opts.json) cmd.push("--json")
  if (opts.print) cmd.push("--print")
  cmd.push("--icons", opts.icons || "nerd")
  if (opts.location) {
    cmd.push("--location")
    cmd.push(String(opts.location))
  }
  if (opts.units === "metric") cmd.push("--metric")
  if (opts.units === "imperial") cmd.push("--imperial")
  return cmd
}

function parseWeatherJson(raw) {
  try {
    var data = JSON.parse(String(raw || ""))
    if (!data || typeof data !== "object") return null
    var current = data.current || {}
    var icon = current.icon != null ? String(current.icon) : ""
    var location = typeof data.location === "string" ? data.location : ""
    if (location.indexOf(",") >= 0) location = location.split(",")[0].replace(/^\s+|\s+$/g, "")
    return {
      location: location,
      icon: icon
    }
  } catch (e) {
    return null
  }
}

// Open-Meteo geocoding response → suggestion rows for the location picker.
function parseGeocodingResults(raw) {
  try {
    var data = JSON.parse(String(raw || "{}"))
    var results = data.results
    if (!results || !results.length) return []

    var out = []
    for (var i = 0; i < results.length; i++) {
      var r = results[i]
      if (!r || !r.name || r.latitude === undefined || r.longitude === undefined) continue
      var region = [r.admin1, r.country].filter(function(part) { return !!part }).join(", ")
      out.push({
        name: String(r.name),
        description: region,
        latitude: r.latitude,
        longitude: r.longitude
      })
    }
    return out
  } catch (e) {
    return []
  }
}

function locationCommit(text, suggestions, selectedIndex) {
  var name = String(text || "").replace(/^\s+|\s+$/g, "")
  if (name === "") return { name: "", latitude: null, longitude: null }

  var choices = suggestions || []
  var index = Math.max(0, Math.min(parseInt(selectedIndex, 10) || 0, choices.length - 1))
  var suggestion = choices[index]
  if (suggestion) return suggestion

  return { name: name, latitude: null, longitude: null }
}

function normalizedUnit(value) {
  return String(value || "").replace(/^\s+|\s+$/g, "").toLowerCase()
}

function linecastPrintEnvironment(columns, rows) {
  return {
    LINECAST_COLOR: "truecolor",
    LINECAST_ICONS: "nerd",
    CLICOLOR_FORCE: "1",
    NO_COLOR: "",
    TERM: "xterm-256color",
    COLORTERM: "truecolor",
    COLUMNS: String(Math.max(20, columns || 20)),
    LINES: String(Math.max(6, rows || 6))
  }
}

var ANSI_16 = [
  "#000000", "#bb0000", "#00bb00", "#bbbb00",
  "#0000bb", "#bb00bb", "#00bbbb", "#bbbbbb",
  "#555555", "#ff5555", "#55ff55", "#ffff55",
  "#5555ff", "#ff55ff", "#55ffff", "#ffffff"
]

function rgbHex(r, g, b) {
  function h(n) {
    n = Math.max(0, Math.min(255, parseInt(n, 10) || 0))
    return (n < 16 ? "0" : "") + n.toString(16)
  }
  return "#" + h(r) + h(g) + h(b)
}

function color256(n) {
  n = parseInt(n, 10) || 0
  if (n < 16) return ANSI_16[n]
  if (n < 232) {
    n -= 16
    var r = Math.floor(n / 36)
    var g = Math.floor((n % 36) / 6)
    var b = n % 6
    var c = [0, 95, 135, 175, 215, 255]
    return rgbHex(c[r], c[g], c[b])
  }
  var v = 8 + (n - 232) * 10
  return rgbHex(v, v, v)
}

function applySgr(params, state) {
  var i = 0
  if (!params.length) params = ["0"]
  while (i < params.length) {
    var p = parseInt(params[i], 10)
    if (isNaN(p) || p === 0) {
      state.fg = null
      state.bg = null
      state.bold = false
    } else if (p === 1) {
      state.bold = true
    } else if (p === 22) {
      state.bold = false
    } else if (p === 39) {
      state.fg = null
    } else if (p === 49) {
      state.bg = null
    } else if (p >= 30 && p <= 37) {
      state.fg = ANSI_16[p - 30]
    } else if (p >= 90 && p <= 97) {
      state.fg = ANSI_16[p - 90 + 8]
    } else if (p >= 40 && p <= 47) {
      state.bg = ANSI_16[p - 40]
    } else if (p >= 100 && p <= 107) {
      state.bg = ANSI_16[p - 100 + 8]
    } else if (p === 38 || p === 48) {
      var isFg = p === 38
      var mode = parseInt(params[i + 1], 10)
      if (mode === 2) {
        var hex = rgbHex(params[i + 2], params[i + 3], params[i + 4])
        if (isFg) state.fg = hex
        else state.bg = hex
        i += 4
      } else if (mode === 5) {
        var indexed = color256(params[i + 2])
        if (isFg) state.fg = indexed
        else state.bg = indexed
        i += 2
      }
    }
    i++
  }
}

function takeChar(raw, i) {
  var c = raw.charCodeAt(i)
  if (c >= 0xD800 && c <= 0xDBFF && i + 1 < raw.length) {
    var d = raw.charCodeAt(i + 1)
    if (d >= 0xDC00 && d <= 0xDFFF) return raw.substring(i, i + 2)
  }
  return raw.charAt(i)
}

function ansiToLines(raw) {
  raw = String(raw || "")
  raw = raw.replace(/\u001b\][^\u0007]*(?:\u0007|\u001b\\)/g, "")
  raw = raw.replace(/\r\n/g, "\n").replace(/\r/g, "")

  var lines = []
  var segs = []
  var state = { fg: null, bg: null, bold: false }
  var buf = ""

  function flush() {
    if (buf === "") return
    segs.push({ text: buf, fg: state.fg, bg: state.bg, bold: !!state.bold })
    buf = ""
  }

  function newline() {
    flush()
    lines.push(segs)
    segs = []
  }

  var i = 0
  while (i < raw.length) {
    if (raw.charAt(i) === "\u001b") {
      var rest = raw.substring(i)
      var csi = rest.match(/^\u001b\[([0-9;]*)([A-Za-z])/)
      if (csi) {
        if (csi[2] === "m") {
          flush()
          applySgr(csi[1] === "" ? [] : csi[1].split(";"), state)
        }
        i += csi[0].length
        continue
      }
      i += 1
      while (i < raw.length) {
        var code = raw.charCodeAt(i)
        i += 1
        if (code >= 64 && code <= 126) break
      }
      continue
    }
    if (raw.charAt(i) === "\n") {
      newline()
      i += 1
      continue
    }
    var ch = takeChar(raw, i)
    buf += ch
    i += ch.length
  }
  flush()
  if (segs.length) lines.push(segs)
  while (lines.length && lines[lines.length - 1].length === 0) lines.pop()
  return lines
}

if (typeof module !== "undefined") {
  module.exports = {
    parseLocationFile: parseLocationFile,
    serializeLocationFile: serializeLocationFile,
    newPlaceId: newPlaceId,
    findPlace: findPlace,
    placeLabel: placeLabel,
    replacePlace: replacePlace,
    removePlace: removePlace,
    neighborPlaceId: neighborPlaceId,
    linecastLocationArg: linecastLocationArg,
    linecastCommand: linecastCommand,
    parseWeatherJson: parseWeatherJson,
    parseGeocodingResults: parseGeocodingResults,
    locationCommit: locationCommit,
    normalizedUnit: normalizedUnit,
    linecastPrintEnvironment: linecastPrintEnvironment,
    ansiToLines: ansiToLines
  }
}
