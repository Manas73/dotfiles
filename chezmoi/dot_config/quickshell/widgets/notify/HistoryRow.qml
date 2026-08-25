import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components

Item {
  id: root

  property string app: ""
  property string appIcon: ""
  property string summary: ""
  property string body: ""
  property string image: ""
  property string glyph: ""
  property double timestamp: 0
  property int originalId: 0
  property string fontFamily: ""

  signal dismissed()

  readonly property string when: timestamp > 0 ? Qt.formatTime(new Date(timestamp), "hh:mm AP") : ""
  readonly property string leadSource: sourceFor(appIcon)
  readonly property string previewSource: sourceFor(image)
  readonly property bool hasPreview: previewSource.length > 0
  readonly property bool hasLeadImage: leadSource.length > 0 && leadSource !== previewSource
  readonly property bool hasGlyph: glyph.length > 0 && !hasLeadImage && !hasPreview

  function sourceFor(value) {
    var s = String(value || "")
    if (!s) return ""
    if (s.indexOf("file://") === 0 || s.indexOf("image://") === 0) return s
    if (s.charAt(0) === "/") return Util.fileUrl(s)
    return Quickshell.iconPath(s, true)
  }

  implicitWidth: Style.space(360)
  implicitHeight: column.implicitHeight + Style.space(16)

  Column {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(4)
    anchors.rightMargin: Style.space(4)
    spacing: Style.space(8)

    RowLayout {
      width: parent.width
      spacing: Style.space(10)

      Rectangle {
        visible: root.hasLeadImage || root.hasGlyph
        Layout.preferredWidth: Style.space(32)
        Layout.preferredHeight: Style.space(32)
        Layout.alignment: Qt.AlignTop
        radius: Style.space(8)
        color: Util.alpha(Color.notifications.text, 0.08)

        Image {
          anchors.fill: parent
          anchors.margins: Style.space(5)
          visible: root.hasLeadImage
          source: root.leadSource
          sourceSize.width: width * Screen.devicePixelRatio
          sourceSize.height: height * Screen.devicePixelRatio
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          smooth: true
        }

        Text {
          anchors.centerIn: parent
          visible: root.hasGlyph
          text: root.glyph
          color: Color.notifications.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
      }

      Column {
        Layout.fillWidth: true
        spacing: Style.space(2)

        RowLayout {
          width: parent.width
          spacing: Style.space(8)

          Text {
            Layout.fillWidth: true
            text: root.summary || root.app || "Notification"
            elide: Text.ElideRight
            color: Color.notifications.text
            font.family: "Adwaita Sans"
            font.pixelSize: Style.font.body
            font.weight: Font.DemiBold
          }

          Text {
            text: root.when
            color: Qt.darker(Color.notifications.text, 1.4)
            font.family: "Adwaita Sans"
            font.pixelSize: Style.font.caption
          }

          Rectangle {
            Layout.preferredWidth: Style.space(20)
            Layout.preferredHeight: Style.space(20)
            Layout.alignment: Qt.AlignVCenter
            radius: width / 2
            color: closeArea.containsMouse ? Util.alpha(Color.notifications.text, 0.12) : "transparent"

            Text {
              anchors.centerIn: parent
              text: "󰅖"
              color: closeArea.containsMouse ? Color.notifications.text : Qt.darker(Color.notifications.text, 1.5)
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: closeArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.dismissed()
            }
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
          font.family: "Adwaita Sans"
          font.pixelSize: Style.font.caption
        }
      }
    }

    Image {
      visible: root.hasPreview && status !== Image.Error && status !== Image.Null
      width: parent.width
      height: Math.min(Math.round(width * 0.56), Style.space(140))
      source: root.previewSource
      sourceSize.width: width * Screen.devicePixelRatio
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      smooth: true
    }
  }
}
