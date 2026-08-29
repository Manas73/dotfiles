import QtQuick
import qs.components

// Weather + radar for one place. The panel binds this to the active tab.
Item {
  id: root

  property string location: ""
  property string units: ""
  property bool active: false
  property int refreshMinutes: 15
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property int fontPixelSize: Style.font.bodySmall
  property int cellW: 8
  property int cellH: 16
  property int sectionPad: Style.space(10)
  property int sectionGap: Style.spacing.panelGap

  function refresh() {
    weatherView.refresh()
    radarView.refresh()
  }

  Row {
    anchors.fill: parent
    spacing: root.sectionGap

    LinecastSection {
      title: "WEATHER"
      width: Math.floor((parent.width - parent.spacing) / 2)
      height: parent.height
      foreground: root.foreground
      fontFamily: root.fontFamily
      padding: root.sectionPad

      LinecastView {
        id: weatherView
        anchors.fill: parent
        viewName: "weather"
        location: root.location
        units: root.units
        active: root.active
        refreshMs: root.refreshMinutes * 60 * 1000
        foreground: root.foreground
        fontFamily: root.fontFamily
        fontPixelSize: root.fontPixelSize
        cellW: root.cellW
        cellH: root.cellH
      }
    }

    LinecastSection {
      title: "RADAR"
      width: parent.width - parent.children[0].width - parent.spacing
      height: parent.height
      foreground: root.foreground
      fontFamily: root.fontFamily
      padding: root.sectionPad

      LinecastView {
        id: radarView
        anchors.fill: parent
        viewName: "radar"
        location: root.location
        units: root.units
        active: root.active
        refreshMs: 20000
        foreground: root.foreground
        fontFamily: root.fontFamily
        fontPixelSize: root.fontPixelSize
        cellW: root.cellW
        cellH: root.cellH
      }
    }
  }
}
