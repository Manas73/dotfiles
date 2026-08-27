import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import "PickerModel.js" as Model
import "menus"

Item {
  id: root

  property var shell: null
  property bool opened: false
  property string menuId: ""
  property string query: ""
  property int selectedIndex: 0
  property bool passwordMode: false
  property string passwordSsid: ""
  property var overlayScreen: null

  readonly property var activeMenu: {
    if (menuId === "audio") return audioMenu
    if (menuId === "microphone") return microphoneMenu
    if (menuId === "bluetooth") return bluetoothMenu
    if (menuId === "vpn") return vpnMenu
    if (menuId === "wifi") return wifiMenu
    return null
  }
  readonly property var sourceItems: activeMenu ? activeMenu.items : []
  readonly property var filteredItems: passwordMode ? [] : Model.filterItems(sourceItems, query)
  readonly property string prompt: passwordMode
    ? (passwordSsid || "Password")
    : (activeMenu ? activeMenu.prompt : "")
  readonly property int initialIndex: activeMenu ? activeMenu.initialIndex : 0
  readonly property color foreground: Color.popups.text
  readonly property color hoverFill: Style.hoverFillFor(Color.popups.text, Color.accent)
  readonly property color selectedFill: Style.selectedFillFor(Color.popups.text, Color.accent)

  AudioMenu { id: audioMenu; active: root.opened && root.menuId === "audio" }
  MicrophoneMenu { id: microphoneMenu; active: root.opened && root.menuId === "microphone" }
  BluetoothMenu { id: bluetoothMenu; active: root.opened && root.menuId === "bluetooth" }
  VpnMenu { id: vpnMenu; active: root.opened && root.menuId === "vpn" }
  WifiMenu { id: wifiMenu; active: root.opened && root.menuId === "wifi" }

  function resolveScreen() {
    var focused = Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""
    var screens = Quickshell.screens
    if (!screens || screens.length === 0) return null
    for (var i = 0; i < screens.length; i++) {
      var s = screens[i]
      var mon = Hyprland.monitorFor(s)
      if (mon && String(mon.name || "") === focused) return s
      if (String(s.name || "") === focused) return s
    }
    return screens[0]
  }

  function openMenu(id) {
    var key = String(id || "").trim()
    if (!key) return
    overlayScreen = resolveScreen()
    menuId = key
    query = ""
    passwordMode = false
    passwordSsid = ""
    selectedIndex = initialIndex
    opened = true
    Qt.callLater(function() {
      if (!root.opened) return
      root.resetSelection()
      if (passwordField) passwordField.text = ""
      if (searchField) {
        searchField.text = ""
        searchField.forceActiveFocus()
      }
    })
  }

  function close() {
    opened = false
    passwordMode = false
    passwordSsid = ""
    query = ""
    menuId = ""
  }

  function toggleMenu(id) {
    var key = String(id || "").trim()
    if (opened && menuId === key && !passwordMode) close()
    else openMenu(key)
  }

  function resetSelection() {
    var count = filteredItems.length
    if (query !== "") selectedIndex = count > 0 ? 0 : -1
    else selectedIndex = Model.clampIndex(initialIndex, count, 0)
  }

  function moveSelection(delta) {
    var count = filteredItems.length
    if (count <= 0) { selectedIndex = -1; return }
    if (selectedIndex < 0) selectedIndex = delta > 0 ? 0 : count - 1
    else selectedIndex = (selectedIndex + delta + count) % count
  }

  function activateSelected() {
    if (passwordMode) {
      submitPassword()
      return
    }
    if (selectedIndex < 0 || selectedIndex >= filteredItems.length) return
    activateItem(filteredItems[selectedIndex])
  }

  function activateItem(item) {
    if (!item || !activeMenu || typeof activeMenu.activate !== "function") return
    var result = activeMenu.activate(item)
    if (result === "stay") {
      query = ""
      if (searchField) searchField.text = ""
      Qt.callLater(root.resetSelection)
      return
    }
    if (result === "password") {
      passwordSsid = item.ssid || item.label || ""
      passwordMode = true
      if (passwordField) {
        passwordField.text = ""
        Qt.callLater(function() { if (passwordField) passwordField.forceActiveFocus() })
      }
      return
    }
    close()
  }

  function submitPassword() {
    if (!passwordField) return
    var pw = String(passwordField.text || "")
    if (!pw || !passwordSsid) return
    wifiMenu.connectWithPassword(passwordSsid, pw)
    close()
  }

  function handleEscape() {
    if (passwordMode) {
      passwordMode = false
      passwordSsid = ""
      Qt.callLater(function() { if (searchField) searchField.forceActiveFocus() })
      return
    }
    if (menuId === "wifi" && wifiMenu.back()) {
      query = ""
      if (searchField) searchField.text = ""
      Qt.callLater(root.resetSelection)
      return
    }
    close()
  }

  onFilteredItemsChanged: {
    if (!opened || passwordMode) return
    selectedIndex = Model.clampIndex(selectedIndex, filteredItems.length, query !== "" ? 0 : initialIndex)
  }

  onQueryChanged: if (opened && !passwordMode) resetSelection()

  IpcHandler {
    target: "picker"
    function open(menu: string): void { root.openMenu(menu) }
    function show(menu: string): void { root.openMenu(menu) }
    function toggle(menu: string): void { root.toggleMenu(menu) }
    function close(): void { root.close() }
  }

  PanelWindow {
    visible: root.opened
    screen: root.overlayScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    surfaceFormat.opaque: false
    exclusionMode: ExclusionMode.Ignore
    // Same namespace as widget panels so blur/ignore_alpha apply to the card
    // only — not a full-screen dim.
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    BorderSurface {
      id: card
      width: Math.min(Style.space(460), parent.width - Style.space(48))
      height: Math.min(cardColumn.implicitHeight + Style.spacing.popupPadding * 2, parent.height - Style.space(48))
      anchors.centerIn: parent
      color: Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
      radius: Style.cornerRadius

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: {}
      }

      Column {
        id: cardColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.spacing.popupPadding
        spacing: Style.space(10)

        PanelSectionHeader {
          width: parent.width
          text: root.prompt.toUpperCase()
          foreground: root.foreground
          fontFamily: Style.font.family
        }

        TextField {
          id: searchField
          visible: !root.passwordMode
          width: parent.width
          placeholderText: "Search"
          foreground: root.foreground
          onTextChanged: root.query = text
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Down) { root.moveSelection(1); event.accepted = true }
            else if (event.key === Qt.Key_Up) { root.moveSelection(-1); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.activateSelected(); event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
              root.handleEscape(); event.accepted = true
            } else if (event.key === Qt.Key_Tab) {
              root.moveSelection(event.modifiers & Qt.ShiftModifier ? -1 : 1)
              event.accepted = true
            }
          }
        }

        TextField {
          id: passwordField
          visible: root.passwordMode
          width: parent.width
          placeholderText: "Password"
          password: true
          foreground: root.foreground
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.submitPassword(); event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
              root.handleEscape(); event.accepted = true
            }
          }
        }

        Text {
          visible: !root.passwordMode && root.filteredItems.length === 0
          width: parent.width
          text: root.sourceItems.length === 0 ? "Nothing to list" : "No matches"
          color: Qt.darker(root.foreground, 1.5)
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }

        ListView {
          id: list
          visible: !root.passwordMode && root.filteredItems.length > 0
          width: parent.width
          height: Math.min(contentHeight, Style.space(360))
          clip: true
          spacing: Style.space(2)
          boundsBehavior: Flickable.StopAtBounds
          model: root.filteredItems
          currentIndex: root.selectedIndex
          onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

          delegate: CursorSurface {
            required property var modelData
            required property int index
            width: list.width
            height: implicitHeight
            implicitHeight: rowInner.implicitHeight + Style.spacing.md
            hasCursor: root.selectedIndex === index
            current: !!(modelData && modelData.current)
            foreground: root.foreground
            fill: root.hoverFill
            currentFill: root.selectedFill

            Row {
              id: rowInner
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(8)

              Text {
                text: modelData && modelData.glyph ? modelData.glyph : ""
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                width: Style.space(22)
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: modelData ? modelData.label : ""
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: !!(modelData && modelData.current)
                elide: Text.ElideRight
                width: parent.width - Style.space(22) - detailText.width - Style.space(16)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: detailText
                text: modelData && modelData.detail ? modelData.detail : ""
                color: Qt.darker(root.foreground, 1.5)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                visible: text !== ""
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: if (containsMouse) root.selectedIndex = index
              onClicked: root.activateItem(modelData)
            }
          }
        }
      }
    }
  }
}
