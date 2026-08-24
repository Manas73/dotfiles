import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Hyprland workspaces, aligned with ~/.config/waybar `hyprland/workspaces`:
// per-id nerd icons, sort-by-number, click to activate, all workspaces on
// this output (not active-only, not all-outputs).
BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  readonly property var defaultIcons: ({
    "1": "",
    "2": "",
    "3": "",
    "4": "",
    "5": "",
    "6": "",
    "7": "",
    "8": "",
    "default": "󰒅"
  })
  readonly property var defaultPersistentGroups: [
    [1, 2, 3, 4, 5],
    [6, 7, 8, 9, 10]
  ]

  readonly property var icons: {
    var value = setting("icons", null)
    return Util.isPlainObject(value) ? value : root.defaultIcons
  }
  readonly property var persistentGroups: {
    var value = setting("persistentGroups", null)
    return Array.isArray(value) && value.length > 0 ? value : root.defaultPersistentGroups
  }
  readonly property bool allOutputs: setting("allOutputs", false) === true
  readonly property bool activeOnly: setting("activeOnly", false) === true
  readonly property bool hideEmpty: setting("hideEmpty", true) !== false

  readonly property string screenName: {
    var window = root.QsWindow ? root.QsWindow.window : null
    return window && window.screen ? String(window.screen.name || "") : ""
  }

  readonly property var workspaceIds: {
    var values = Hyprland.workspaces.values
    var monitors = Hyprland.monitors ? Hyprland.monitors.values : []
    var screen = root.screenName
    var ids = []
    var seen = ({})

    function addId(id) {
      var n = Number(id)
      if (!isFinite(n) || n < 1) return
      if (seen[n]) return
      seen[n] = true
      ids.push(n)
    }

    var activeId = root.activeIdOnScreen(screen, values, monitors)
    if (!root.hideEmpty) {
      var persistent = root.persistentIdsForScreen(screen, values, monitors)
      for (var p = 0; p < persistent.length; p++) addId(persistent[p])
    } else if (activeId > 0) {
      addId(activeId)
    }

    for (var i = 0; i < values.length; i++) {
      var ws = values[i]
      if (!ws || ws.id < 1) continue
      if (!root.allOutputs && !root.workspaceOnScreen(ws, screen)) continue
      var occupied = ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0
      if (root.hideEmpty && !occupied && ws.id !== activeId) continue
      addId(ws.id)
    }

    if (root.activeOnly)
      ids = ids.filter(function(id) { return id === activeId })

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  function workspaceMonitorName(ws) {
    if (!ws) return ""
    if (ws.monitor && ws.monitor.name) return String(ws.monitor.name)
    var ipc = ws.lastIpcObject
    if (ipc && ipc.monitor) return String(ipc.monitor)
    return ""
  }

  function workspaceOnScreen(ws, screen) {
    if (!screen) return true
    var name = root.workspaceMonitorName(ws)
    return name === "" || name === screen
  }

  function activeIdOnScreen(screen, values, monitors) {
    for (var m = 0; monitors && m < monitors.length; m++) {
      var monitor = monitors[m]
      if (!monitor || String(monitor.name || "") !== screen) continue
      var active = monitor.activeWorkspace || monitor.focusedWorkspace
      if (active && active.id > 0) return active.id
    }
    if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0)
      return Hyprland.focusedWorkspace.id
    for (var i = 0; i < values.length; i++) {
      if (values[i] && values[i].id > 0 && root.workspaceOnScreen(values[i], screen))
        return values[i].id
    }
    return 0
  }

  function persistentIdsForScreen(screen, values, monitors) {
    var groups = root.persistentGroups
    if (!Array.isArray(groups) || groups.length === 0) return []

    function groupIndexForId(id) {
      for (var g = 0; g < groups.length; g++) {
        var group = groups[g]
        if (Array.isArray(group) && group.indexOf(id) !== -1) return g
      }
      return -1
    }

    for (var i = 0; i < values.length; i++) {
      var ws = values[i]
      if (!ws || ws.id < 1) continue
      if (!root.workspaceOnScreen(ws, screen)) continue
      var idx = groupIndexForId(ws.id)
      if (idx >= 0) return groups[idx]
    }

    var activeId = root.activeIdOnScreen(screen, values, monitors)
    var activeIdx = groupIndexForId(activeId)
    if (activeIdx >= 0) return groups[activeIdx]

    return groups[0]
  }

  function iconFor(id) {
    var map = root.icons
    var key = String(id)
    if (map[key]) return map[key]
    if (id === 10 && map["0"]) return map["0"]
    return map["default"] || "󰒅"
  }

  function isUrgent(ws) {
    if (!ws) return false
    if (ws.urgent === true) return true
    var toplevels = ws.toplevels ? ws.toplevels.values : []
    for (var i = 0; i < toplevels.length; i++) {
      if (toplevels[i] && toplevels[i].urgent === true) return true
    }
    return false
  }

  function focusWorkspace(id) {
    if (typeof Hyprland.dispatch === "function") {
      Hyprland.dispatch("workspace " + String(id))
      return
    }
    if (root.bar) root.bar.run("hyprctl dispatch workspace " + String(id))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : Math.max(1, root.workspaceIds.length)
    columnSpacing: root.vertical ? 0 : Style.space(3)
    rowSpacing: root.vertical ? Style.space(3) : 0

    Repeater {
      model: root.workspaceIds

      Item {
        id: pill
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        readonly property bool visibleHere: {
          if (!workspace) return false
          var monitor = workspace.monitor
          var active = monitor && (monitor.activeWorkspace || monitor.focusedWorkspace)
          if (active && active.id === modelData) return true
          return pill.focused
        }
        readonly property bool urgent: root.isUrgent(workspace)
        property bool hovered: false
        readonly property bool emphasized: pill.focused || pill.visibleHere || pill.hovered

        Layout.preferredWidth: root.vertical ? root.barSize : pill.width
        Layout.preferredHeight: root.vertical ? pill.height : root.barSize
        Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter

        width: root.vertical ? root.barSize : Math.max(emphasized ? Style.space(50) : Style.space(40), icon.implicitWidth + Style.space(12))
        height: root.vertical ? Math.max(emphasized ? Style.space(50) : Style.space(40), icon.implicitHeight + Style.space(8)) : root.barSize

        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Rectangle {
          id: plate
          anchors.centerIn: parent
          width: parent.width
          height: Math.min(parent.height - Style.space(4), Style.space(22))
          radius: Style.space(5)
          color: pill.urgent
            ? Color.urgent
            : (pill.emphasized
              ? Color.accent
              : Util.alpha(Color.foreground, pill.occupied ? 0.14 : 0.06))

          Behavior on color { ColorAnimation { duration: 180 } }
        }

        Text {
          id: icon
          anchors.centerIn: parent
          text: root.iconFor(modelData)
          color: pill.urgent || pill.emphasized ? Color.background : Color.bar.text
          opacity: pill.occupied || pill.emphasized || pill.urgent ? 1 : 0.55
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.iconLarge
          renderType: Text.NativeRendering
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter

          Behavior on color { ColorAnimation { duration: 160 } }
          Behavior on opacity { NumberAnimation { duration: 140 } }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton
          onEntered: {
            pill.hovered = true
            if (root.bar) root.bar.showTooltip(pill, "Workspace " + modelData)
          }
          onExited: {
            pill.hovered = false
            if (root.bar) root.bar.hideTooltip(pill)
          }
          onClicked: root.focusWorkspace(modelData)
        }
      }
    }
  }
}
