import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import "../NotificationLogic.js" as NotificationLogic

BorderSurface {
  id: root

  property string app: ""
  property string appIcon: ""
  property string summary: ""
  property string body: ""
  property string image: ""
  property string glyph: ""
  property int urgency: 1
  property double timestamp: 0
  property int cornerRadius: Style.cornerRadius
  property string fontFamily: ""
  property real remainingLifetime: 0

  readonly property string sansFamily: "Adwaita Sans"
  readonly property string iconFamily: fontFamily.length > 0 ? fontFamily : Style.font.family
  readonly property bool hovered: hoverTracker.hovered
  readonly property bool hasGlyph: glyph.length > 0
  readonly property bool hasSmallIcon: smallIconSource.length > 0
  readonly property bool showIcon: (hasSmallIcon && smallIconImage.status !== Image.Error) || hasGlyph
  readonly property bool showApp: app.length > 0 && app !== summary
  readonly property string sanitizedBody: NotificationLogic.sanitizeBody(body, app, appIcon)
  readonly property string styledBody: sanitizedBody.replace(/\r\n|\r|\n/g, "<br/>")
  readonly property string smallIconSource: image.length > 0 ? image : iconSource(appIcon)
  readonly property color dimColor: Qt.darker(Color.notifications.text, 1.45)
  readonly property color bodyColor: Qt.darker(Color.notifications.text, 1.18)
  readonly property color accentColor: urgency === 2 ? Color.urgent : Color.notifications.countdown
  readonly property bool showCountdown: remainingLifetime > 0 && remainingLifetime < 1

  signal closeRequested()
  signal cardClicked()

  function iconSource(icon) {
    var value = String(icon || "")
    if (value.length === 0) return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    return Quickshell.iconPath(value, true)
  }

  implicitWidth: Style.space(360)
  implicitHeight: content.implicitHeight + borderTop + borderBottom
  radius: Math.max(root.cornerRadius, Style.space(10))
  color: Color.notifications.background
  borderSpec: Border.surfaceSpec("notifications", "border", Color.notifications.border, 1)
  clip: true

  HoverHandler { id: hoverTracker }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.closeRequested()
      else root.cardClicked()
    }
  }

  Rectangle {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.topMargin: root.borderTop + Style.space(10)
    anchors.bottomMargin: root.borderBottom + Style.space(10)
    width: Style.space(3)
    radius: width / 2
    color: root.accentColor
    opacity: root.urgency === 0 ? 0.35 : 0.9
  }

  ColumnLayout {
    id: content
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.topMargin: root.borderTop
    anchors.leftMargin: root.borderLeft
    anchors.rightMargin: root.borderRight
    spacing: 0

    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: Style.space(16)
      Layout.rightMargin: Style.space(28)
      Layout.topMargin: Style.space(12)
      Layout.bottomMargin: Style.space(12)
      spacing: Style.space(12)

      Rectangle {
        visible: root.showIcon
        Layout.preferredWidth: Style.space(36)
        Layout.preferredHeight: Style.space(36)
        Layout.alignment: Qt.AlignTop
        radius: Style.space(8)
        color: Util.alpha(Color.notifications.text, 0.08)

        Image {
          id: smallIconImage
          anchors.fill: parent
          anchors.margins: Style.space(6)
          source: root.smallIconSource
          sourceSize.width: width * Screen.devicePixelRatio
          sourceSize.height: height * Screen.devicePixelRatio
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          smooth: true
          visible: !root.hasGlyph || status === Image.Ready
        }

        Text {
          anchors.centerIn: parent
          visible: root.hasGlyph && smallIconImage.status !== Image.Ready
          text: root.glyph
          color: Color.notifications.text
          font.family: root.iconFamily
          font.pixelSize: Style.font.heading
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: Style.space(2)

        Text {
          Layout.fillWidth: true
          visible: root.showApp
          text: root.app
          color: root.dimColor
          font.family: root.sansFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 0.4
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          visible: root.summary.length > 0
          text: root.summary
          color: Color.notifications.text
          font.family: root.sansFamily
          font.pixelSize: Style.font.subtitle
          font.weight: Font.DemiBold
          wrapMode: Text.WordWrap
          elide: Text.ElideRight
          maximumLineCount: 2
        }

        Text {
          Layout.fillWidth: true
          visible: root.sanitizedBody.length > 0
          text: root.styledBody
          textFormat: Text.StyledText
          color: root.bodyColor
          font.family: root.sansFamily
          font.pixelSize: Style.font.body
          lineHeight: 1.35
          wrapMode: Text.WordWrap
          elide: Text.ElideRight
          maximumLineCount: 3
        }
      }
    }

    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: root.showCountdown ? Style.space(3) : 0

      Rectangle {
        visible: root.showCountdown
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        height: Style.space(2)
        width: parent.width * Math.max(0, Math.min(1, root.remainingLifetime))
        color: root.accentColor
        opacity: 0.7
        radius: 1
      }
    }
  }

  Rectangle {
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: root.borderTop + Style.space(8)
    anchors.rightMargin: root.borderRight + Style.space(8)
    width: Style.space(20)
    height: Style.space(20)
    radius: width / 2
    color: closeArea.containsMouse ? Util.alpha(Color.notifications.text, 0.12) : "transparent"
    visible: opacity > 0
    opacity: root.hovered ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 120 } }

    Text {
      anchors.centerIn: parent
      text: "󰅖"
      color: closeArea.containsMouse ? Color.notifications.text : root.dimColor
      font.family: root.iconFamily
      font.pixelSize: Style.font.bodySmall
    }

    MouseArea {
      id: closeArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.closeRequested()
    }
  }
}
