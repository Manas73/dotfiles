import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import qs.components
import "Model.js" as Model

Panel {
  id: root
  moduleName: "microphone"
  ipcTarget: "microphone"

  readonly property var source: Pipewire.defaultAudioSource
  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []

  readonly property var candidateSources: {
    var list = []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (n && !n.isSink && !n.isStream && isAudioSource(n)) {
        var name = n.name || ""
        if (name === "quickshell") continue
        list.push(n)
      }
    }
    return list
  }

  function isAudioSource(node) {
    return Model.isAudioSource(node)
  }

  property var cachedAudioSources: []

  readonly property var rawAudioSources: {
    var list = candidateSources.slice()
    if (source && list.indexOf(source) < 0) list.unshift(source)
    return list
  }

  readonly property var audioSources: rawAudioSources.length > 0 ? rawAudioSources : cachedAudioSources

  // Feed Repeaters with panel-local snapshots instead of the live PipeWire
  // model. PipeWire can remove nodes while Quickshell is dispatching the
  // removal signal; rebuilding a Repeater from that signal path has crashed
  // in Quickshell's PipeWire service. The snapshot timer lets that mutation
  // settle first, and closed panels keep their repeaters detached entirely.
  property var displayAudioSources: []

  // Carry sub-notch touchpad deltas between wheel events.
  property real wheelAccumulator: 0

  readonly property real inputVolume: source && source.audio ? source.audio.volume : 0
  readonly property bool inputMuted: source && source.audio ? source.audio.muted : false
  readonly property int inputPercent: Math.round(Math.max(0, inputVolume) * 100)
  readonly property bool showVolumePercent: !button.vertical && !inputMuted
  readonly property real openPanelIndicatorWidth: showVolumePercent ? button.labelWidth : 0

  onRawAudioSourcesChanged: if (rawAudioSources.length > 0) cachedAudioSources = rawAudioSources

  // Single cursor model shared by keyboard and mouse.
  // selectedIndex: -1 on the slider row; 0..N-1 on a source device.
  property int selectedIndex: -1
  property bool cursorActive: false

  readonly property bool hasInput: !!(source && source.audio)
  readonly property string inputMuteHint: inputMuted ? "Unmute microphone" : "Mute microphone"

  readonly property color hoverFill: bar
    ? Style.hoverFillFor(bar.foreground, Color.accent)
    : "transparent"
  readonly property color selectedFill: bar
    ? Style.selectedFillFor(bar.foreground, Color.accent)
    : "transparent"

  function moveCursor(delta) {
    var max = displayAudioSources.length - 1
    var floor = -1
    var next = selectedIndex + delta
    if (next > max) next = max
    if (next < floor) next = floor
    selectedIndex = next
  }

  function adjustVolume(delta) {
    if (selectedIndex === -1) setInputVolume(inputVolume + delta)
  }

  function activateCursor() {
    if (selectedIndex === -1) {
      toggleInputMute()
      return
    }
    var src = displayAudioSources[selectedIndex]
    if (src) setDefaultSource(src)
  }

  onOpenedChanged: {
    if (opened) {
      refreshDisplayAudioModels()
      selectedIndex = -1
      cursorActive = false
      Qt.callLater(resetScroll)
    } else {
      clearDisplayAudioModels()
    }
  }

  onAudioSourcesChanged: scheduleDisplayAudioModelRefresh()

  function listSnapshot(list) {
    return Model.listSnapshot(list)
  }

  function refreshDisplayAudioModels() {
    if (!opened) return
    displayAudioSources = listSnapshot(audioSources)
    clampCursor()
  }

  function scheduleDisplayAudioModelRefresh() {
    if (!opened) return
    audioModelRefreshTimer.restart()
  }

  function clearDisplayAudioModels() {
    audioModelRefreshTimer.stop()
    displayAudioSources = []
  }

  function resetScroll() {
    if (!scrollArea) return
    var flick = scrollArea.contentItem
    if (flick && flick.contentY !== undefined) flick.contentY = 0
  }

  function ensureCursorVisible(item) {
    if (!item || !scrollArea) return
    var flick = scrollArea.contentItem
    if (!flick || flick.contentY === undefined) return
    var margin = 6
    var maxY = Math.max(0, (flick.contentHeight || 0) - flick.height)
    if (maxY <= Style.space(24) || root.selectedIndex === -1) {
      flick.contentY = 0
      return
    }
    var pt = item.mapToItem(flick.contentItem || flick, 0, 0)
    var top = pt.y
    var bottom = top + (item.height || 0)
    var viewTop = flick.contentY
    var viewBottom = viewTop + flick.height
    if (top < viewTop + margin) flick.contentY = Math.max(0, Math.min(maxY, top - margin))
    else if (bottom > viewBottom - margin)
      flick.contentY = Math.max(0, Math.min(maxY, bottom + margin - flick.height))
  }

  function clampCursor() {
    var count = displayAudioSources.length
    var floor = -1
    if (selectedIndex > count - 1) selectedIndex = Math.max(floor, count - 1)
    if (selectedIndex < floor) selectedIndex = floor
  }

  function inputIcon() {
    if (!source || !source.audio) return "󰍭"
    return inputMuted ? "󰍭" : "󰍬"
  }

  function inputVolumeName(volume, muted) {
    return Model.inputVolumeName(volume, muted)
  }

  function setInputVolume(v) {
    if (!source || !source.audio) return inputVolume
    var volume = Math.max(0, Math.min(1, v))
    source.audio.volume = volume
    return volume
  }

  function showVolumeOsd(volume) {
    if (!bar || !bar.shell) return
    bar.shell.summon("osd", JSON.stringify({
      icon: inputIcon(),
      value: Math.round(volume * 100)
    }))
  }

  function toggleInputMute() {
    if (source && source.audio) source.audio.muted = !source.audio.muted
  }

  function setDefaultSource(node) {
    if (!node) return
    Pipewire.preferredDefaultAudioSource = node
    if (node.id !== undefined && node.name) {
      Quickshell.execDetached([Quickshell.shellDir + "/bin/omarchy-audio-input-set-default",
        String(node.id),
        String(node.name)
      ])
    }
  }

  function nodeLabel(node) {
    return Model.nodeLabel(node)
  }

  function sourceGlyph(node) {
    return Model.sourceGlyph(node)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  PwObjectTracker { objects: root.candidateSources }

  PwNodePeakMonitor {
    id: inputPeakMonitor
    node: root.source
    enabled: root.opened && !!root.source
  }

  Timer {
    id: audioModelRefreshTimer
    interval: 75
    repeat: false
    onTriggered: root.refreshDisplayAudioModels()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.showVolumePercent
      ? root.inputIcon() + " " + root.inputPercent + "%"
      : root.inputIcon()
    fontSize: Style.font.bodySmall
    active: root.inputMuted
    horizontalMargin: 8.5
    onPressed: function(b) {
      if (b === Qt.RightButton) root.toggleInputMute()
      else root.toggle()
    }

    onWheelMoved: function(delta) {
      if (!root.hasInput) return
      var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
      root.wheelAccumulator = wheel.remainder
      if (wheel.steps === 0) return
      var volume = root.setInputVolume(root.inputVolume + wheel.steps * 0.02)
      root.showVolumeOsd(volume)
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
        else if (dx !== 0) root.adjustVolume(dx * 0.05)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "m" || t === "M") {
          if (root.cursorActive) root.toggleInputMute()
        }
      }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        Binding {
          target: scrollArea.contentItem
          property: "interactive"
          value: panelColumn.implicitHeight > scrollArea.height
        }

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          Item {
            id: heroItem
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

            Text {
              id: heroIcon
              text: root.inputIcon()
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.display
              opacity: root.inputMuted ? 0.5 : 1.0
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: "Microphone"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                id: heroLabel
                text: root.inputVolumeName(
                  inputSlider.dragging ? inputSlider.liveValue : root.inputVolume,
                  root.inputMuted
                ).toUpperCase()
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                elide: Text.ElideRight
                width: parent.width
              }
            }
          }

          PanelSeparator {
            foreground: root.bar.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              implicitHeight: Math.max(microphoneHeader.implicitHeight, inputMuteSwitch.implicitHeight)

              PanelSectionHeader {
                id: microphoneHeader
                text: "INPUT"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              ChannelMuteSwitch {
                id: inputMuteSwitch
                visible: root.hasInput
                muted: root.inputMuted
                hint: root.inputMuteHint
                anchors.right: parent.right
                anchors.verticalCenter: microphoneHeader.verticalCenter
                anchors.verticalCenterOffset: Math.round(microphoneHeader.topPadding / 2)
                onToggled: root.toggleInputMute()
                onHovered: function(on) {
                  if (!on) return
                  root.cursorActive = true
                  root.selectedIndex = -1
                }
              }

              Text {
                id: microphonePercent
                text: Math.round((inputSlider.dragging ? inputSlider.liveValue : root.inputVolume) * 100) + "%"
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: inputMuteSwitch.visible ? inputMuteSwitch.left : parent.right
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                opacity: root.inputMuted ? 0.5 : 1.0
              }
            }

            CursorSurface {
              id: inputSliderRow
              visible: !!root.source
              width: parent.width
              height: inputControls.implicitHeight + Style.spacing.controlGap
              hasCursor: root.cursorActive && root.selectedIndex === -1
              onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(inputSliderRow)
              foreground: root.bar.foreground
              outline: true

              Column {
                id: inputControls
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                spacing: Style.space(5)

                PanelSlider {
                  id: inputSlider
                  bar: root.bar
                  width: parent.width
                  minimum: 0
                  maximum: 1
                  step: 0.05
                  value: root.inputVolume
                  opacity: root.inputMuted ? 0.5 : 1.0
                  enabled: !!root.source

                  onMoved: function(v) { root.setInputVolume(v) }
                  onRightClicked: root.toggleInputMute()
                }

                Rectangle {
                  width: parent.width
                  height: Math.max(Style.space(5), Style.spacing.xs)
                  color: Util.alpha(root.bar.foreground, 0.18)
                  opacity: root.inputMuted ? 0.35 : 1.0

                  Rectangle {
                    height: parent.height
                    width: parent.width * Math.max(0, Math.min(1, inputPeakMonitor.peak))
                    color: root.bar.foreground
                    Behavior on width { NumberAnimation { duration: 70 } }
                  }
                }
              }

              HoverHandler {
                onHoveredChanged: if (hovered) {
                  root.cursorActive = true
                  root.selectedIndex = -1
                }
              }
            }

            Repeater {
              model: root.displayAudioSources

              SourceRow {
                required property var modelData
                required property int index
                width: panelColumn.width
                node: modelData
                rowIndex: index
              }
            }
          }
        }
      }
    }
  }

  component ChannelMuteSwitch: ToggleSwitch {
    property bool muted: false
    property string hint: ""

    checked: !muted
    trackHeight: Math.round(Style.font.caption * 1.2)
    cursorPad: Style.space(3)
    foreground: root.bar.foreground

    PanelToolTip {
      visible: parent.containsMouse
      text: hint
      fontFamily: root.bar.fontFamily
    }
  }

  component SourceRow: CursorSurface {
    id: sourceRow
    required property var node
    required property int rowIndex

    readonly property bool isActive: root.source && node && root.source.id === node.id
    hasCursor: root.cursorActive && root.selectedIndex === rowIndex
    onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(sourceRow)
    current: isActive
    foreground: root.bar.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: sourceInner.implicitHeight + Style.spacing.xl

    Row {
      id: sourceInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        text: root.sourceGlyph(sourceRow.node)
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.title
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: root.nodeLabel(sourceRow.node)
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        font.bold: sourceRow.isActive
        elide: Text.ElideRight
        width: parent.width - Style.space(22) - Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.selectedIndex = sourceRow.rowIndex
      }
      onClicked: root.setDefaultSource(sourceRow.node)
    }
  }
}
