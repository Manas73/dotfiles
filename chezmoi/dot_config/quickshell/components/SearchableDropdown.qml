import QtQuick
import QtQuick.Controls as QQC
import qs.components

// Searchable single-select dropdown. Same trigger shape as Dropdown, but
// the popup leads with an embedded TextField that filters the option
// list in real time. Use for pickers with enough options that scanning
// is friction.
//
// Filtering is case-insensitive substring against each option's label,
// description, and value. The filter clears whenever the popup closes.
//
// popupType Window makes this an xdg-popup of the parent layer-shell
// surface so Hyprland's blur_popups rule can frost it. Item popups are
// just more pixels on the panel and never get a blur pass.
//
// Keyboard: Tab to focus the trigger, Enter/Space opens (search focused
// immediately). Down arrow from the search jumps to the first match;
// Up from the first match returns to the search. Enter selects, Esc
// closes (and clears the filter).
Item {
  id: root

  property string label: ""
  property string value: ""
  property var options: []
  property string placeholderText: "Search..."
  property string emptyText: "No matches"
  property string triggerLabel: ""

  property color foreground: Color.popups.text
  property color background: Color.popups.background
  property color popupBorder: Color.popups.border
  property color accent: Color.accent
  readonly property var popupBorderSpec: Border.localOrSurfaceSpec("popups", "border", popupBorder, Color.popups.border, Style.normalBorderWidth)
  property string fontFamily: Style.font.family
  property int rowHeight: Style.spacing.controlHeight
  property int popupRowHeight: Style.spacing.popupRowHeight
  property int popupMinHeight: Style.spacing.searchablePopupMinHeight
  property bool showLabel: true
  property int textAlignment: Text.AlignLeft

  property bool hasCursor: false

  readonly property bool popupOpen: popup.opened
  function open() { popup.open() }
  function close() { popup.close() }
  function toggle() { popup.opened ? popup.close() : popup.open() }

  signal changed(string value)
  signal hovered(bool isHovered)

  function optionValue(o) {
    return (o && typeof o === "object") ? String(o.value) : String(o)
  }
  function optionLabel(o) {
    return (o && typeof o === "object") ? String(o.label) : String(o)
  }
  function optionDescription(o) {
    return (o && typeof o === "object" && o.description) ? String(o.description) : ""
  }
  function currentLabel() {
    for (var i = 0; i < options.length; i++) {
      if (optionValue(options[i]) === value) return optionLabel(options[i])
    }
    return value
  }

  property var filtered: options
  function recomputeFiltered() {
    var q = searchField.text.toLowerCase()
    if (!q) { filtered = options; return }
    var out = []
    for (var i = 0; i < options.length; i++) {
      var lbl = optionLabel(options[i]).toLowerCase()
      var desc = optionDescription(options[i]).toLowerCase()
      var val = optionValue(options[i]).toLowerCase()
      if (lbl.indexOf(q) !== -1 || desc.indexOf(q) !== -1 || val.indexOf(q) !== -1)
        out.push(options[i])
    }
    filtered = out
  }

  onOptionsChanged: recomputeFiltered()

  implicitWidth: Style.spacing.searchableDropdownWidth
  implicitHeight: showLabel && label !== "" ? rowHeight + Style.spacing.huge : rowHeight

  Column {
    anchors.fill: parent
    spacing: Style.spacing.labelGap

    Text {
      visible: root.showLabel && root.label !== ""
      text: root.label
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    BorderSurface {
      id: trigger
      width: parent.width
      height: root.rowHeight
      radius: Style.cornerRadius

      readonly property bool _focused: trigger.activeFocus
      readonly property bool _hot: triggerHover.hovered || root.hasCursor
      readonly property var _borderSpec: Border.controlSpec(trigger._focused ? "focus" : (trigger._hot ? "hover-cursor" : "normal"), root.foreground, root.accent)

      color: Style.controlFill(trigger._focused, trigger._hot, root.foreground, root.accent)
      borderSpec: _borderSpec

      activeFocusOnTab: true

      HoverHandler {
        id: triggerHover
        onHoveredChanged: root.hovered(hovered)
      }

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
            || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
          popup.opened ? popup.close() : popup.open()
          event.accepted = true
        } else if (event.key === Qt.Key_Escape && popup.opened) {
          popup.close(); event.accepted = true
        }
      }

      Text {
        anchors.left: parent.left
        anchors.right: root.textAlignment === Text.AlignHCenter ? parent.right : chevron.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.textAlignment === Text.AlignHCenter
          ? chevron.implicitWidth + Style.spacing.controlGap + trigger.borderLeft
          : trigger.borderLeft + Style.spacing.controlPaddingX
        anchors.rightMargin: chevron.implicitWidth + Style.spacing.controlGap + trigger.borderRight
        horizontalAlignment: root.textAlignment
        text: root.currentLabel() || root.triggerLabel || root.placeholderText
        color: (root.currentLabel() || root.triggerLabel) ? root.foreground : Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        id: chevron
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: trigger.borderRight + Style.spacing.controlGap
        text: "󰅀"
        color: Qt.darker(root.foreground, 1.2)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          trigger.forceActiveFocus()
          popup.opened ? popup.close() : popup.open()
        }
      }

      // Wayland's default xdg positioner for a generic Popup is
      // top-right / gravity right (menu-style), so the list opens beside
      // the field. ComboBox uses bottom-left / gravity down. A 1×1 parent
      // on the field's bottom-left makes that default land under the
      // trigger instead of to its right.
      Item {
        id: belowAnchor
        width: 1
        height: 1
        x: 0
        y: trigger.height + Style.spacing.xxs
      }

      QQC.Popup {
        id: popup
        parent: belowAnchor
        popupType: QQC.Popup.Window
        dim: false
        modal: false
        x: 0
        y: 0
        width: trigger.width
        implicitHeight: Math.max(root.popupMinHeight,
                                 Math.min(resultList.contentHeight + Style.space(50),
                                          root.popupRowHeight * 6 + 5 * Style.spacing.labelGap + Style.space(50)))
        padding: Style.spacing.hairline
        leftPadding: Border.left(root.popupBorderSpec) + Style.spacing.hairline
        rightPadding: Border.right(root.popupBorderSpec) + Style.spacing.hairline
        topPadding: Border.top(root.popupBorderSpec) + Style.spacing.hairline
        bottomPadding: Border.bottom(root.popupBorderSpec) + Style.spacing.hairline
        focus: true

        background: BorderSurface {
          color: root.background
          borderSpec: root.popupBorderSpec
          radius: Style.cornerRadius
        }

        onOpened: {
          searchField.text = ""
          root.recomputeFiltered()
          Qt.callLater(function() { searchField.forceActiveFocus() })
        }
        onClosed: searchField.text = ""

        contentItem: Column {
          spacing: 0

          Item {
            id: searchHeader
            width: parent.width
            height: root.popupRowHeight + Style.spacing.controlPaddingX

            TextField {
              id: searchField
              anchors.fill: parent
              anchors.margins: Style.spacing.md
              placeholderText: root.placeholderText
              foreground: root.foreground
              accent: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.body

              onTextChanged: {
                root.recomputeFiltered()
                if (resultList.count > 0) resultList.currentIndex = 0
              }

              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  popup.close(); event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                  if (resultList.count > 0) {
                    resultList.currentIndex = 0
                    resultList.forceActiveFocus()
                  }
                  event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  if (resultList.count > 0) {
                    resultList.currentIndex = 0
                    resultList.selectCurrent()
                  }
                  event.accepted = true
                }
              }
            }
          }

          Rectangle {
            width: parent.width
            height: 1
            color: Util.alpha(root.foreground, 0.10)
          }

          Item {
            width: parent.width
            height: popup.height - searchHeader.height - Style.spacing.xxs - 1

            Text {
              anchors.centerIn: parent
              visible: resultList.count === 0
              text: root.emptyText
              color: Qt.darker(root.foreground, 1.6)
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            ListView {
              id: resultList
              anchors.fill: parent
              spacing: Style.spacing.labelGap
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              model: root.filtered
              currentIndex: -1
              keyNavigationEnabled: false

              function selectCurrent() {
                if (currentIndex < 0 || currentIndex >= root.filtered.length) return
                var v = root.optionValue(root.filtered[currentIndex])
                root.value = v
                root.changed(v)
                popup.close()
              }

              Keys.priority: Keys.BeforeItem
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  popup.close(); event.accepted = true
                } else if (event.key === Qt.Key_Down || event.text === "j") {
                  if (resultList.currentIndex >= resultList.count - 1) {
                    event.accepted = true; return
                  }
                  resultList.currentIndex = resultList.currentIndex + 1
                  event.accepted = true
                } else if (event.key === Qt.Key_Up || event.text === "k") {
                  if (resultList.currentIndex <= 0) {
                    searchField.forceActiveFocus()
                    event.accepted = true; return
                  }
                  resultList.currentIndex = resultList.currentIndex - 1
                  event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  resultList.selectCurrent(); event.accepted = true
                }
              }

              delegate: Rectangle {
                required property var modelData
                required property int index
                width: resultList.width
                height: Math.max(root.popupRowHeight, rowContent.implicitHeight + Style.spacing.rowPaddingX)
                color: index === resultList.currentIndex
                  ? Style.hoverFillFor(root.foreground, root.accent)
                  : "transparent"

                Column {
                  id: rowContent
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.spacing.controlPaddingX
                  anchors.rightMargin: Style.spacing.controlPaddingX
                  spacing: Style.spacing.xxs

                  Text {
                    text: root.optionLabel(modelData)
                    color: index === resultList.currentIndex ? Style.hoverStateColor(root.foreground, root.accent) : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                    width: parent.width
                  }
                  Text {
                    visible: text !== ""
                    text: root.optionDescription(modelData)
                    color: Qt.darker(root.foreground, 1.5)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    width: parent.width
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onPositionChanged: resultList.currentIndex = parent.index
                  onClicked: resultList.selectCurrent()
                }
              }
            }
          }
        }
      }
    }
  }
}
