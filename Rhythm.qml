pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import "Model.js" as Model

Rectangle {
  id: root
  property var svc: null
  property color accent: Color.accent
  radius: Style.cornerRadius; color: Style.normalFillFor(Color.popups.text, Color.accent); border.width: 1; border.color: Util.alpha(Color.popups.text, 0.15)
  readonly property var days: {
    var sessions = svc ? svc.sessions : [], now = new Date(svc ? svc._now : Date.now()), result = []
    for (var i=6; i>=0; i--) {
      var d = new Date(now.getFullYear(), now.getMonth(), now.getDate()-i), key = Model.dateKey(d)
      result.push({label: Qt.formatDate(d,"ddd").toUpperCase(), count: sessions.filter(function(s){ return s === key }).length, today: i === 0})
    }
    return result
  }
  readonly property int maxCount: Math.max(1, ...days.map(function(d){return d.count}))
  Row {
    anchors.fill: parent; anchors.margins: 14; spacing: 10
    Column {
      width: Math.min(150, parent.width*0.28); spacing: 4
      Text { text: "THIS WEEK"; color: Util.alpha(Color.popups.text, 0.65); font.family: Style.font.family; font.pixelSize: 9; font.letterSpacing: 1.7 }
      Text { text: root.svc ? String(root.svc.countWeek) : "0"; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: 26 }
      Text { text: "sessions"; color: Util.alpha(Color.popups.text, 0.65); font.family: Style.font.family; font.pixelSize: 10 }
    }
    Row {
      width: parent.width - parent.children[0].width - parent.spacing
      height: parent.height; spacing: 9
      Repeater {
        model: root.days
        Column {
          required property var modelData
          width: (parent.width-54)/7; height: parent.height; spacing: 7
          Item {
            width: parent.width; height: parent.height - 21
            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: Math.max(3, (parent.height-16)*modelData.count/root.maxCount)
              radius: 3
              color: modelData.today ? root.accent : Util.alpha(root.accent, 0.5)
              opacity: modelData.count ? 1 : 0.28
              Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 0; text: modelData.count || "·"; color: modelData.today ? root.accent : Util.alpha(Color.popups.text, 0.65); font.family: Style.font.family; font.pixelSize: 9 }
          }
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: modelData.today ? root.accent : Util.alpha(Color.popups.text, 0.65); font.family: Style.font.family; font.pixelSize: 8; font.letterSpacing: 0.5 }
        }
      }
    }
  }
}
