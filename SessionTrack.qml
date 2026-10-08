pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons

// Today's sessions as a row of blocks: one per session toward the daily goal.
// Finished sessions are solid; the running focus session fills as time passes.
Item {
  id: root
  property int goal: 4
  property int done: 0
  property string phase: "idle"   // "idle" | "focus" | "break"
  property bool running: false
  property real progress: 0
  property color accent: Color.accent
  property color foreground: Color.popups.text

  readonly property int maxBlocks: 12
  readonly property bool inFocus: phase === "focus"
  readonly property int count: Math.min(maxBlocks, Math.max(goal, done + (inFocus ? 1 : 0)))
  readonly property real gap: count > 8 ? 4 : 6

  implicitHeight: 8
  Accessible.role: Accessible.ProgressBar
  Accessible.name: done + " of " + goal + " sessions today"

  Row {
    anchors.fill: parent
    spacing: root.gap
    Repeater {
      model: root.count
      Rectangle {
        id: block
        required property int index
        readonly property bool finished: index < root.done
        readonly property bool current: root.inFocus && index === root.done
        width: (root.width - root.gap * (root.count - 1)) / root.count
        height: root.height
        radius: height / 2
        color: finished ? root.accent : Util.alpha(root.foreground, 0.13)

        Rectangle {
          visible: block.current
          height: parent.height
          radius: parent.radius
          width: Math.max(parent.height, parent.width * root.progress)
          color: root.running ? root.accent : Util.alpha(root.accent, 0.55)
          Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
        }
      }
    }
  }
}
