import QtQuick
import qs.Commons
import qs.Ui as Ui

Ui.TextField {
  height: Math.max(34, Style.font.body + 18)
  foreground: Color.popups.text
  accent: Color.accent
  font.family: Style.font.family
  font.pixelSize: Style.font.body
  placeholderTextColor: Util.alpha(foreground, 0.6)
}
