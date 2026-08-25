import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.components

Item {
  id: root

  property var bar: null
  property string submap: ""

  readonly property bool onFocusedMonitor: {
    var window = root.QsWindow ? root.QsWindow.window : null
    var screen = window && window.screen ? String(window.screen.name || "") : ""
    var focused = Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""
    return screen.length > 0 && screen === focused
  }

  readonly property bool active: {
    var name = String(root.submap || "").trim()
    return name.length > 0 && name !== "reset" && name !== "default"
  }

  readonly property string label: {
    var names = {
      resize: "Resize",
      rofi_menus: "Menus",
      ide: "IDE",
      group: "Group"
    }
    var id = String(root.submap || "")
    if (names[id]) return names[id]
    return id.replace(/_/g, " ")
  }

  visible: active && onFocusedMonitor
  implicitWidth: visible ? pill.implicitWidth + Style.space(8) : 0
  implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal
  clip: true

  function apply(name) {
    root.submap = String(name || "").trim()
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!event || String(event.name || "") !== "submap") return
      var parts = []
      try {
        if (event.parse) parts = event.parse(1)
      } catch (e) {}
      if (!parts || !parts.length)
        parts = [String(event.data || "")]
      root.apply(parts[0])
    }
  }

  Process {
    id: query
    command: ["hyprctl", "submap"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.apply(String(text || "").trim().split("\n")[0])
    }
  }

  Component.onCompleted: query.running = true

  Rectangle {
    id: pill
    x: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: labelText.implicitWidth + Style.space(16)
    implicitHeight: Math.round(Style.font.caption + Style.space(10))
    radius: height / 2
    color: Color.accent

    Text {
      id: labelText
      anchors.centerIn: parent
      text: root.label
      color: Color.background
      font.family: "Adwaita Sans"
      font.pixelSize: Style.font.caption
      font.weight: Font.DemiBold
    }
  }
}
