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
    if (bar && typeof bar.moduleWidgets === "function" && moduleName) {
      var items = bar.moduleWidgets(moduleName)
      if (items.length > 0)
        return items[0] === key || items[0] === root
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

  // IPC is registered on one instance, but a bar exists per monitor.
  // Hotkeys should open the copy on Hyprland's focused display, not
  // whichever screen happened to own the IpcHandler.
  function invokeFocused(method) {
    var fn = String(method || "")
    if (bar && typeof bar.callOnFocused === "function" && moduleName)
      return bar.callOnFocused(moduleName, fn)
    if (typeof root[fn] === "function") return root[fn]()
  }

  property var _registeredBar: null
  property string _registeredName: ""
  property var _registeredItem: null

  function syncModuleRegistry() {
    if (_registeredBar && typeof _registeredBar.unregisterModuleWidget === "function")
      _registeredBar.unregisterModuleWidget(_registeredName, _registeredItem)
    _registeredBar = null
    _registeredName = ""
    _registeredItem = null
    if (!bar || !moduleName || typeof bar.registerModuleWidget !== "function") return
    bar.registerModuleWidget(moduleName, root)
    _registeredBar = bar
    _registeredName = moduleName
    _registeredItem = root
  }

  onBarChanged: syncModuleRegistry()
  onModuleNameChanged: syncModuleRegistry()
  Component.onCompleted: syncModuleRegistry()
  Component.onDestruction: {
    if (_registeredBar && typeof _registeredBar.unregisterModuleWidget === "function")
      _registeredBar.unregisterModuleWidget(_registeredName, _registeredItem)
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

    function open(): void { root.invokeFocused("open") }
    function close(): void { root.invokeFocused("close") }
    function show(): void { root.invokeFocused("open") }
    function hide(): void { root.invokeFocused("close") }
    function toggle(): void { root.invokeFocused("toggle") }
  }

}
