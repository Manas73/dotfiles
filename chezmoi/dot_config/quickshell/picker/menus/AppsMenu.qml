import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property bool active: false
  property var entries: []
  readonly property string prompt: "Applications"
  readonly property int initialIndex: 0
  readonly property var items: buildItems()

  onActiveChanged: if (active) refresh()

  function refresh() {
    if (!listProc.running) listProc.running = true
  }

  function buildItems() {
    var list = []
    for (var i = 0; i < entries.length; i++) {
      var e = entries[i]
      if (!e) continue
      list.push({
        key: "app-" + e.path,
        kind: "launch",
        label: e.name,
        detail: e.detail,
        glyph: "󰣆",
        icon: e.icon || "",
        search: e.search || e.name,
        path: e.path
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
      if (parts.length < 2) continue
      list.push({
        path: parts[0] || "",
        name: parts[1] || "",
        detail: parts[2] || "",
        icon: parts[3] || "",
        search: parts[4] || parts[1] || ""
      })
    }
    return list
  }

  function activate(item) {
    if (!item || !item.path) return "close"
    Quickshell.execDetached([Quickshell.shellDir + "/bin/omarchy-apps", "launch", item.path])
    return "close"
  }

  Process {
    id: listProc
    command: [Quickshell.shellDir + "/bin/omarchy-apps", "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.entries = root.parseList(text)
    }
  }
}
