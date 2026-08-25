import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.components

Panel {
  id: root
  moduleName: "notify"
  ipcTarget: "notify"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var notifier: bar && bar.shell ? bar.shell.firstPartyServiceFor("notifications") : null
  readonly property var history: notifier ? notifier.historyModel : null
  readonly property int count: history ? history.count : 0
  readonly property bool dnd: notifier ? notifier.doNotDisturb : false
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var barWindow: anchorItem && anchorItem.QsWindow ? anchorItem.QsWindow.window : null
  readonly property int topGap: (bar ? bar.barSize : Style.bar.sizeHorizontal) + Style.gapsOut
  readonly property int drawerWidth: Style.space(380)

  function open() {
    if (notifier) {
      notifier.refreshHistory()
      notifier.markHistorySeen()
    }
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  onOpenedChanged: {
    if (!bar) return
    if (opened) bar.requestPopout(barIdentity)
    else if (bar.activePopout === barIdentity) bar.releasePopout(barIdentity)
  }

  PanelWindow {
    id: layer
    screen: root.barWindow ? root.barWindow.screen : null
    visible: root.opened || drawer.x < width
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-notify-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }

    HyprlandFocusGrab {
      active: root.opened
      windows: root.barWindow ? [layer, root.barWindow] : [layer]
      onCleared: root.close()
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.opened
      onClicked: root.close()
    }

    BorderSurface {
      id: drawer
      width: root.drawerWidth
      height: parent.height - root.topGap - Style.gapsOut
      y: root.topGap
      x: root.opened ? parent.width - width - Style.gapsOut : parent.width
      color: Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
      radius: Style.cornerRadius

      Behavior on x {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.spacing.panelPadding
        spacing: Style.space(10)

        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: false
          Layout.alignment: Qt.AlignTop
          spacing: Style.space(8)

          Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: "Notifications"
            color: Color.popups.text
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          WidgetButton {
            Layout.alignment: Qt.AlignVCenter
            bar: root.bar
            text: root.dnd ? "󰂛" : "󰂚"
            tooltipText: root.dnd ? "Resume notifications" : "Pause notifications"
            fontFamily: root.fontFamily
            onPressed: function() {
              if (root.notifier) root.notifier.setDoNotDisturb(!root.dnd)
            }
          }

          WidgetButton {
            Layout.alignment: Qt.AlignVCenter
            bar: root.bar
            text: "Clear"
            dimmed: root.count === 0
            pressable: root.count > 0
            tooltipText: root.count === 0 ? "Nothing to clear" : "Clear all"
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            onPressed: function() {
              if (root.notifier) root.notifier.clearAll()
            }
          }
        }

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true

          Text {
            visible: root.count === 0
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            text: root.dnd ? "Notifications paused" : "No recent notifications"
            color: Qt.darker(Color.popups.text, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          ListView {
            anchors.fill: parent
            visible: root.count > 0
            clip: true
            spacing: Style.space(6)
            model: root.history
            boundsBehavior: Flickable.StopAtBounds

            delegate: HistoryRow {
              width: ListView.view ? ListView.view.width : root.drawerWidth
              app: model.app || ""
              summary: model.summary || ""
              body: model.body || ""
              glyph: model.glyph || ""
              timestamp: model.timestamp || 0
              fontFamily: root.fontFamily
            }
          }
        }
      }
    }
  }
}
