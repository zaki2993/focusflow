import QtQuick
import QtQuick.Controls as Controls
import qs.Commons

// Borderless button. `primary` fills with the accent; `quiet` has no fill until
// hovered; `selected` marks the active choice in a group. A ring appears only
// for keyboard focus.
Rectangle {
  id: root
  property string text: ""
  property string icon: ""
  property string hint: ""
  property bool primary: false
  property bool selected: false
  property bool quiet: false
  property color accent: Color.accent
  property color foreground: Color.popups.text
  property int fontSize: Style.font.body
  readonly property bool hot: mouse.containsMouse || activeFocus
  function contrastColor(c) {
    var r = c.r <= 0.04045 ? c.r/12.92 : Math.pow((c.r+0.055)/1.055,2.4)
    var g = c.g <= 0.04045 ? c.g/12.92 : Math.pow((c.g+0.055)/1.055,2.4)
    var b = c.b <= 0.04045 ? c.b/12.92 : Math.pow((c.b+0.055)/1.055,2.4)
    return r*0.2126+g*0.7152+b*0.0722 > 0.179 ? "#000000" : "#ffffff"
  }
  readonly property color primaryTextColor: root.contrastColor(root.accent)
  readonly property color inkColor: primary ? primaryTextColor
                                  : selected || hot || !quiet ? foreground
                                  : Util.alpha(foreground, 0.7)
  signal clicked()
  implicitWidth: content.implicitWidth + (text !== "" ? 22 : 12)
  implicitHeight: Math.max(30, Style.font.body + 16)
  radius: Math.min(8, Style.cornerRadius)
  color: primary ? (hot ? Qt.lighter(accent, 1.1) : accent)
       : mouse.pressed ? Style.selectedFillFor(foreground, accent)
       : hot ? Style.hoverFillFor(foreground, accent)
       : selected ? Style.selectedFillFor(foreground, accent)
       : quiet ? "transparent" : Style.normalFillFor(foreground, accent)
  border.width: activeFocus ? 2 : 0
  border.color: accent
  opacity: enabled ? 1 : 0.35
  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: hint || text
  Keys.onSpacePressed: clicked()
  Keys.onReturnPressed: clicked()
  Behavior on color { ColorAnimation { duration: 120 } }
  Row {
    id: content
    anchors.centerIn: parent
    spacing: 7
    Text {
      visible: root.icon !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.icon; color: root.inkColor
      font.family: Style.font.family; font.pixelSize: Math.round(root.fontSize * 1.25)
    }
    Text {
      visible: root.text !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.text; textFormat: Text.PlainText; color: root.inkColor
      font.family: Style.font.family; font.pixelSize: root.fontSize
      font.weight: root.primary || root.selected ? Font.DemiBold : Font.Normal
    }
  }
  MouseArea {
    id: mouse
    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
  Controls.ToolTip {
    visible: mouse.containsMouse && root.hint !== "" && root.hint !== root.text
    delay: 650; text: root.hint
    contentItem: Text { text: root.hint; color: Color.tooltip.text; font.family: Style.font.family; font.pixelSize: Style.font.caption }
    background: Rectangle { color: Color.tooltip.background; radius: Style.cornerRadius; border.width: 1; border.color: Color.tooltip.border }
  }
}
