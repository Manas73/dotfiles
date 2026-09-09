import QtQuick
import Quickshell
import qs.components
import "ClockModel.js" as Model

Item {
  id: root

  property var bar: null
  property string format: "hh:mm AP"
  property string formatAlt: "yyyy-MM-dd hh:mm:ss AP"
  property string tooltipFormat: "hh:mm:ss AP | yyyy-MM-dd"
  property bool showingAlt: false

  readonly property string activeFormat: showingAlt ? formatAlt : format
  readonly property bool showsSeconds: Model.clockNeedsSeconds(activeFormat) || Model.clockNeedsSeconds(tooltipFormat)
  readonly property string displayText: Qt.formatDateTime(clock.date, activeFormat)
  readonly property string tooltipText: Qt.formatDateTime(clock.date, tooltipFormat)
  readonly property color foreground: bar ? bar.barForeground : Color.bar.text

  implicitWidth: label.implicitWidth + Style.space(16)
  implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

  SystemClock {
    id: clock
    precision: root.showsSeconds ? SystemClock.Seconds : SystemClock.Minutes
  }

  readonly property bool opened: calendarLoader.item ? calendarLoader.item.opened === true : false

  function injectCalendar() {
    var cal = calendarLoader.item
    if (!cal) return
    cal.bar = root.bar
    cal.anchorItem = root
    cal.hostWidget = root
  }

  function open() {
    if (calendarLoader.item) calendarLoader.item.open()
  }

  function close() {
    if (calendarLoader.item) calendarLoader.item.close()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function showTooltip() {
    if (root.bar) root.bar.showTooltip(root, root.tooltipText)
  }

  function hideTooltip() {
    if (root.bar) root.bar.hideTooltip(root)
  }

  // Keep the tooltip in step with the clock while the pointer stays on it;
  // WidgetButton only writes the text on enter, so seconds would freeze.
  onTooltipTextChanged: if (mouse.containsMouse) root.showTooltip()
  onVisibleChanged: if (!visible) root.hideTooltip()
  Component.onDestruction: root.hideTooltip()

  Loader {
    id: calendarLoader
    active: true
    source: Qt.resolvedUrl("Calendar.qml")
    visible: false
    onLoaded: {
      root.injectCalendar()
      Qt.callLater(root.injectCalendar)
    }
  }

  onBarChanged: injectCalendar()

  Text {
    id: label
    anchors.centerIn: parent
    text: root.displayText
    color: root.foreground
    font.family: bar ? bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
    renderType: Text.NativeRendering
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: root.showTooltip()
    onExited: root.hideTooltip()
    onClicked: function(event) {
      root.hideTooltip()
      if (event.button === Qt.RightButton) root.showingAlt = !root.showingAlt
      else root.toggle()
    }
  }
}
