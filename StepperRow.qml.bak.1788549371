import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Duration stepper with direct numeric entry and -/+ buttons.
Row {
  id: root

  property int value: 25
  property int minValue: 1
  property int maxValue: 1440
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  signal step(int delta)
  signal valueCommitted(int newValue)

  spacing: Style.space(4)

  PanelActionButton {
    iconText: "−"
    foreground: root.foreground
    fontFamily: root.fontFamily
    onClicked: root.step(-1)
  }

  Rectangle {
    width: Style.space(54)
    height: Style.space(26)
    radius: Math.max(2, Style.cornerRadius - 2)
    color: numInput.activeFocus
      ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
      : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
    border.width: 1
    border.color: numInput.activeFocus
      ? Color.accent
      : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)

    TextInput {
      id: numInput
      anchors.fill: parent
      anchors.margins: 2
      horizontalAlignment: TextInput.AlignHCenter
      verticalAlignment: TextInput.AlignVCenter
      text: String(root.value)
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      selectByMouse: true
      activeFocusOnPress: true

      validator: IntValidator {
        bottom: root.minValue
        top: root.maxValue
      }

      onTextEdited: {
        var n = parseInt(text, 10)
        if (!isNaN(n) && n >= root.minValue && n <= root.maxValue) {
          root.valueCommitted(n)
        }
      }

      onEditingFinished: {
        var n = parseInt(text, 10)
        if (isNaN(n) || n < root.minValue) n = root.minValue
        if (n > root.maxValue) n = root.maxValue
        text = String(n)
        root.valueCommitted(n)
      }

      onAccepted: {
        numInput.focus = false
      }

      Connections {
        target: root
        function onValueChanged() {
          if (!numInput.activeFocus) numInput.text = String(root.value)
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.IBeamCursor
      onClicked: {
        numInput.forceActiveFocus()
        numInput.selectAll()
      }
    }
  }

  PanelActionButton {
    iconText: "+"
    foreground: root.foreground
    fontFamily: root.fontFamily
    onClicked: root.step(1)
  }
}
