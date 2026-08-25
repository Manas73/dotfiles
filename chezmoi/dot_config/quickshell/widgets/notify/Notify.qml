import QtQuick
import Quickshell
import Quickshell.Io
import qs.components

Item {
  id: root

  property var bar: null

  readonly property var notifier: bar && bar.shell ? bar.shell.firstPartyServiceFor("notifications") : null
  readonly property bool dnd: notifier ? notifier.doNotDisturb : false
  readonly property int unread: notifier ? notifier.unreadCount : 0
  readonly property bool opened: centerLoader.item ? centerLoader.item.opened === true : false
  readonly property string bell: dnd ? "󰂛" : (unread > 0 ? "󰂚" : "󰂜")

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function injectCenter() {
    var panel = centerLoader.item
    if (!panel) return
    panel.bar = root.bar
    panel.anchorItem = root
    panel.hostWidget = root
  }

  function open() {
    if (centerLoader.item) centerLoader.item.open()
  }

  function close() {
    if (centerLoader.item) centerLoader.item.close()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function toggleDnd() {
    if (notifier) notifier.setDoNotDisturb(!notifier.doNotDisturb)
  }

  Loader {
    id: centerLoader
    active: true
    source: Qt.resolvedUrl("Center.qml")
    visible: false
    onLoaded: {
      root.injectCenter()
      Qt.callLater(root.injectCenter)
    }
  }

  onBarChanged: injectCenter()

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.bell
    slotSize: Style.bar.statusSlot
    active: root.dnd || root.unread > 0
    tooltipText: root.dnd ? "Notifications paused" : (root.unread > 0 ? (root.unread + " new") : "Notifications")
    onPressed: function(b) {
      if (b === Qt.RightButton) root.toggleDnd()
      else root.toggle()
    }
  }

  Rectangle {
    visible: root.unread > 0 && !root.dnd
    width: Style.space(7)
    height: Style.space(7)
    radius: width / 2
    color: Color.urgent
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: Style.space(4)
    anchors.topMargin: Style.space(6)
  }

  IpcHandler {
    enabled: {
      var window = root.QsWindow ? root.QsWindow.window : null
      var screens = Quickshell.screens
      return !!(window && window.screen && screens.length && window.screen === screens[0])
    }
    target: "notify"

    function toggle(): string { root.toggle(); return "ok" }
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
  }
}
