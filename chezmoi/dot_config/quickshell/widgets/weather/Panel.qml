import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import "Model.js" as Model

Panel {
  id: root
  moduleName: "weather"
  ipcTarget: "weather"
  manageIpc: false

  property var anchorItem: null

  // The bar tracks the widget mounted in its slot — BarWidget.qml — not this
  // nested panel. Everything the bar identifies a panel by has to be that
  // widget: the popout coordinator (and with it the open-panel dot under the
  // pill) compares against `slot.activeItem`, and switchPanelFrom looks the
  // slot up the same way. `hostWidget` is declared on qs.Ui.Panel.
  readonly property var barIdentity: hostWidget || root

  function open() {
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
    locationFile.reload()
    root.refresh()
  }

  function openFromHotkey() {
    root.controller.show()
    locationFile.reload()
    root.refresh()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.cancelRename()
    if (root.editingLocation) root.cancelEditingLocation()
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  property var places: Model.parseLocationFile("").places
  property string activePlaceId: "home"
  property bool placesHydrating: false
  property bool addingPlace: false
  property string renamingPlaceId: ""
  readonly property bool renamingPlace: renamingPlaceId !== ""
  readonly property string settingsDir: Quickshell.env("HOME") + "/.local/state/quickshell/settings"
  readonly property var homePlace: places.length ? places[0] : null
  readonly property string homeLocationQuery: Model.linecastLocationArg(homePlace)
  readonly property var activePlace: Model.findPlace(places, activePlaceId) || homePlace
  readonly property string activeLocationQuery: Model.linecastLocationArg(activePlace)
  readonly property string unitOverride: Model.normalizedUnit(setting("unit", ""))
  readonly property var jsonCommand: Model.linecastCommand(Util.bin("omarchy-linecast"), "weather", {
    json: true,
    icons: "nerd",
    location: root.homeLocationQuery,
    units: root.unitOverride
  })

  onHomeLocationQueryChanged: {
    jsonRetries = 0
    jsonProc.running = false
    Qt.callLater(refresh)
  }

  property FileView locationFile: FileView {
    path: root.settingsDir + "/weather.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyLocationFile(text())
    onLoadFailed: root.applyLocationFile("")
  }

  Process {
    id: ensureSettingsDir
    command: ["mkdir", "-p", root.settingsDir]
  }

  Timer {
    interval: 1500
    running: true
    onTriggered: locationFile.reload()
  }

  property int jsonRetries: 0
  property bool editingLocation: false
  property bool savingLocation: false
  property var locationSuggestions: []
  property int suggestionIndex: 0
  property string geocodePendingQuery: ""
  property string geocodeActiveQuery: ""
  property string label: ""
  property string reportLocation: ""

  readonly property int refreshMinutes: Math.max(1, parseInt(setting("refreshMinutes", 15), 10) || 15)
  readonly property int termFontSize: Style.font.bodySmall
  readonly property int cellW: Math.max(7, Math.round(termMetrics.averageCharacterWidth))
  readonly property int cellH: Math.max(termFontSize + 2, Math.round(termMetrics.height))
  readonly property int leftCols: 58
  readonly property int rightCols: 62
  readonly property int viewRows: 28
  readonly property int sectionPad: Style.space(10)
  readonly property int sectionGap: Style.spacing.panelGap
  readonly property int sectionHeaderH: Style.font.caption + Style.space(10)
  readonly property int sectionChrome: sectionHeaderH + sectionPad * 2 + Math.max(1, Style.spacing.hairline) * 2
  readonly property int viewsHeight: viewRows * cellH + sectionChrome

  FontMetrics {
    id: termMetrics
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: root.termFontSize
  }

  function refresh() {
    jsonRetries = 0
    jsonProc.command = root.jsonCommand
    if (!jsonProc.running) jsonProc.running = true
    if (root.opened && placeFrame) placeFrame.refresh()
  }

  function applyLocationFile(raw) {
    var parsed = Model.parseLocationFile(raw)
    root.placesHydrating = true
    root.places = parsed.places
    root.activePlaceId = parsed.activePlaceId
    root.placesHydrating = false
  }

  function persistPlaces() {
    if (root.placesHydrating) return
    if (ensureSettingsDir.running !== true) ensureSettingsDir.running = true
    locationFile.setText(Model.serializeLocationFile({
      places: root.places,
      activePlaceId: root.activePlaceId
    }) + "\n")
    if (root.savingLocation) root.cancelEditingLocation()
  }

  function selectPlace(id) {
    if (!id || id === root.activePlaceId) {
      root.cancelRename()
      return
    }
    root.cancelRename()
    root.activePlaceId = id
    root.persistPlaces()
  }

  function cyclePlace(delta) {
    root.selectPlace(Model.neighborPlaceId(root.places, root.activePlaceId, delta))
  }

  function startAddingPlace() {
    root.renamingPlaceId = ""
    addingPlace = true
    startEditingLocation()
    Qt.callLater(function() { locationField.text = "" })
  }

  function startRenamingPlace(id) {
    if (!id) return
    root.cancelEditingLocation()
    if (id !== root.activePlaceId) {
      root.activePlaceId = id
      root.persistPlaces()
    }
    root.renamingPlaceId = id
  }

  function commitRename(name) {
    var current = Model.findPlace(root.places, root.renamingPlaceId)
    root.renamingPlaceId = ""
    if (!current) return
    var nextName = String(name || "").replace(/^\s+|\s+$/g, "")
    if (nextName === "" || nextName === current.name) return
    root.places = Model.replacePlace(root.places, {
      id: current.id,
      name: nextName,
      latitude: current.latitude,
      longitude: current.longitude
    })
    root.persistPlaces()
  }

  function cancelRename() {
    root.renamingPlaceId = ""
  }

  function removePlace(id) {
    if ((root.places || []).length <= 1) return
    var nextId = root.activePlaceId === id
      ? Model.neighborPlaceId(root.places, id, -1)
      : root.activePlaceId
    var nextPlaces = Model.removePlace(root.places, id)
    if (!Model.findPlace(nextPlaces, nextId) || nextId === id)
      nextId = nextPlaces[0].id
    root.places = nextPlaces
    root.activePlaceId = nextId
    root.persistPlaces()
  }

  function startEditingLocation() {
    root.cancelRename()
    editingLocation = true
    savingLocation = false
    locationSuggestions = []
    suggestionIndex = 0
    Qt.callLater(function() {
      locationField.text = root.addingPlace ? "" : Model.placeLabel(root.activePlace)
      if (locationField.text === "Auto") locationField.text = ""
      locationField.selectAll()
      locationField.forceActiveFocus()
    })
  }

  function cancelEditingLocation() {
    editingLocation = false
    addingPlace = false
    savingLocation = false
    locationSuggestions = []
    geocodeDebounce.stop()
    Qt.callLater(function() { if (keyCatcher && !root.renamingPlace) keyCatcher.forceActiveFocus() })
  }

  function applyPlaceLocation(location) {
    savingLocation = true
    if (root.addingPlace) {
      var created = {
        id: Model.newPlaceId(),
        name: location.name,
        latitude: location.latitude,
        longitude: location.longitude
      }
      root.places = root.places.concat([created])
      root.activePlaceId = created.id
      root.addingPlace = false
    } else {
      var current = root.activePlace
      root.places = Model.replacePlace(root.places, {
        id: current.id,
        name: location.name,
        latitude: location.latitude,
        longitude: location.longitude
      })
    }
    root.persistPlaces()
  }

  function commitLocation() {
    var location = Model.locationCommit(locationField.text, locationSuggestions, suggestionIndex)
    if (location.name === "") {
      if (root.addingPlace) root.cancelEditingLocation()
      else root.clearLocation()
      return
    }
    root.applyPlaceLocation(location)
  }

  function clearLocation() {
    if (root.addingPlace) {
      root.cancelEditingLocation()
      return
    }
    var clearingHome = root.homePlace && root.activePlace && root.activePlace.id === root.homePlace.id
    root.applyPlaceLocation({ name: "", latitude: null, longitude: null })
    if (clearingHome) reportLocation = ""
  }

  function pickSuggestion(suggestion) {
    if (!suggestion) return
    root.applyPlaceLocation(suggestion)
  }

  function requestGeocode() {
    var query = locationField.text.trim()
    if (query.length < 2) {
      locationSuggestions = []
      return
    }
    geocodePendingQuery = query
    if (!geocodeProc.running) startGeocode()
  }

  function startGeocode() {
    geocodeActiveQuery = geocodePendingQuery
    geocodeProc.command = ["curl", "-fsS", "--max-time", "5",
      "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(geocodeActiveQuery) + "&count=5&language=en&format=json"]
    geocodeProc.running = true
  }

  Process {
    id: jsonProc
    environment: ({
      "LINECAST_ICONS": "nerd",
      "LINECAST_COLOR": "truecolor"
    })
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseWeatherJson(text)
        if (!parsed || parsed.icon === "") {
          root.scheduleJsonRetry()
          return
        }
        root.label = parsed.icon
        if (parsed.location !== "") root.reportLocation = parsed.location
        root.jsonRetries = 0
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.label === "") root.scheduleJsonRetry()
    }
  }

  function scheduleJsonRetry() {
    if (jsonRetries >= 3) return
    jsonRetries++
    jsonRetryTimer.restart()
  }

  Timer {
    id: jsonRetryTimer
    interval: 2500
    onTriggered: {
      if (jsonProc.running) return
      jsonProc.command = root.jsonCommand
      jsonProc.running = true
    }
  }

  Process {
    id: geocodeProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.locationSuggestions = root.editingLocation ? Model.parseGeocodingResults(text) : []
        root.suggestionIndex = 0
        if (root.geocodePendingQuery !== root.geocodeActiveQuery) Qt.callLater(root.startGeocode)
      }
    }
  }

  Timer {
    id: geocodeDebounce
    interval: 300
    onTriggered: root.requestGeocode()
  }

  Timer {
    id: refreshTimer
    interval: root.refreshMinutes * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  IpcHandler {
    enabled: root.ipcOwner
    target: root.ipcTarget

    function open(): void { root.invokeFocused("openFromHotkey") }
    function close(): void { root.invokeFocused("close") }
    function show(): void { root.invokeFocused("openFromHotkey") }
    function hide(): void { root.invokeFocused("close") }
    function toggle(): void { root.invokeFocused("toggle") }
    function edit(): void { root.openFromHotkey(); root.startEditingLocation() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth((root.leftCols + root.rightCols) * root.cellW + root.sectionPad * 4 + root.sectionGap + Style.space(8))
    contentHeight: panel.fittedContentHeight(headerColumn.height + Style.space(12) + root.viewsHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editingLocation || root.renamingPlace
      onReturnRequested: root.startEditingLocation()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) { if (dx !== 0) root.cyclePlace(dx) }

      Column {
        id: headerColumn
        width: parent.width
        spacing: Style.space(8)

        Row {
          id: tabStrip
          width: parent.width
          spacing: Style.space(6)

          Flickable {
            id: tabFlick
            width: parent.width - addPlaceButton.implicitWidth - parent.spacing
            height: Math.max(Style.spacing.controlHeight, tabRow.height)
            contentWidth: tabRow.width
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick
            interactive: contentWidth > width

            Row {
              id: tabRow
              spacing: Style.space(6)

              Repeater {
                model: root.places

                PlaceTab {
                  required property var modelData
                  title: Model.placeLabel(modelData)
                  selected: modelData.id === root.activePlaceId
                  removable: root.places.length > 1
                  renaming: modelData.id === root.renamingPlaceId
                  foreground: root.bar.foreground
                  accent: Color.accent
                  fontFamily: root.bar.fontFamily
                  onActivated: root.selectPlace(modelData.id)
                  onRemoved: root.removePlace(modelData.id)
                  onRenameRequested: root.startRenamingPlace(modelData.id)
                  onRenameCommitted: function(name) { root.commitRename(name) }
                  onRenameCanceled: root.cancelRename()
                }
              }
            }
          }

          Button {
            id: addPlaceButton
            text: "+"
            bordered: true
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            fontSize: Style.font.body
            horizontalPadding: Style.space(10)
            tooltipText: "Add a place"
            onClicked: root.startAddingPlace()
          }
        }

        Row {
          id: locationEditRow
          visible: root.editingLocation
          spacing: Style.space(6)
          width: parent.width

          TextField {
            id: locationField
            width: Style.space(250)
            enabled: !root.savingLocation
            placeholderText: root.addingPlace ? "Add a city" : "Search city"
            foreground: root.bar.foreground
            font.family: root.bar.fontFamily

            onTextChanged: if (root.editingLocation && !root.savingLocation) geocodeDebounce.restart()

            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                root.cancelEditingLocation()
                event.accepted = true
              } else if (event.key === Qt.Key_Down) {
                if (root.suggestionIndex < root.locationSuggestions.length - 1) root.suggestionIndex++
                event.accepted = true
              } else if (event.key === Qt.Key_Up) {
                if (root.suggestionIndex > 0) root.suggestionIndex--
                event.accepted = true
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.commitLocation()
                event.accepted = true
              }
            }
          }

          Rectangle {
            width: Style.space(18)
            height: Style.space(18)
            anchors.verticalCenter: parent.verticalCenter
            radius: Math.min(4, Style.cornerRadius)
            color: !root.savingLocation && clearLocationArea.containsMouse ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent"

            Text {
              anchors.centerIn: parent
              text: root.savingLocation ? "󰦖" : "✕"
              font.family: root.bar.fontFamily
              color: Qt.darker(root.bar.foreground, 1.4)
              font.pixelSize: Style.font.bodySmall

              RotationAnimator on rotation {
                running: root.savingLocation
                from: 0; to: 360
                duration: 800
                loops: Animation.Infinite
              }
            }

            MouseArea {
              id: clearLocationArea
              anchors.fill: parent
              enabled: !root.savingLocation
              hoverEnabled: true
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: root.clearLocation()
            }
          }
        }

        Column {
          id: locationSuggestionsColumn
          visible: root.editingLocation && !root.savingLocation && root.locationSuggestions.length > 0
          width: parent.width
          spacing: 0

          Repeater {
            model: root.locationSuggestions

            Rectangle {
              required property var modelData
              required property int index
              width: parent.width
              height: suggestionRow.implicitHeight + Style.space(12)
              radius: Style.cornerRadius
              color: index === root.suggestionIndex ? Style.hoverFillFor(root.bar.foreground, Color.accent) : Color.popups.background

              Row {
                id: suggestionRow
                anchors.left: parent.left
                anchors.leftMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(8)

                Text {
                  text: modelData.name
                  color: index === root.suggestionIndex ? Style.hoverStateColor(root.bar.foreground, Color.accent) : root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.body
                }
                Text {
                  visible: text !== ""
                  text: modelData.description
                  color: Qt.darker(root.bar.foreground, 1.5)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: root.suggestionIndex = index
                onClicked: root.pickSuggestion(modelData)
              }
            }
          }
        }
      }

      PlaceFrame {
        id: placeFrame
        anchors.top: headerColumn.bottom
        anchors.topMargin: Style.space(12)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        location: root.activeLocationQuery
        units: root.unitOverride
        active: root.opened
        refreshMinutes: root.refreshMinutes
        foreground: root.bar.foreground
        fontFamily: root.bar.fontFamily
        fontPixelSize: root.termFontSize
        cellW: root.cellW
        cellH: root.cellH
        sectionPad: root.sectionPad
        sectionGap: root.sectionGap
      }
    }
  }
}
