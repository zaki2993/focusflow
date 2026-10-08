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
  readonly property int total: days.reduce(function(sum, d){ return sum + d.count }, 0)
  Row {
    anchors.fill: parent; anchors.margins: 14; spacing: 10
    Column {
      width: Math.min(150, parent.width*0.28); spacing: 4
      Text { text: "LAST 7 DAYS"; color: Util.alpha(Color.popups.text, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption; font.letterSpacing: 1.2 }
      Text { text: String(root.total); color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.display }
      Text { text: root.total === 1 ? "session" : "sessions"; color: Util.alpha(Color.popups.text, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption }
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
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 0; text: modelData.count || "·"; color: modelData.today ? root.accent : Util.alpha(Color.popups.text, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption }
          }
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: modelData.today ? root.accent : Util.alpha(Color.popups.text, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption; font.letterSpacing: 0.3 }
        }
      }
    }
  }
}
