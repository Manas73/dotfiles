import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property bool active: false
  property var entries: []
  readonly property string prompt: "Clipboard"
  readonly property int initialIndex: 0
  readonly property var items: buildItems()

  onActiveChanged: if (active) refresh()

  function refresh() {
    if (!listProc.running) listProc.running = true
  }

  function glyphFor(kind, row) {
    if (kind === "image") return "󰋩"
    if (String(row) === "0") return "󰆏"
    return "󰅌"
  }

  function buildItems() {
    var list = []
    for (var i = 0; i < entries.length; i++) {
      var e = entries[i]
      if (!e) continue
      list.push({
        key: "clip-" + e.row,
        kind: "pick",
        label: e.label,
        glyph: glyphFor(e.kind, e.row),
        thumb: e.kind === "image" ? (e.preview || "") : "",
        preview: e.preview || "",
        previewKind: e.kind || "text",
        current: String(e.row) === "0",
        row: e.row
      })
    }
    return list
  }

  function parseList(raw) {
    var list = []
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      if (!line) continue
      var parts = line.split("\t")
      if (parts.length < 3) continue
      var kind = String(parts[1] || "text")
      var label = parts[2] || ""
      var preview = ""
      if (parts.length >= 4) {
        preview = parts[parts.length - 1] || ""
        label = parts.slice(2, parts.length - 1).join("\t")
      }
      if (!label && kind === "image") label = "Image"
      list.push({
        row: String(parts[0] || ""),
        kind: kind,
        label: label,
        preview: preview
      })
    }
    return list
  }

  function clearAll() {
    if (removeProc.running || listProc.running) return
    removeProc.command = [Quickshell.shellDir + "/bin/omarchy-clipboard", "clear"]
    removeProc.running = true
  }

  function activate(item) {
    if (!item || item.row === undefined || item.row === "") return "close"
    Quickshell.execDetached([Quickshell.shellDir + "/bin/omarchy-clipboard", "pick", String(item.row)])
    return "close"
  }

  function remove(item) {
    if (!item || item.row === undefined || item.row === "") return
    if (removeProc.running || listProc.running) return
    removeProc.command = [Quickshell.shellDir + "/bin/omarchy-clipboard", "remove", String(item.row)]
    removeProc.running = true
  }

  Process {
    id: listProc
    command: [Quickshell.shellDir + "/bin/omarchy-clipboard", "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.entries = root.parseList(text)
    }
  }

  Process {
    id: removeProc
    command: []
    onExited: function(code) {
      if (code === 0) root.refresh()
    }
  }
}
