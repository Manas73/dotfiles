import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.components

Item {
  id: root

  property var shell: null
  property string position: "top"
  property bool transparent: false
  property Component leftSection: null
  property Component centerSection: null
  property Component rightSection: null

  readonly property bool vertical: position === "left" || position === "right"
  readonly property int barSize: vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  readonly property string fontFamily: Style.font.family
  readonly property color barForeground: Color.bar.text
  readonly property color foreground: Color.bar.text
  readonly property color background: Color.bar.background
  readonly property color urgent: Color.bar.active
  property bool foregroundAnimationEnabled: true
  property bool barHidden: false

  property var activePopout: null
  property Item tooltipTarget: null
  property string tooltipText: ""

  function run(command) {
    Util.execDetached(command)
  }

  function showTooltip(target, text) {
    if (!text) {
      hideTooltip(target)
      return
    }
    tooltipTarget = target
    tooltipText = String(text)
  }

  function hideTooltip(target) {
    if (target && tooltipTarget !== target) return
    tooltipTarget = null
    tooltipText = ""
  }

  function requestPopout(owner) {
    if (activePopout && activePopout !== owner && activePopout.close)
      activePopout.close()
    activePopout = owner
  }

  function releasePopout(owner) {
    if (activePopout === owner) activePopout = null
  }

  function injectBar(item) {
    if (!item) return
    if (item.bar !== undefined) item.bar = root
    var kids = item.children || []
    for (var i = 0; i < kids.length; i++) injectBar(kids[i])
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: window
      required property var modelData
      screen: modelData

      visible: true
      exclusionMode: ExclusionMode.Auto
      implicitWidth: root.vertical ? root.barSize : 0
      implicitHeight: root.vertical ? 0 : root.barSize
      color: "transparent"
      surfaceFormat.opaque: false
      WlrLayershell.namespace: "quickshell"
      WlrLayershell.layer: WlrLayer.Top

      anchors {
        top: root.position === "top" || root.vertical
        bottom: root.position === "bottom" || root.vertical
        left: root.position === "left" || !root.vertical
        right: root.position === "right" || !root.vertical
      }

      Rectangle {
        anchors.fill: parent
        color: root.transparent ? "transparent" : root.background
      }

      Item {
        anchors.fill: parent
        anchors.leftMargin: root.vertical ? 0 : Style.space(8)
        anchors.rightMargin: root.vertical ? 0 : Style.space(8)
        anchors.topMargin: root.vertical ? Style.space(8) : 0
        anchors.bottomMargin: root.vertical ? Style.space(8) : 0

        Loader {
          id: leftLoader
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          sourceComponent: root.leftSection
          onLoaded: {
            root.injectBar(item)
            Qt.callLater(function() { root.injectBar(item) })
          }
        }

        Loader {
          id: centerLoader
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          sourceComponent: root.centerSection
          onLoaded: {
            root.injectBar(item)
            Qt.callLater(function() { root.injectBar(item) })
          }
        }

        Loader {
          id: rightLoader
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          sourceComponent: root.rightSection
          onLoaded: {
            root.injectBar(item)
            Qt.callLater(function() { root.injectBar(item) })
          }
        }
      }

      Tooltip {
        bar: root
        barWindow: window
      }
    }
  }
}
