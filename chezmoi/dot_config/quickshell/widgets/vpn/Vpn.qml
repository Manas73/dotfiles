import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.components
import "Model.js" as Model

Panel {
  id: root
  moduleName: "vpn"
  ipcTarget: "vpn"
  manageIpc: false

  property var connections: []
  property var pendingDownUuids: []
  property string pendingUuid: ""
  property string pendingKind: ""  // "up" | "down" | "down-all"
  property int desiredActive: -1   // -1 follow live; 0/1 optimistic
  property string lastError: ""
  property string actionStatus: ""
  property int phraseIndex: 0
  property string focusSection: "header"
  property int selectedIndex: 0
  property bool cursorActive: false

  readonly property var activeVpns: Model.activeConnections(connections)
  readonly property bool liveAnyActive: activeVpns.length > 0
  readonly property bool anyActive: desiredActive === -1 ? liveAnyActive : desiredActive === 1
  readonly property bool busy: pendingKind !== "" || actionProc.running
  readonly property var recentVpn: Model.mostRecent(connections)
  readonly property string connectedLabel: Model.connectedSummary(activeVpns)
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color hoverFill: bar ? Style.hoverFillFor(bar.foreground, Color.accent) : "transparent"
  readonly property color selectedFill: bar ? Style.selectedFillFor(bar.foreground, Color.accent) : "transparent"
  readonly property bool headerHasCursor: cursorActive && focusSection === "header"
  readonly property string toggleHint: anyActive ? "Disconnect VPN" : (recentVpn ? "Connect " + recentVpn.name : "No VPN connections")
  readonly property var activePhrases: [
    "Sealing tunnels",
    "Hiding routes",
    "Guarding wires",
    "Braiding packets",
    "Locking doors",
    "Masking hops"
  ]
  readonly property string heroStatusText: {
    if (actionStatus !== "") return actionStatus
    if (pendingKind === "up") return "Connecting…"
    if (pendingKind === "down" || pendingKind === "down-all") return "Disconnecting…"
    if (anyActive) return activePhrases[phraseIndex % activePhrases.length]
    return "Disconnected"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!listProc.running) listProc.running = true
  }

  function applyList(raw) {
    connections = Model.parseList(raw)
    clampCursor()
  }

  function runAction(kind, uuid) {
    if (actionProc.running || !kind) return
    pendingKind = kind
    pendingUuid = uuid || ""
    lastError = ""
    if (kind === "up") {
      desiredActive = 1
      actionStatus = "Connecting…"
      actionProc.command = [Quickshell.shellDir + "/bin/omarchy-vpn", "up", uuid]
    } else {
      desiredActive = 0
      actionStatus = "Disconnecting…"
      actionProc.command = [Quickshell.shellDir + "/bin/omarchy-vpn", "down", uuid]
    }
    actionProc.running = true
  }

  function connectUuid(uuid) {
    var conn = Model.connectionByUuid(connections, uuid)
    if (!conn || conn.active || busy) return
    runAction("up", uuid)
  }

  function disconnectUuid(uuid) {
    var conn = Model.connectionByUuid(connections, uuid)
    if (!conn || !conn.active || busy) return
    runAction("down", uuid)
  }

  function toggleConnection(conn) {
    if (!conn || busy) return
    if (conn.active) disconnectUuid(conn.uuid)
    else connectUuid(conn.uuid)
  }

  function disconnectAll() {
    if (busy || activeVpns.length === 0) return
    var uuids = []
    for (var i = 0; i < activeVpns.length; i++) uuids.push(activeVpns[i].uuid)
    pendingDownUuids = uuids
    pendingKind = "down-all"
    desiredActive = 0
    lastError = ""
    actionStatus = "Disconnecting…"
    disconnectNextQueued()
  }

  function disconnectNextQueued() {
    if (!pendingDownUuids || pendingDownUuids.length === 0) {
      pendingKind = ""
      pendingUuid = ""
      pendingDownUuids = []
      desiredActive = -1
      actionStatus = ""
      refresh()
      return
    }
    var uuid = pendingDownUuids[0]
    var rest = []
    for (var i = 1; i < pendingDownUuids.length; i++) rest.push(pendingDownUuids[i])
    pendingDownUuids = rest
    pendingUuid = uuid
    actionProc.command = [Quickshell.shellDir + "/bin/omarchy-vpn", "down", uuid]
    actionProc.running = true
  }

  function toggleVpn() {
    if (busy) return
    if (anyActive) disconnectAll()
    else if (recentVpn) connectUuid(recentVpn.uuid)
  }

  function setHeaderCursor() {
    cursorActive = true
    focusSection = "header"
  }

  function clampCursor() {
    if (connections.length === 0) {
      focusSection = "header"
      selectedIndex = 0
      return
    }
    if (focusSection === "connections")
      selectedIndex = Math.max(0, Math.min(connections.length - 1, selectedIndex))
  }

  function moveCursor(dx, dy) {
    if (dy === 0) return
    var sections = ["header"]
    if (connections.length > 0) sections.push("connections")
    var sIdx = sections.indexOf(focusSection)
    if (sIdx < 0) sIdx = 0

    if (focusSection === "connections") {
      var next = selectedIndex + dy
      if (next >= 0 && next < connections.length) {
        selectedIndex = next
        return
      }
      if (next < 0) {
        focusSection = "header"
        return
      }
      return
    }

    if (dy > 0 && connections.length > 0) {
      focusSection = "connections"
      selectedIndex = 0
    }
  }

  function activateCursor() {
    if (focusSection === "header") {
      toggleVpn()
      return
    }
    if (focusSection === "connections" && selectedIndex >= 0 && selectedIndex < connections.length)
      toggleConnection(connections[selectedIndex])
  }

  function ensureCursorVisible(item) {
    if (!item || !scrollArea) return
    var flick = scrollArea.contentItem
    if (!flick || flick.contentY === undefined) return
    var margin = 6
    var maxY = Math.max(0, (flick.contentHeight || 0) - flick.height)
    if (maxY <= Style.space(24) || focusSection === "header") {
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

  onOpenedChanged: {
    if (opened) {
      refresh()
      focusSection = "header"
      selectedIndex = 0
      cursorActive = false
    }
  }

  Component.onCompleted: refresh()

  IpcHandler {
    enabled: root.ipcOwner
    target: "vpn"

    function open() { root.invokeFocused("open") }
    function close() { root.invokeFocused("close") }
    function show() { root.invokeFocused("open") }
    function hide() { root.invokeFocused("close") }
    function toggle() { root.invokeFocused("toggle") }
    function toggleVpn() { root.toggleVpn() }
    function refresh(): string { root.refresh(); return "ok" }
  }

  Process {
    id: listProc
    command: [Quickshell.shellDir + "/bin/omarchy-vpn", "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyList(text)
    }
  }

  Process {
    id: actionProc
    command: []
    stdout: StdioCollector { id: actionStdout; waitForEnd: true }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var stderr = String(actionStderr.text || "")
      var stdout = String(actionStdout.text || "")
      if (exitCode !== 0) {
        root.desiredActive = -1
        root.pendingKind = ""
        root.pendingUuid = ""
        root.pendingDownUuids = []
        root.lastError = Model.elideStatus(stderr || stdout || "VPN command failed")
        root.actionStatus = ""
        root.refresh()
        return
      }
      root.lastError = ""
      if (root.pendingKind === "down-all") {
        root.disconnectNextQueued()
        return
      }
      root.pendingKind = ""
      root.pendingUuid = ""
      root.desiredActive = -1
      root.actionStatus = ""
      root.refresh()
    }
  }

  Timer {
    interval: root.opened || root.busy ? 1500 : 4000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!root.busy) root.refresh()
  }

  Timer {
    interval: 4000
    running: root.opened && root.anyActive && root.pendingKind === ""
    repeat: true
    onTriggered: root.phraseIndex = (root.phraseIndex + 1) % Math.max(1, root.activePhrases.length)
  }

  Timer {
    id: errorClear
    interval: 8000
    onTriggered: if (root.actionStatus === "") root.lastError = ""
  }

  onLastErrorChanged: if (lastError !== "") errorClear.restart()

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.barGlyph(root.activeVpns)
    foreground: root.anyActive ? root.foreground : root.dim
    tooltipText: root.anyActive ? (root.connectedLabel || "VPN connected") : "VPN"

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.toggleVpn()
      else if (buttonCode === Qt.MiddleButton) root.refresh()
      else root.toggle()
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
        if (dy !== 0) root.moveCursor(dx, dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "t" || t === "T") root.toggleVpn()
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
            id: header
            width: parent.width
            implicitHeight: hero.implicitHeight
            readonly property bool ringVisible: root.headerHasCursor
            function focusHero() { root.setHeaderCursor() }

            PanelHero {
              id: hero
              width: parent.width
              title: "VPN"
              meta: root.heroStatusText
              detail: root.anyActive ? root.connectedLabel : ""
              foreground: root.foreground
              fontFamily: root.fontFamily
              iconOpacity: root.anyActive ? 1.0 : 0.5
              iconComponent: Component {
                Text {
                  text: Model.barGlyph(root.activeVpns)
                  color: root.anyActive ? root.foreground : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                }
              }

              trailingControl: Component {
                ToggleSwitch {
                  id: powerSwitch
                  visible: root.connections.length > 0 || root.anyActive
                  checked: root.anyActive
                  busy: root.busy
                  hasCursor: header.ringVisible
                  foreground: hero.foreground
                  onHovered: function(on) { if (on) header.focusHero() }
                  onToggled: root.toggleVpn()

                  PanelToolTip {
                    visible: powerSwitch.containsMouse
                    text: root.toggleHint
                    fontFamily: hero.fontFamily
                  }
                }
              }
            }
          }

          Text {
            visible: root.lastError !== ""
            width: parent.width
            text: root.lastError
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          PanelSeparator {
            foreground: root.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              text: "CONNECTIONS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              visible: root.connections.length === 0
              width: parent.width
              text: "No VPN or WireGuard connections in NetworkManager."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Repeater {
              model: root.connections

              ConnectionRow {
                required property var modelData
                required property int index
                width: panelColumn.width
                conn: modelData
                rowIndex: index
              }
            }
          }
        }
      }
    }
  }

  component ConnectionRow: CursorSurface {
    id: row
    required property var conn
    required property int rowIndex

    readonly property bool isActive: {
      if (!conn) return false
      if (conn.active) return true
      return root.pendingKind === "up" && root.pendingUuid === conn.uuid
    }
    readonly property bool rowBusy: root.pendingUuid === (conn ? conn.uuid : "") && root.busy
    readonly property string statusText: {
      if (!conn) return ""
      if (root.pendingUuid === conn.uuid && root.pendingKind === "up") return "Connecting…"
      if (root.pendingUuid === conn.uuid && (root.pendingKind === "down" || root.pendingKind === "down-all"))
        return "Disconnecting…"
      if (isActive) return "Connected"
      return Model.typeLabel(Model.kindOf(conn))
    }

    hasCursor: root.cursorActive && root.focusSection === "connections" && root.selectedIndex === rowIndex
    onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(row)
    current: isActive
    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: rowInner.implicitHeight + Style.spacing.xl
    opacity: root.busy && !rowBusy ? 0.55 : 1.0

    Row {
      id: rowInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        text: Model.glyph(Model.kindOf(row.conn))
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
        opacity: row.isActive ? 1.0 : 0.7
      }

      Column {
        width: parent.width - Style.space(22) - Style.space(8)
        spacing: Style.space(1)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          text: row.conn ? row.conn.name : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: row.isActive
          elide: Text.ElideRight
          width: parent.width
        }

        Text {
          text: row.statusText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          width: parent.width
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: root.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.focusSection = "connections"
        root.selectedIndex = row.rowIndex
      }
      onClicked: if (!root.busy) root.toggleConnection(row.conn)
    }
  }
}
