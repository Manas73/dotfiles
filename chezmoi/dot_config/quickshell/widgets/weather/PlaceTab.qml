import QtQuick
import qs.components

// One place chip in the weather tab strip. Close lives inside the chip so
// it does not read as a second button, and it is a dedicated hit target.
BorderSurface {
  id: root

  property string title: ""
  property bool selected: false
  property bool removable: false
  property bool renaming: false
  property color foreground: Color.foreground
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property real fontSize: Style.font.bodySmall

  signal activated()
  signal removed()
  signal renameRequested()
  signal renameCommitted(string name)
  signal renameCanceled()

  readonly property bool hot: tabArea.containsMouse
  readonly property color _selectedColor: Style.selectedStateColor(root.foreground, root.accent)

  implicitWidth: chipRow.implicitWidth + Style.spacing.controlPaddingX * 2 + Border.left(_borderSpec) + Border.right(_borderSpec)
  implicitHeight: Math.max(Style.spacing.controlHeight, chipRow.implicitHeight + Style.spacing.controlPaddingY * 2)
  radius: Style.cornerRadius
  color: tabArea.pressed ? Style.pressedFillFor(root.foreground, root.accent)
    : root.hot            ? Style.hoverFillFor(root.foreground, root.accent)
    : root.selected       ? Style.selectedFillFor(root.foreground, root.accent)
    : "transparent"
  borderSpec: _borderSpec

  readonly property var _borderSpec: root.hot
    ? Border.controlSpec("hover-cursor", root.foreground, root.accent)
    : root.selected
      ? (Border.controlHasWidth("selected")
        ? Border.controlSpec("selected", root.foreground, root.accent)
        : Border.controlSpec("normal", root.foreground, root.accent))
      : Border.controlSpec("normal", root.foreground, root.accent)

  Behavior on color { ColorAnimation { duration: 120 } }

  function commitRename() {
    if (!root.renaming) return
    root.renameCommitted(renameField.text)
  }

  onRenamingChanged: {
    if (!root.renaming) return
    renameField.text = root.title === "Auto" ? "" : root.title
    Qt.callLater(function() {
      if (!root.renaming) return
      renameField.forceActiveFocus()
      renameField.selectAll()
    })
  }

  MouseArea {
    id: tabArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    enabled: !root.renaming
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.renameRequested()
      else root.activated()
    }
  }

  Row {
    id: chipRow
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: Style.spacing.controlPaddingX
    spacing: Style.space(8)

    Text {
      visible: !root.renaming
      text: root.title
      color: root.selected ? root._selectedColor : root.foreground
      font.family: root.fontFamily
      font.pixelSize: root.fontSize
      font.bold: root.selected
      anchors.verticalCenter: parent.verticalCenter
    }

    TextInput {
      id: renameField
      visible: root.renaming
      width: Style.space(140)
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: root.fontSize
      selectByMouse: true
      clip: true
      anchors.verticalCenter: parent.verticalCenter
      onAccepted: root.commitRename()
      onActiveFocusChanged: if (!activeFocus && root.renaming) root.commitRename()
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.renameCanceled()
          event.accepted = true
        }
      }
    }

    Item {
      visible: root.removable && !root.renaming
      width: visible ? Style.space(16) : 0
      height: Style.space(16)
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.fill: parent
        radius: Math.min(4, Style.cornerRadius)
        color: closeArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"
      }

      Text {
        anchors.centerIn: parent
        text: "✕"
        color: closeArea.containsMouse ? root.foreground : Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      MouseArea {
        id: closeArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: function(mouse) {
          mouse.accepted = true
          root.removed()
        }
      }
    }
  }
}
