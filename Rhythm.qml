pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import "Model.js" as Model

// Finished focus sessions for each of the last seven days.
Item {
  id: root
  property var svc: null
  property color accent: Color.accent
  readonly property color fg: Color.popups.text
  readonly property var days: {
    var sessions = svc ? svc.sessions : [], now = new Date(svc ? svc._now : Date.now()), result = []
    for (var i = 6; i >= 0; i--) {
      var d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i), key = Model.dateKey(d)
      result.push({ label: Qt.formatDate(d, "ddd").slice(0, 2), count: sessions.filter(function(s) { return s === key }).length, today: i === 0 })
    }
    return result
  }
  readonly property int maxCount: Math.max(1, ...days.map(function(d) { return d.count }))
  readonly property int total: days.reduce(function(sum, d) { return sum + d.count }, 0)

  Column {
    id: summary
    anchors.left: parent.left; anchors.leftMargin: 2; anchors.bottom: parent.bottom
    width: 92; spacing: 0
    Text { text: String(root.total); color: root.fg; font.family: Style.font.family; font.pixelSize: Style.font.display; font.weight: Font.Light }
    Text { text: (root.total === 1 ? "session" : "sessions") + "\nlast 7 days"; color: Util.alpha(root.fg, 0.55); font.family: Style.font.family; font.pixelSize: Style.font.caption; lineHeight: 1.15 }
  }

  Row {
    anchors.left: summary.right; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
    spacing: 6
    Repeater {
      model: root.days
      Column {
        id: day
        required property var modelData
        width: (parent.width - 6 * 6) / 7; height: parent.height; spacing: 6
        Item {
          width: parent.width; height: parent.height - dayLabel.height - parent.spacing
          Rectangle {
            id: bar
            anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, 14)
            height: day.modelData.count ? Math.max(6, (parent.height - 18) * day.modelData.count / root.maxCount) : 3
            radius: Math.min(4, width / 2)
            color: day.modelData.count === 0 ? Util.alpha(root.fg, 0.15) : day.modelData.today ? root.accent : Util.alpha(root.accent, 0.5)
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: bar.top; anchors.bottomMargin: 3
            visible: day.modelData.count > 0
            text: day.modelData.count; color: day.modelData.today ? root.accent : Util.alpha(root.fg, 0.6)
            font.family: Style.font.family; font.pixelSize: Style.font.caption
          }
        }
        Text {
          id: dayLabel
          anchors.horizontalCenter: parent.horizontalCenter
          text: day.modelData.label
          color: day.modelData.today ? root.accent : Util.alpha(root.fg, 0.5)
          font.family: Style.font.family; font.pixelSize: Style.font.caption
          font.weight: day.modelData.today ? Font.DemiBold : Font.Normal
        }
      }
    }
  }
}
