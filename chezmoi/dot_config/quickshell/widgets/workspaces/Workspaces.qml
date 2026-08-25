import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.components
import "Workspaces.js" as Model

Item {
  id: root

  property var bar: null
  property var icons: ({
    "1": "", "2": "", "3": "", "4": "",
    "5": "", "6": "", "7": "", "8": "",
    "default": "󰒅"
  })
  property var persistentGroups: [[1, 2, 3, 4, 5], [6, 7, 8, 9, 10]]
  property bool allOutputs: false
  property bool activeOnly: false
  property bool hideEmpty: true

  readonly property bool vertical: bar ? bar.vertical : false
  readonly property string screenName: {
    var window = root.QsWindow ? root.QsWindow.window : null
    return window && window.screen ? String(window.screen.name || "") : ""
  }
  readonly property var workspaceIds: Model.collectIds({
    values: Hyprland.workspaces.values,
    monitors: Hyprland.monitors ? Hyprland.monitors.values : [],
    screen: screenName,
    hyprland: Hyprland,
    hideEmpty: hideEmpty,
    allOutputs: allOutputs,
    activeOnly: activeOnly,
    persistentGroups: persistentGroups
  })

  implicitWidth: grid.implicitWidth
  implicitHeight: grid.implicitHeight

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  function activate(ws, id) {
    if (ws && typeof ws.activate === "function") {
      ws.activate()
      return
    }
    Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(id)])
  }

  GridLayout {
    id: grid
    columns: root.vertical ? 1 : Math.max(1, root.workspaceIds.length)
    columnSpacing: 0
    rowSpacing: 0

    Repeater {
      model: root.workspaceIds

      Item {
        id: cell
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace && workspace.toplevels && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData
        readonly property bool urgent: Model.isUrgent(workspace)
        readonly property color glyphColor: urgent
          ? Color.urgent
          : (focused || mouse.containsMouse ? Color.accent : Color.bar.text)

        Layout.preferredWidth: Style.bar.iconSlot + Style.space(4)
        Layout.preferredHeight: bar ? bar.barSize : Style.bar.sizeHorizontal
        implicitWidth: Layout.preferredWidth
        implicitHeight: Layout.preferredHeight

        OpticalGlyph {
          anchors.centerIn: parent
          width: Style.bar.iconCanvas
          height: Style.bar.iconCanvas
          text: Model.iconFor(root.icons, modelData)
          fontFamily: bar ? bar.fontFamily : Style.font.family
          fontSize: Style.bar.iconFont
          color: cell.glyphColor
          opacity: cell.focused || cell.urgent || mouse.containsMouse ? 1 : 0.72
          Behavior on color { ColorAnimation { duration: 140 } }
          Behavior on opacity { NumberAnimation { duration: 140 } }
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.activate(cell.workspace, modelData)
        }
      }
    }
  }
}
