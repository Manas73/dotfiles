import QtQuick
import Quickshell
import Quickshell.Networking
import "../../widgets/network/Model.js" as NetModel

Item {
  id: root

  property bool active: false
  property string mode: "main"  // "main" | "new"
  readonly property string prompt: mode === "new" ? "New Wi-Fi Network" : "Wi-Fi SSID"
  readonly property int initialIndex: mode === "new" ? 1 : (connectedName ? 2 : 1)
  readonly property bool networkManagerAvailable: Networking.backend === NetworkBackendType.NetworkManager
  readonly property var networkDevices: Networking.devices ? Networking.devices.values : []
  readonly property var wifiDevice: findDevice(DeviceType.Wifi)
  readonly property var wifiNetworkObjects: wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []
  readonly property bool wifiOn: Networking.wifiEnabled
  readonly property string connectedName: {
    var n = findConnected()
    return n ? (n.name || "") : ""
  }
  readonly property var items: buildItems()

  onActiveChanged: {
    if (active) {
      mode = "main"
      setScanner(true)
    } else {
      mode = "main"
      setScanner(false)
    }
  }

  function findDevice(type) {
    var devices = networkDevices || []
    var fallback = null
    for (var i = 0; i < devices.length; i++) {
      var device = devices[i]
      if (!device || device.type !== type) continue
      if (device.connected) return device
      if (!fallback) fallback = device
    }
    return fallback
  }

  function findConnected() {
    var networks = wifiNetworkObjects || []
    for (var i = 0; i < networks.length; i++) {
      if (networks[i] && networks[i].connected) return networks[i]
    }
    return null
  }

  function networkForSsid(ssid) {
    var name = String(ssid || "")
    var networks = wifiNetworkObjects || []
    for (var i = 0; i < networks.length; i++) {
      if (networks[i] && (networks[i].name || "") === name) return networks[i]
    }
    return null
  }

  function setScanner(on) {
    if (wifiDevice) wifiDevice.scannerEnabled = !!on
  }

  function needsPassword(net) {
    if (!net) return false
    return NetModel.requiresCredentials(net.security, WifiSecurityType.Open, WifiSecurityType.Owe)
  }

  function buildItems() {
    var rows = []
    var objects = wifiNetworkObjects || []
    for (var i = 0; i < objects.length; i++) {
      var row = NetModel.wifiRow(objects[i])
      if (row && row.ssid) rows.push(row)
    }
    rows = NetModel.sortWifiRows(rows)

    var list = []
    if (mode === "main") {
      list.push({
        key: "power",
        kind: "power",
        label: wifiOn ? "Disable Wi-Fi" : "Enable Wi-Fi",
        glyph: wifiOn ? "󰖪" : "󰖩",
        current: false
      })
      if (connectedName) {
        list.push({
          key: "up-" + connectedName,
          kind: "disconnect",
          label: connectedName,
          glyph: "󰖩",
          current: true,
          ssid: connectedName
        })
      }
      list.push({
        key: "rescan",
        kind: "rescan",
        label: "Rescan Wi-Fi",
        glyph: "",
        current: false
      })
      for (var k = 0; k < rows.length; k++) {
        var known = rows[k]
        if (!known.known || known.connected) continue
        list.push({
          key: "known-" + known.ssid,
          kind: "connect",
          label: known.ssid,
          glyph: "󰤨",
          current: false,
          ssid: known.ssid
        })
      }
      list.push({
        key: "new",
        kind: "new",
        label: "New Connection",
        glyph: "󰏖",
        current: false
      })
      return list
    }

    list.push({
      key: "rescan",
      kind: "rescan",
      label: "Rescan Wi-Fi",
      glyph: "",
      current: false
    })
    for (var u = 0; u < rows.length; u++) {
      var unknown = rows[u]
      if (unknown.known || unknown.connected || !unknown.ssid) continue
      var locked = needsPassword(networkForSsid(unknown.ssid))
      list.push({
        key: "new-" + unknown.ssid,
        kind: "join",
        label: unknown.ssid,
        detail: unknown.signal ? unknown.signal + "%" : "",
        glyph: locked ? "" : "",
        current: false,
        ssid: unknown.ssid,
        locked: locked
      })
    }
    return list
  }

  function activate(item) {
    if (!item) return "close"
    if (item.kind === "power") {
      Networking.wifiEnabled = !Networking.wifiEnabled
      return "close"
    }
    if (item.kind === "rescan") {
      setScanner(true)
      if (wifiDevice && wifiDevice.requestScan) wifiDevice.requestScan()
      return "stay"
    }
    if (item.kind === "new") {
      mode = "new"
      return "stay"
    }
    if (item.kind === "disconnect") {
      var up = networkForSsid(item.ssid)
      if (up && up.disconnect) up.disconnect()
      return "close"
    }
    if (item.kind === "connect") {
      var known = networkForSsid(item.ssid)
      if (known && known.connect) known.connect()
      return "close"
    }
    if (item.kind === "join") {
      var net = networkForSsid(item.ssid)
      if (!net) return "close"
      if (item.locked || needsPassword(net)) return "password"
      if (net.connect) net.connect()
      return "close"
    }
    return "close"
  }

  function connectWithPassword(ssid, password) {
    var net = networkForSsid(ssid)
    if (!net) return
    if (net.connectWithPsk) net.connectWithPsk(password)
    else if (net.connect) net.connect()
  }

  function back() {
    if (mode === "new") {
      mode = "main"
      return true
    }
    return false
  }
}
