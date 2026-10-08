pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import "Model.js" as Model

Item {
  id: root
  property var svc: null
  property string filter: "open"
  property string priority: "medium"
  property bool optionsOpen: false
  property bool ranked: true
  property string expandedId: ""
  property string editingId: ""
  readonly property color fg: Color.popups.text
  readonly property var taskModel: {
    var all = svc ? svc.tasks : []
    var list = all.filter(function(t) { return root.filter === "done" ? t.done : !t.done })
    return root.ranked ? list.slice().sort(function(a,b) { return Model.priorityWeight(b.priority)-Model.priorityWeight(a.priority) }) : list
  }
  // Leaves edit mode without saving (Esc).
  function cancelEdit() { editingId = "" }
  function submit() {
    if (svc && svc.addTask(taskInput.text, optionsOpen ? priority : undefined)) taskInput.clear()
  }
  Column {
    id: tools
    width: parent.width; spacing: 8
    Row {
      width: parent.width; spacing: 6
      StudioInput { id: taskInput; width: parent.width-addButton.width-6; placeholderText: "Add a task…"; onAccepted: root.submit() }
      StudioButton { id: addButton; text: "+"; width: 34; height: taskInput.height; primary: true; hint: "Add task"; onClicked: root.submit() }
    }
    Item {
      width: parent.width; height: 28
      Row {
        spacing: 5
        StudioButton { text: "To do"; selected: root.filter === "open"; height: 28; onClicked: root.filter = "open" }
        StudioButton { text: "Done"; selected: root.filter === "done"; height: 28; onClicked: root.filter = "done" }
      }
      StudioButton { anchors.right: parent.right; text: "Options"; quiet: true; selected: root.optionsOpen; height: 28; onClicked: root.optionsOpen = !root.optionsOpen }
    }
    Column {
      visible: root.optionsOpen; width: parent.width; spacing: 6
      Row {
        spacing: 5
        Repeater {
          model: ["low","medium","high"]
          StudioButton { required property string modelData; text: Model.priorityLabel(modelData); selected: root.priority === modelData; height: 26; hint: "Priority for new tasks"; onClicked: root.priority = modelData }
        }
      }
      StudioButton { text: root.ranked ? "Sort: priority" : "Sort: newest"; quiet: true; height: 26; onClicked: root.ranked = !root.ranked }
    }
  }
  ListView {
    id: list
    y: tools.implicitHeight + 10
    width: parent.width
    height: Math.max(60, root.height-y-(root.filter === "done" ? 32 : 0))
    model: root.taskModel; clip: true; spacing: 6
    boundsBehavior: Flickable.StopAtBounds
    Controls.ScrollBar.vertical: Controls.ScrollBar {}
    delegate: Rectangle {
      id: taskRow
      required property var modelData
      readonly property bool linked: root.svc && root.svc.activeTaskId === String(modelData.id)
      readonly property bool expanded: root.expandedId === String(modelData.id)
      width: list.width; height: expanded ? 91 : 48
      radius: Math.min(8,Style.cornerRadius)
      color: linked ? Style.selectedFillFor(root.fg,Color.accent) : hover.hovered ? Style.hoverFillFor(root.fg,Color.accent) : Style.normalFillFor(root.fg,Color.accent)
      border.width: linked ? 1 : 0; border.color: Color.accent
      HoverHandler { id: hover }
      // Priority marker: urgent colour for high, accent for medium, faint for low.
      Rectangle {
        x: 3; anchors.verticalCenter: parent.top; anchors.verticalCenterOffset: 24
        width: 3; height: 18; radius: 1.5
        readonly property string prio: Model.validPriority(taskRow.modelData.priority)
        color: prio === "high" ? Color.urgent : prio === "medium" ? Util.alpha(Color.accent, 0.7) : Util.alpha(root.fg, 0.25)
        opacity: taskRow.modelData.done ? 0.4 : 1
      }
      StudioButton {
        x: 9; y: 12; width: 23; height: 23
        text: taskRow.modelData.done ? "✓" : ""
        primary: taskRow.modelData.done
        hint: taskRow.modelData.done ? "Reopen task" : "Complete task"
        onClicked: if (root.svc) root.svc.toggleTask(taskRow.modelData.id)
      }
      Text {
        x: 41; anchors.top: parent.top; anchors.topMargin: 14; width: parent.width-83-(pomoLabel.visible ? pomoLabel.implicitWidth+8 : 0)
        visible: root.editingId !== String(taskRow.modelData.id)
        text: taskRow.modelData.title; textFormat: Text.PlainText; elide: Text.ElideRight
        color: taskRow.modelData.done ? Util.alpha(root.fg,0.65) : root.fg
        font.family: Style.font.family; font.pixelSize: Style.font.body; font.strikeout: taskRow.modelData.done
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.svc) root.svc.setActiveTask(taskRow.modelData.id) }
      }
      Text {
        id: pomoLabel
        anchors.right: parent.right; anchors.rightMargin: 40; anchors.top: parent.top; anchors.topMargin: 15
        visible: (taskRow.modelData.pomos || 0) > 0 && root.editingId !== String(taskRow.modelData.id)
        text: "󰔛 " + (taskRow.modelData.pomos || 0)
        color: Util.alpha(root.fg, 0.6); font.family: Style.font.family; font.pixelSize: Style.font.caption
        Controls.ToolTip.visible: pomoHover.hovered; Controls.ToolTip.delay: 650
        Controls.ToolTip.text: (taskRow.modelData.pomos || 0) + " focus session" + ((taskRow.modelData.pomos || 0) === 1 ? "" : "s")
        HoverHandler { id: pomoHover }
      }
      StudioInput {
        id: edit
        x: 38; y: 7; width: parent.width-83; height: 32
        visible: root.editingId === String(taskRow.modelData.id)
        text: taskRow.modelData.title
        function commit() {
          if (root.svc && text.trim()) root.svc.editTask(taskRow.modelData.id,text)
          root.editingId = ""
        }
        onAccepted: commit()
        onEditingFinished: if (visible) commit()
        Keys.onEscapePressed: root.editingId = ""
      }
      StudioButton {
        anchors.right: parent.right; anchors.rightMargin: 6; y: 10; width: 29; height: 28
        text: taskRow.linked ? "◎" : "⋯"; quiet: true
        hint: "Task options"; onClicked: root.expandedId = taskRow.expanded ? "" : String(taskRow.modelData.id)
      }
      Row {
        x: 9; y: 52; spacing: 4; visible: taskRow.expanded
        StudioButton { text: Model.priorityLabel(taskRow.modelData.priority); height: 27; hint: "Change priority"; onClicked: if (root.svc) root.svc.cycleTaskPriority(taskRow.modelData.id) }
        StudioButton { text: "Edit"; height: 27; onClicked: { root.editingId = String(taskRow.modelData.id); edit.forceActiveFocus(); edit.selectAll() } }
        StudioButton { text: taskRow.linked ? "Unlink" : "Focus"; height: 27; onClicked: if (root.svc) root.svc.setActiveTask(taskRow.modelData.id) }
        StudioButton { text: "×"; width: 27; height: 27; hint: "Delete task"; onClicked: if (root.svc) root.svc.removeTask(taskRow.modelData.id) }
      }
    }
    Text {
      anchors.centerIn: parent; width: parent.width-24; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
      visible: list.count === 0
      text: root.filter === "done" ? "Completed tasks appear here." : "Add one thing to focus on."
      color: Util.alpha(root.fg,0.65); font.family: Style.font.family; font.pixelSize: Style.font.body
    }
  }
  StudioButton { anchors.bottom: parent.bottom; text: "Clear completed"; height: 27; quiet: true; visible: root.filter === "done"; onClicked: if (root.svc) root.svc.clearCompletedTasks() }
}
