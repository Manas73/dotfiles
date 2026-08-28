import QtQuick
import Quickshell

Item {
  id: root

  property bool active: false
  property string mode: "menu"  // "menu" | "confirm"
  property string pending: ""
  readonly property string prompt: mode === "confirm" ? "Are you sure?" : "Power"
  readonly property bool showSearch: false
  readonly property int initialIndex: 0
  readonly property var items: mode === "confirm" ? confirmItems() : menuItems()

  onActiveChanged: {
    if (active) {
      mode = "menu"
      pending = ""
    }
  }

  function menuItems() {
    return [
      { key: "lock", kind: "lock", label: "Lock", glyph: "󰌾" },
      { key: "logout", kind: "logout", label: "Logout", glyph: "󰗽" },
      { key: "reboot", kind: "reboot", label: "Reboot", glyph: "󰜉" },
      { key: "shutdown", kind: "shutdown", label: "Shutdown", glyph: "󰐥", destructive: true }
    ]
  }

  function confirmItems() {
    return [
      { key: "yes", kind: "yes", label: "Yes", glyph: "󰄬", destructive: pending === "shutdown" },
      { key: "no", kind: "no", label: "No", glyph: "󰅖" }
    ]
  }

  function run(kind) {
    var bin = Quickshell.shellDir + "/bin/"
    if (kind === "lock") Quickshell.execDetached([bin + "omarchy-system-lock"])
    else if (kind === "logout") Quickshell.execDetached([bin + "omarchy-system-logout"])
    else if (kind === "reboot") Quickshell.execDetached([bin + "omarchy-system-reboot"])
    else if (kind === "shutdown") Quickshell.execDetached([bin + "omarchy-system-shutdown"])
  }

  function back() {
    if (mode !== "confirm") return false
    mode = "menu"
    pending = ""
    return true
  }

  function activate(item) {
    if (!item) return "close"
    if (item.kind === "no") {
      back()
      return "stay"
    }
    if (item.kind === "yes") {
      run(pending)
      return "close"
    }
    if (item.kind === "lock") {
      run("lock")
      return "close"
    }
    pending = item.kind
    mode = "confirm"
    return "stay"
  }
}
