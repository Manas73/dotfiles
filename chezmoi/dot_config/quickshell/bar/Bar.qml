import QtQuick
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
  readonly property int pillPad: Style.bar.padding
  readonly property int edgeGap: Style.bar.marginSide
  readonly property int edgeInset: Style.bar.marginTop
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
      implicitWidth: root.vertical ? root.barSize + root.edgeInset : 0
      implicitHeight: root.vertical ? 0 : root.barSize + root.edgeInset
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

      // Only the three pills take clicks; the gaps pass through to the desktop.
      mask: Region {
        Region { item: leftPill }
        Region { item: centerPill }
        Region { item: rightPill }
      }

      BarPill {
        id: leftPill
        slot: "start"
        content: root.leftSection
      }

      BarPill {
        id: centerPill
        slot: "center"
        content: root.centerSection
      }

      BarPill {
        id: rightPill
        slot: "end"
        content: root.rightSection
      }

      Tooltip {
        bar: root
        barWindow: window
      }
    }
  }

  // One island for a bar section. Sized to its widgets, capsule-rounded,
  // no idle chrome beyond the bar fill so the three islands stay quiet.
  component BarPill: BorderSurface {
    id: pill

    // "start" is left/top, "end" is right/bottom, matching the bar's reading order.
    property string slot: "start"
    property alias content: loader.sourceComponent

    readonly property real contentW: loader.item ? loader.item.implicitWidth : 0
    readonly property real contentH: loader.item ? loader.item.implicitHeight : 0
    readonly property bool hasContent: contentW > 0 && contentH > 0

    visible: hasContent
    width: !hasContent ? 0 : (root.vertical ? root.barSize : contentW + root.pillPad * 2)
    height: !hasContent ? 0 : (root.vertical ? contentH + root.pillPad * 2 : root.barSize)

    anchors.left: {
      if (!root.vertical && slot === "start") return parent.left
      if (root.vertical && root.position === "left") return parent.left
      return undefined
    }
    anchors.right: {
      if (!root.vertical && slot === "end") return parent.right
      if (root.vertical && root.position === "right") return parent.right
      return undefined
    }
    anchors.top: {
      if (!root.vertical && root.position === "top") return parent.top
      if (root.vertical && slot === "start") return parent.top
      return undefined
    }
    anchors.bottom: {
      if (!root.vertical && root.position === "bottom") return parent.bottom
      if (root.vertical && slot === "end") return parent.bottom
      return undefined
    }
    anchors.horizontalCenter: (!root.vertical && slot === "center") ? parent.horizontalCenter : undefined
    anchors.verticalCenter: {
      if (root.vertical && slot === "center") return parent.verticalCenter
      return undefined
    }
    anchors.leftMargin: {
      if (!root.vertical && slot === "start") return root.edgeGap
      if (root.vertical && root.position === "left") return root.edgeInset
      return 0
    }
    anchors.rightMargin: {
      if (!root.vertical && slot === "end") return root.edgeGap
      if (root.vertical && root.position === "right") return root.edgeInset
      return 0
    }
    anchors.topMargin: {
      if (!root.vertical && root.position === "top") return root.edgeInset
      if (root.vertical && slot === "start") return root.edgeGap
      return 0
    }
    anchors.bottomMargin: {
      if (!root.vertical && root.position === "bottom") return root.edgeInset
      if (root.vertical && slot === "end") return root.edgeGap
      return 0
    }

    color: root.transparent ? "transparent" : root.background
    radius: root.vertical ? width / 2 : height / 2
    borderSpec: Border.flat(Util.alpha(root.foreground, 0.12), 1)

    Loader {
      id: loader
      anchors.verticalCenter: parent.verticalCenter
      anchors.horizontalCenter: slot === "center" || root.vertical ? parent.horizontalCenter : undefined
      anchors.left: !root.vertical && slot === "start" ? parent.left : undefined
      anchors.right: !root.vertical && slot === "end" ? parent.right : undefined
      anchors.leftMargin: !root.vertical && slot === "start" ? root.pillPad : 0
      anchors.rightMargin: !root.vertical && slot === "end" ? root.pillPad : 0
      onLoaded: {
        root.injectBar(item)
        Qt.callLater(function() { root.injectBar(item) })
      }
    }
  }
}
