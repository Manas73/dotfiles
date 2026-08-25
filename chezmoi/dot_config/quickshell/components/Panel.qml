import QtQuick
import Quickshell
import Quickshell.Io
import qs.components

// Base item for plugin popup widgets. Many first-party plugins expose a bar
// button plus a popup from one QML entry point; this base owns the shared
// IPC-backed open/close lifecycle while implementations own button behavior,
// keyboard navigation, and content.
Item {
  id: root

  property QtObject bar: null
  property string moduleName: ""
  property var settings: ({})
  property string ipcTarget: ""
  property bool manageIpc: true
  property alias controller: panelController
  property bool popoutSwitching: false
  property bool popoutSwitchClosing: false

  readonly property bool opened: panelController.open
  readonly property color barForeground: bar ? bar.barForeground : Color.foreground
  // Nested panels (e.g. weather) identify as their host bar widget.
  property var hostWidget: null
  readonly property bool ipcOwner: {
    var key = hostWidget || root
    if (bar && typeof bar.moduleWidgets === "function") {
      var items = bar.moduleWidgets(moduleName)
      return !moduleName || items.length === 0 || items[0] === key || items[0] === root
    }
    var window = key.QsWindow ? key.QsWindow.window : (root.QsWindow ? root.QsWindow.window : null)
    var screens = Quickshell.screens
    if (!window || !window.screen || !screens || screens.length === 0) return true
    return window.screen === screens[0]
  }

  function open() { panelController.show() }
  function close() { panelController.hide() }
  function closeForPopoutSwitch() {
    popoutSwitchClosing = true
    close()
    Qt.callLater(function() { popoutSwitchClosing = false })
  }
  function toggle() { opened ? close() : open() }
  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function") return bar.switchPanelFrom(root, direction)
    return false
  }

  // Read a single value from this panel's inline shell.json entry, with a
  // fallback for missing/null values. Matches BarWidget.setting().
  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  PanelController {
    id: panelController
  }

  IpcHandler {
    enabled: root.manageIpc && root.ipcTarget !== "" && root.ipcOwner
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

}
