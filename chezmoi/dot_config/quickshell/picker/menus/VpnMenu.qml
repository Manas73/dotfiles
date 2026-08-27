import QtQuick
import Quickshell
import Quickshell.Io
import "../../widgets/vpn/Model.js" as VpnModel

Item {
  id: root

  property bool active: false
  property var connections: []
  readonly property string prompt: "VPN"
  readonly property int initialIndex: connections.length > 0 ? 1 : 0
  readonly property var items: buildItems()

  onActiveChanged: if (active) refresh()

  function refresh() {
    if (!listProc.running) listProc.running = true
  }

  function buildItems() {
    var list = []
    var activeVpns = VpnModel.activeConnections(connections)
    if (activeVpns.length > 0) {
      list.push({
        key: "down",
        kind: "down",
        label: "Disconnect VPN (" + (activeVpns[0].name || "VPN") + ")",
        glyph: "",
        current: false,
        uuid: activeVpns[0].uuid
      })
    } else {
      list.push({
        key: "none",
        kind: "noop",
        label: "No VPN Connected",
        glyph: "",
        current: false
      })
    }
    for (var i = 0; i < connections.length; i++) {
      var c = connections[i]
      if (!c) continue
      list.push({
        key: c.uuid,
        kind: "up",
        label: c.name,
        detail: VpnModel.typeLabel(VpnModel.kindOf(c)),
        glyph: VpnModel.glyph(VpnModel.kindOf(c)),
        current: !!c.active,
        uuid: c.uuid
      })
    }
    return list
  }

  function activate(item) {
    if (!item || item.kind === "noop") return "close"
    if (item.kind === "down" && item.uuid) {
      Quickshell.execDetached([Quickshell.shellDir + "/bin/omarchy-vpn", "down", item.uuid])
      return "close"
    }
    if (item.kind === "up" && item.uuid) {
      Quickshell.execDetached([Quickshell.shellDir + "/bin/omarchy-vpn", "up", item.uuid])
    }
    return "close"
  }

  Process {
    id: listProc
    command: [Quickshell.shellDir + "/bin/omarchy-vpn", "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.connections = VpnModel.parseList(text)
    }
  }
}
