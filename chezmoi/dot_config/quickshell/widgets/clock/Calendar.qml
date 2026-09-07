import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import "ClockModel.js" as Model

// The clock's calendar popup: three world clocks, then a month grid with
// ISO week numbers. Built to sit beside the weather panel — same spacing
// scale, same small-caps labels. Click a clock to set its timezone.
//
// The grid is a read-out rather than a picker: today is the only marked
// day, and the only thing that moves is which month is on screen —
// chevrons, the scroll wheel, and the arrow keys all step it.
//
// BarWidget.qml owns the bar label and hands this panel the button to
// anchor against.
Panel {
  id: root
  moduleName: "clock"
  ipcTarget: "clock"
  manageIpc: false

  property var anchorItem: null

  // The bar tracks the widget mounted in its slot — BarWidget.qml — not this
  // nested panel. Everything the bar identifies a panel by has to be that
  // widget: the popout coordinator (and with it the open-panel dot under the
  // pill) compares against `slot.activeItem`, and switchPanelFrom looks the
  // slot up the same way.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // ---- Today. SystemClock keeps this honest across midnight so the
  //      highlight rolls over without the panel being reopened.
  property date today: new Date()
  readonly property string todayKey: Model.keyForDate(today)

  // The month on screen. Stepping moves this and nothing else: the grid is
  // a read-out, not a picker, so there is no per-day cursor to keep in sync.
  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()

  readonly property date viewDate: new Date(viewYear, viewMonth, 1)
  readonly property bool viewingCurrentMonth: viewYear === today.getFullYear() && viewMonth === today.getMonth()

  // Three labeled IANA zones above the date. Missing config falls through
  // to Local / UTC / New York; clicking a clock edits that slot's label
  // and zone, then persistSettings writes it next to week-start and life.
  readonly property var worldClocks: Model.parseWorldClocks(root.settings && root.settings.worldClocks)
  property int editingWorldClock: -1
  readonly property bool editingClocks: editingWorldClock >= 0
  // Minutes east of UTC, one per clock. Local is `null` (use wall time);
  // NaN is an unknown IANA zone. Qt's JS Intl ignores timeZone, so IANA
  // offsets come from `date +%z` against /usr/share/zoneinfo.
  property var worldClockOffsetMinutes: []
  property bool clockSettingsLoaded: false
  property bool clockSettingsHydrating: false
  readonly property string clockSettingsDir: Quickshell.env("HOME") + "/.local/state/quickshell/settings"
  readonly property string clockSettingsPath: clockSettingsDir + "/clock.json"
  readonly property string timezoneCachePath: clockSettingsDir + "/timezones.json"
  property var timezoneCache: []
  property string timezoneCacheFetchedAt: ""
  property bool timezoneRefreshing: false
  readonly property var timezoneOptions: Model.timezoneDropdownOptions(
    root.timezoneCache,
    root.editingWorldClock >= 0 && root.worldClocks[root.editingWorldClock]
      ? root.worldClocks[root.editingWorldClock].zone
      : ""
  )

  // Unset falls through to the locale's own first day, so a fresh install
  // starts out matching the rest of the desktop rather than a hardcoded
  // convention. Clicking the grid's "W" heading writes the choice back to
  // shell.json.
  readonly property int weekStart: Model.normalizedWeekStart(root.settings && root.settings.weekStartDay, Qt.locale().firstDayOfWeek)
  // The interface is English throughout, so day names are not taken from the
  // system locale. Where the week starts still is: that is a regional
  // convention rather than a translation, and it stays overridable above.
  readonly property var labelLocale: Qt.locale("en_US")
  readonly property string nextWeekStartLabel: labelLocale.dayName(Model.toggledWeekStart(weekStart), Locale.LongFormat)
  readonly property var weekdays: Model.weekdayOrder(weekStart)
  readonly property var weeks: Model.monthGrid(viewYear, viewMonth, weekStart, todayKey)


  // Guarded so the widget renders before the bar is injected (the bar-widget
  // contract instantiates it bare).
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property int cellWidth: Style.space(52)
  readonly property int cellHeight: Style.space(34)
  readonly property int cellSpacing: Style.space(2)
  readonly property int weekColumnWidth: Style.space(32)
  readonly property int gutterWidth: Style.space(14)

  function open() {
    refresh()
    root.controller.show()
    // Set after showing, not before: showing hands the popout coordinator
    // over, which closes whichever panel was open, and that close clears the
    // shared flag. Deferring means the panel taking over always wins, while
    // a handoff to a panel that does not manage the flag still leaves it
    // cleared rather than stuck on.
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    // Dismissing the panel mid-edit would otherwise leave the inputs up,
    // waiting behind a closed popup for the next time it opens.
    if (root.editingClocks) root.cancelEditingWorldClock()
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // Summoning by hotkey moves no pointer, so a hover the bar was still
  // holding must not keep the center indicators revealed behind the panel.
  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function refresh() {
    root.today = new Date()
    root.goToToday()
  }

  function goToToday() {
    root.viewYear = today.getFullYear()
    root.viewMonth = today.getMonth()
  }

  function moveMonth(delta) {
    var next = Model.stepMonth(viewYear, viewMonth, delta)
    root.viewYear = next.year
    root.viewMonth = next.month
  }

  function moveYear(delta) {
    moveMonth(delta * 12)
  }

  // Applied locally first so the panel redraws on the click itself. The
  // clock.json write is the restart-surviving copy; updateEntryInline is
  // kept for hosts that still own a layout entry. The host widget builds
  // its own entry when the label format is cycled, so it has to be kept
  // in step or it would write this key straight back out from a stale copy.
  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    root.writeClockSettingsFile(entry)
  }

  function setWeekStart(day) {
    var next = Model.normalizedWeekStart(day, root.weekStart)
    if (next === root.weekStart) return
    persistSettings({ weekStartDay: Model.weekStartSettingName(next) })
  }

  function toggleWeekStart() {
    setWeekStart(Model.toggledWeekStart(root.weekStart))
  }

  function startEditingWorldClock(index) {
    if (index < 0 || index > 2) return
    root.editingWorldClock = index
    Qt.callLater(function() {
      var entry = root.worldClocks[index] || {}
      worldZoneField.value = entry.zone || "Local"
    })
  }

  function cancelEditingWorldClock() {
    if (worldZoneField && worldZoneField.popupOpen) worldZoneField.close()
    root.editingWorldClock = -1
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  function commitWorldClock() {
    var index = root.editingWorldClock
    if (index < 0) {
      root.cancelEditingWorldClock()
      return
    }
    var next = Model.parseWorldClocks(root.worldClocks)
    next[index] = Model.parseWorldClock({
      zone: worldZoneField.value
    }, next[index])
    persistSettings({ worldClocks: next })
    cancelEditingWorldClock()
  }

  function applyTimezoneCacheFile(raw) {
    var parsed = Model.parseTimezoneCacheFile(raw)
    root.timezoneCache = parsed.timezones
    root.timezoneCacheFetchedAt = parsed.fetchedAt
  }

  function applyTimezoneFetch(raw) {
    root.timezoneRefreshing = false
    var parsed = Model.parseTimezoneList(raw)
    if (parsed.length === 0) return
    var fetchedAt = new Date().toISOString()
    root.timezoneCache = parsed
    root.timezoneCacheFetchedAt = fetchedAt
    if (ensureClockSettingsDir.running !== true)
      ensureClockSettingsDir.running = true
    timezoneCacheFile.setText(JSON.stringify(Model.serializeTimezoneCache(parsed, fetchedAt), null, 2) + "\n")
  }

  function refreshTimezoneCache() {
    if (timezoneFetchProc.running) return
    root.timezoneRefreshing = true
    timezoneFetchProc.running = true
  }

  function applyClockSettingsFile(raw) {
    var parsed = Model.parseClockSettingsFile(raw)
    root.clockSettingsHydrating = true
    if (parsed) {
      var entry = { id: root.moduleName }
      for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
      for (var key in parsed) entry[key] = parsed[key]
      root.settings = entry
      if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    }
    root.clockSettingsHydrating = false
    root.clockSettingsLoaded = true
  }

  function writeClockSettingsFile(entry) {
    if (!root.clockSettingsLoaded || root.clockSettingsHydrating) return
    if (ensureClockSettingsDir.running !== true)
      ensureClockSettingsDir.running = true
    clockSettingsFile.setText(JSON.stringify(Model.serializeClockSettings(entry), null, 2) + "\n")
  }

  function worldClockTime(index, zone, now) {
    var offsets = root.worldClockOffsetMinutes
    var offset = offsets && index < offsets.length ? offsets[index] : undefined
    return Model.formatWorldTime(now, zone, offset)
  }

  function applyWorldClockOffsets(raw) {
    var lines = String(raw || "").replace(/^\s+|\s+$/g, "").split(/\n/)
    var next = []
    for (var i = 0; i < 3; i++) next.push(Model.parseUtcOffset(lines[i]))
    root.worldClockOffsetMinutes = next
  }

  function refreshWorldClockOffsets() {
    if (!worldOffsetProc) return
    var clocks = root.worldClocks
    worldOffsetProc.running = false
    worldOffsetProc.command = [
      "bash", "-c",
      'for z; do' +
        ' if [ "$z" = Local ] || [ -z "$z" ]; then echo local;' +
        ' elif [ "$z" = UTC ]; then echo +0000;' +
        ' elif [ -e "/usr/share/zoneinfo/$z" ]; then TZ="$z" date +%z;' +
        ' else echo invalid; fi;' +
      ' done',
      "world-offset",
      Model.normalizeZone(clocks[0] && clocks[0].zone),
      Model.normalizeZone(clocks[1] && clocks[1].zone),
      Model.normalizeZone(clocks[2] && clocks[2].zone)
    ]
    worldOffsetProc.running = true
  }

  // English short day names, matching the rest of the interface.
  function weekdayLabel(weekday) {
    return String(labelLocale.dayName(weekday, Locale.ShortFormat)).toUpperCase()
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: {
      if (Model.keyForDate(clock.date) === String(root.todayKey)) return
      var followToday = root.viewingCurrentMonth
      root.today = clock.date
      if (followToday) root.goToToday()
    }
  }

  Process {
    id: ensureClockSettingsDir
    command: ["mkdir", "-p", root.clockSettingsDir]
  }

  Process {
    id: worldOffsetProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyWorldClockOffsets(text)
    }
  }

  onWorldClocksChanged: root.refreshWorldClockOffsets()

  FileView {
    id: clockSettingsFile
    path: root.clockSettingsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyClockSettingsFile(text())
    onLoadFailed: root.applyClockSettingsFile("")
  }

  FileView {
    id: timezoneCacheFile
    path: root.timezoneCachePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyTimezoneCacheFile(text())
    onLoadFailed: root.applyTimezoneCacheFile("")
  }

  Process {
    id: timezoneFetchProc
    command: ["curl", "-fsS", "--max-time", "10", "https://timeapi.io/api/v1/timezone/availabletimezones"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyTimezoneFetch(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.timezoneRefreshing = false
    }
  }

  Component.onCompleted: {
    ensureClockSettingsDir.running = true
    root.refreshWorldClockOffsets()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.fittedContentHeight(calendarColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: worldZoneField && worldZoneField.popupOpen
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.moveMonth(dx)
        if (dy !== 0) root.moveYear(dy)
      }
      onActivateRequested: {
        if (root.editingClocks) root.commitWorldClock()
        else root.goToToday()
      }
      onCloseRequested: {
        if (root.editingClocks) root.cancelEditingWorldClock()
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "[") root.moveMonth(-1)
        else if (t === "]") root.moveMonth(1)
        else if (t === "{") root.moveYear(-1)
        else if (t === "}") root.moveYear(1)
        else if (t === "t" || t === "T") root.goToToday()
        else if (t === "w" || t === "W") root.toggleWeekStart()
      }

      Flickable {
        id: calendarScroll
        anchors.fill: parent
        contentWidth: calendarColumn.width
        contentHeight: calendarColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height || contentWidth > width

        Column {
          id: calendarColumn
          // Never narrower than the grid. The popup width is capped to what
          // the screen allows, and a fixed seven-column grid would otherwise
          // lose its last days off the edge instead of scrolling.
          width: Math.max(calendarScroll.width, gridColumn.width)
          spacing: Style.space(8)

          // ---- World clocks. Click one to set that slot's IANA zone.
          Item {
            width: parent.width
            height: worldClocksBlock.height

            Item {
                id: worldClocksBlock
                anchors.horizontalCenter: parent.horizontalCenter
                width: gridColumn.width
                height: root.editingClocks ? worldClockEditor.height : worldClocksRow.height

                Row {
                  id: worldClocksRow
                  visible: !root.editingClocks
                  width: parent.width
                  spacing: 0

                  Repeater {
                    model: root.worldClocks

                    Item {
                      id: worldClockCell
                      required property int index
                      required property var modelData

                      width: Math.floor(worldClocksRow.width / 3)
                      height: worldClockCol.height

                      Column {
                        id: worldClockCol
                        width: parent.width
                        spacing: Style.space(2)

                        Text {
                          width: parent.width
                          horizontalAlignment: Text.AlignHCenter
                          elide: Text.ElideRight
                          text: String(worldClockCell.modelData.label || "").toUpperCase()
                          color: worldClockMouse.containsMouse
                            ? Style.hoverStateColor(root.contentForeground, Color.accent)
                            : Qt.darker(root.contentForeground, 1.5)
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption
                          font.letterSpacing: 1
                          font.bold: true
                        }

                        Text {
                          width: parent.width
                          horizontalAlignment: Text.AlignHCenter
                          text: {
                            var _ = root.worldClockOffsetMinutes
                            return root.worldClockTime(worldClockCell.index, worldClockCell.modelData.zone, clock.date) || "—"
                          }
                          color: worldClockMouse.containsMouse
                            ? Style.hoverStateColor(root.contentForeground, Color.accent)
                            : root.contentForeground
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.heading
                        }
                      }

                      MouseArea {
                        id: worldClockMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startEditingWorldClock(worldClockCell.index)

                        PanelToolTip {
                          visible: worldClockMouse.containsMouse
                          text: "Set timezone"
                          fontFamily: root.contentFontFamily
                        }
                      }
                    }
                  }
                }

                Column {
                  id: worldClockEditor
                  visible: root.editingClocks
                  width: parent.width
                  spacing: Style.space(8)

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "TIMEZONE"
                    color: Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.letterSpacing: 1
                  }

                  Item {
                    width: parent.width
                    height: worldZoneField.height

                    SearchableDropdown {
                      id: worldZoneField
                      anchors.horizontalCenter: parent.horizontalCenter
                      width: Style.space(200)
                      showLabel: false
                      textAlignment: Text.AlignHCenter
                      options: root.timezoneOptions
                      placeholderText: "Search timezones"
                      emptyText: root.timezoneCache.length === 0 ? "Refresh to load timezones" : "No matches"
                      foreground: root.contentForeground
                      fontFamily: root.contentFontFamily
                    }

                    PanelActionButton {
                      id: timezoneRefresh
                      anchors.left: worldZoneField.right
                      anchors.leftMargin: Style.space(10)
                      anchors.verticalCenter: worldZoneField.verticalCenter
                      iconText: "󰑐"
                      tooltipText: root.timezoneRefreshing
                        ? "Fetching timezones…"
                        : (root.timezoneCache.length > 0 ? "Refresh timezone list" : "Download timezone list")
                      foreground: root.contentForeground
                      fontFamily: root.contentFontFamily
                      enabled: !root.timezoneRefreshing
                      onClicked: root.refreshTimezoneCache()
                    }
                  }

                  Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Submit"
                    foreground: root.contentForeground
                    fontFamily: root.contentFontFamily
                    bordered: true
                    onClicked: root.commitWorldClock()
                  }
                }
              }
          }

          Item {
            width: parent.width
            height: 1

            PanelSeparator {
              anchors.horizontalCenter: parent.horizontalCenter
              width: gridColumn.width
              foreground: root.contentForeground
            }
          }

          // ---- Month stepping, spanning the grid it drives. Sits above
          //      the days so the month you are looking at is named before
          //      you start reading it. The chevrons sit on the grid's
          //      outer bounds so the row reads as a full-width rail. The
          //      label is centered and fixed-width, so it holds still
          //      from "MAY" to "SEPTEMBER".
          Item {
            width: parent.width
            height: monthNav.height

            Item {
              id: monthNav
              anchors.horizontalCenter: parent.horizontalCenter
              width: gridColumn.width
              height: monthLabel.implicitHeight + Style.space(10)

              Text {
                id: monthLabel
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                // Fixed width so the chevrons hold still between a
                // "MAY 2026" and a "SEPTEMBER 2026".
                width: Style.space(130)
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDate(root.viewDate, "MMMM yyyy").toUpperCase()
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.letterSpacing: 1
              }

              PanelActionButton {
                // Pulled out by the button's own padding so the glyph, not
                // its hit box, lines up with the grid's outer edge.
                anchors.left: parent.left
                anchors.leftMargin: -Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰅁"
                tooltipText: "Previous month"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.moveMonth(-1)
              }

              PanelActionButton {
                anchors.right: parent.right
                anchors.rightMargin: -Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰅂"
                tooltipText: "Next month"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.moveMonth(1)
              }
            }
          }

          // ---- Month grid: week numbers down a gutter on the left, then
          //      the seven day columns. Always six rows, so the popup is
          //      exactly as tall in February as it is in August.
          Item {
            width: parent.width
            height: gridColumn.y + gridColumn.height

            WheelHandler {
              onWheel: function(event) {
                // Horizontal wheels and touchpad side-scrolls report y === 0;
                // without this they would every one read as "next month".
                if (event.angleDelta.y === 0) return
                root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
              }
            }

            Column {
              id: gridColumn
              // Small gap so the weekday headers don't kiss the chevrons.
              y: Style.space(6)
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(3)

              Row {
                id: headerRow
                spacing: root.cellSpacing

                // The week-number heading doubles as the week-start toggle.
                // It is the one control in the panel whose meaning is not
                // self-evident, so it carries a tooltip naming the day the
                // click will switch to.
                Rectangle {
                  width: root.weekColumnWidth
                  height: Style.space(16)
                  radius: Style.cornerRadius
                  color: weekStartMouse.containsMouse
                    ? Style.hoverFillFor(root.contentForeground, Color.accent)
                    : "transparent"

                  Text {
                    anchors.centerIn: parent
                    text: "W"
                    color: weekStartMouse.containsMouse
                      ? Style.hoverStateColor(root.contentForeground, Color.accent)
                      : Qt.darker(root.contentForeground, 1.9)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 1
                    font.bold: true
                  }

                  MouseArea {
                    id: weekStartMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleWeekStart()
                  }

                  PanelToolTip {
                    visible: weekStartMouse.containsMouse
                    text: "Start weeks on " + root.nextWeekStartLabel
                    fontFamily: root.contentFontFamily
                  }
                }

                Item {
                  width: root.gutterWidth
                  height: Style.space(16)
                }

                Repeater {
                  model: root.weekdays

                  Text {
                    required property var modelData
                    width: root.cellWidth
                    height: Style.space(16)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.weekdayLabel(modelData)
                    color: Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 1
                    font.bold: true
                  }
                }
              }

              Repeater {
                model: root.weeks

                Row {
                  required property var modelData
                  spacing: root.cellSpacing

                  Text {
                    width: root.weekColumnWidth
                    height: root.cellHeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.week
                    color: Qt.darker(root.contentForeground, 1.9)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Item {
                    width: root.gutterWidth
                    height: root.cellHeight
                  }

                  Repeater {
                    model: modelData.days

                    Rectangle {
                      required property var modelData

                      width: root.cellWidth
                      height: root.cellHeight
                      radius: Style.cornerRadius
                      // Today is outlined, not filled: a lit-up block shouts
                      // over a grid this quiet.
                      color: "transparent"
                      border.width: modelData.today ? Style.spacing.hairline : 0
                      border.color: Style.normalBorderFor(root.contentForeground, Color.accent)

                      Text {
                        anchors.centerIn: parent
                        text: modelData.day
                        color: modelData.inMonth
                          ? (modelData.weekend ? Qt.darker(root.contentForeground, 1.45) : root.contentForeground)
                          : Qt.darker(root.contentForeground, 2.2)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.body
                        font.bold: modelData.today
                      }
                    }
                  }
                }
              }
            }

            // Hairline down the week-number gutter, drawn only beside the
            // day rows so it does not cut through the header band.
            Rectangle {
              x: gridColumn.x + root.weekColumnWidth + root.cellSpacing + Math.round((root.gutterWidth - width) / 2)
              y: gridColumn.y + headerRow.height + gridColumn.spacing
              width: Style.spacing.hairline
              height: gridColumn.height - headerRow.height - gridColumn.spacing
              color: root.contentForeground
              opacity: 0.1
            }
          }
        }
      }
    }
  }
}
