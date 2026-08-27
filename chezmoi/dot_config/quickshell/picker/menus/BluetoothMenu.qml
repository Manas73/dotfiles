import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../../widgets/bluetooth/Model.js" as BtModel

Item {
  id: root

  property bool active: false
  readonly property string prompt: "Bluetooth"
  readonly property int initialIndex: 0
  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
  readonly property var groups: BtModel.deviceLists(devices)
  readonly property var items: buildItems()

  function buildItems() {
    var list = []
    var on = !!(adapter && adapter.enabled)
    list.push({
      key: "power",
      kind: "power",
      label: on ? "Disable Bluetooth" : "Enable Bluetooth",
      glyph: on ? "󰂲" : "󰂯",
      current: false
    })
    var connected = groups.connected || []
    for (var i = 0; i < connected.length; i++) {
      var d = connected[i]
      list.push({
        key: "c-" + (d.address || i),
        kind: "disconnect",
        label: BtModel.deviceLabel(d),
        detail: d.address || "",
        glyph: "󰂱",
        current: true,
        address: d.address || ""
      })
    }
    var known = groups.known || []
    for (var k = 0; k < known.length; k++) {
      var n = known[k]
      list.push({
        key: "k-" + (n.address || k),
        kind: "connect",
        label: BtModel.deviceLabel(n),
        detail: n.address || "",
        glyph: "󰂲",
        current: false,
        address: n.address || ""
      })
    }
    return list
  }

  function deviceFor(address) {
    var addr = String(address || "")
    var devs = devices || []
    for (var i = 0; i < devs.length; i++) {
      if ((devs[i].address || "") === addr) return devs[i]
    }
    return null
  }

  function activate(item) {
    if (!item) return "close"
    if (item.kind === "power") {
      var on = !!(adapter && adapter.enabled)
      Quickshell.execDetached([Quickshell.shellDir + "/bin/omarchy-bluetooth-power", on ? "off" : "on"])
      return "close"
    }
    var device = deviceFor(item.address)
    if (!device || !item.address) return "close"
    if (item.kind === "disconnect") {
      if (device.disconnect) device.disconnect()
      Quickshell.execDetached([Quickshell.shellDir + "/bin/omarchy-bluetooth-device", "disconnect", item.address])
    } else {
      Quickshell.execDetached([Quickshell.shellDir + "/bin/omarchy-bluetooth-device", "connect", item.address])
    }
    return "close"
  }
}
