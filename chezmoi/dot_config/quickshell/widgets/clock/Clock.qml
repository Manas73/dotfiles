import QtQuick
import Quickshell
import qs.components
import "ClockModel.js" as Model

Item {
  id: root

  property var bar: null
  property string format: "hh:mm AP"
  property string formatAlt: "yyyy-MM-dd hh:mm:ss AP"
  property bool showingAlt: false

  readonly property string activeFormat: showingAlt ? formatAlt : format
  readonly property bool showsSeconds: Model.clockNeedsSeconds(activeFormat)
  readonly property string displayText: Qt.formatDateTime(clock.date, activeFormat)
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
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.showingAlt = !root.showingAlt
      else root.toggle()
    }
  }
}
