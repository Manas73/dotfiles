import QtQuick
import QtQuick.Layouts
import qs.components

Item {
  id: root

  property string app: ""
  property string summary: ""
  property string body: ""
  property string glyph: ""
  property double timestamp: 0
  property string fontFamily: ""

  readonly property string when: timestamp > 0 ? Qt.formatTime(new Date(timestamp), "hh:mm AP") : ""

  implicitWidth: Style.space(360)
  implicitHeight: column.implicitHeight + Style.space(16)

  Column {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(12)
    anchors.rightMargin: Style.space(12)
    spacing: Style.space(2)

    RowLayout {
      width: parent.width
      spacing: Style.space(8)

      Text {
        visible: root.glyph.length > 0
        text: root.glyph
        color: Color.notifications.text
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        Layout.fillWidth: true
        text: root.summary || root.app || "Notification"
        elide: Text.ElideRight
        color: Color.notifications.text
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Text {
        text: root.when
        color: Qt.darker(Color.notifications.text, 1.4)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Text {
      visible: root.body.length > 0
      width: parent.width
      text: root.body.replace(/\n/g, " ")
      elide: Text.ElideRight
      maximumLineCount: 2
      wrapMode: Text.Wrap
      color: Qt.darker(Color.notifications.text, 1.15)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
