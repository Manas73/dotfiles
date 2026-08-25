import QtQuick
import Quickshell
import qs.components

PopupWindow {
  id: root

  required property var bar
  required property var barWindow

  visible: bar.tooltipTarget !== null && bar.tooltipText !== "" && belongsToWindow
  color: "transparent"
  implicitWidth: Math.ceil(bubble.implicitWidth)
  implicitHeight: Math.ceil(bubble.implicitHeight)

  readonly property bool belongsToWindow: {
    var target = bar.tooltipTarget
    if (!target || !barWindow) return false
    var win = target.QsWindow ? target.QsWindow.window : null
    return win === barWindow
  }

  anchor {
    id: tooltipAnchor
    window: root.barWindow
    adjustment: PopupAdjustment.Slide
    edges: Edges.Top | Edges.Left
    gravity: Edges.Bottom | Edges.Right
    rect.width: 1
    rect.height: 1

    onAnchoring: {
      var target = bar.tooltipTarget
      if (!root.belongsToWindow) return

      var localX = target.width / 2 - root.implicitWidth / 2
      var localY = target.height + 6
      if (bar.position === "bottom") localY = -root.implicitHeight - 6
      else if (bar.position === "left") {
        localX = target.width + 6
        localY = target.height / 2 - root.implicitHeight / 2
      } else if (bar.position === "right") {
        localX = -root.implicitWidth - 6
        localY = target.height / 2 - root.implicitHeight / 2
      }

      var point = barWindow.contentItem.mapFromItem(target, localX, localY)
      tooltipAnchor.rect.x = Math.round(point.x)
      tooltipAnchor.rect.y = Math.round(point.y)
    }
  }

  BorderSurface {
    id: bubble
    implicitWidth: label.implicitWidth + 20
    implicitHeight: label.implicitHeight + 14
    color: Color.tooltip.background
    borderSpec: Border.surfaceSpec("tooltip", "border", Color.tooltip.border, 1)
    radius: Style.cornerRadius

    Text {
      id: label
      anchors.centerIn: parent
      text: bar.tooltipText
      color: Color.tooltip.text
      font.family: bar.fontFamily
      font.pixelSize: Style.font.body
    }
  }
}
