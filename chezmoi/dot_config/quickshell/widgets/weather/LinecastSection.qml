import QtQuick
import qs.components

Item {
  id: root

  property string title: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property int padding: Style.space(10)

  default property alias content: body.children

  Column {
    anchors.fill: parent
    spacing: Style.space(6)

    PanelSectionHeader {
      id: header
      width: parent.width
      text: root.title
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    BorderSurface {
      id: frame
      width: parent.width
      height: parent.height - header.height - parent.spacing
      color: "transparent"
      radius: Style.cornerRadius
      padding: root.padding
      borderSpec: Border.flat(Util.alpha(root.foreground, 0.16), Math.max(1, Style.spacing.hairline))

      Item {
        id: body
        anchors.fill: parent
        anchors.topMargin: frame.contentTopInset
        anchors.rightMargin: frame.contentRightInset
        anchors.bottomMargin: frame.contentBottomInset
        anchors.leftMargin: frame.contentLeftInset
      }
    }
  }
}
