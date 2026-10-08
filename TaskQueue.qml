pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons

// Plain task list, newest first. Click a row to link it to the timer (or ▶ to
// link and start). Finished tasks stay in place, struck through, until deleted.
Column {
  id: root
  property var svc: null
  property string editingId: ""
  property int visibleRows: 6
  readonly property color fg: Color.popups.text
  readonly property int rowHeight: 36
  readonly property int doneCount: svc ? svc.tasks.length - svc.openCount : 0
  readonly property var taskModel: svc ? svc.tasks : []
  spacing: 6

  // Leaves edit mode without saving (Esc).
  function cancelEdit() { editingId = "" }
  function focusInput() { taskInput.forceActiveFocus() }
  // Link the task and get the timer going on it.
  function focusNow(id) {
    if (!svc) return
    if (svc.activeTaskId !== String(id)) svc.setActiveTask(id)
    if (svc.phase !== "focus") svc.startFocus()
    else if (!svc.running) svc.resume()
  }
  function submit() {
    if (svc && svc.addTask(taskInput.text)) taskInput.clear()
  }
  // Black or white, whichever reads better on the accent fill.
  readonly property color tickInk: {
    var c = Color.accent
    function lin(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    return lin(c.r) * 0.2126 + lin(c.g) * 0.7152 + lin(c.b) * 0.0722 > 0.179 ? "#000000" : "#ffffff"
  }

  Item {
    width: parent.width; height: 26
    Text {
      anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
      text: "Tasks"; color: root.fg; textFormat: Text.PlainText
      font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.weight: Font.DemiBold
    }
    StudioButton {
      anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      height: 26; quiet: true; fontSize: Style.font.caption
      visible: root.doneCount > 0
      text: "Clear " + root.doneCount + " done"
      hint: "Delete all finished tasks"
      onClicked: if (root.svc) root.svc.clearCompletedTasks()
    }
  }

  ListView {
    id: list
    width: parent.width
    height: Math.min(count, root.visibleRows) * root.rowHeight + Math.max(0, Math.min(count, root.visibleRows) - 1) * spacing
    visible: count > 0
    model: root.taskModel; clip: true; spacing: 2
    interactive: count > root.visibleRows
    boundsBehavior: Flickable.StopAtBounds
    Controls.ScrollBar.vertical: Controls.ScrollBar { policy: list.interactive ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff }
    delegate: Item {
      id: row
      required property var modelData
      readonly property string taskId: String(modelData.id)
      readonly property bool done: modelData.done === true
      readonly property bool linked: !!root.svc && root.svc.activeTaskId === taskId
      readonly property bool editing: root.editingId === taskId
      readonly property bool active: hover.hovered || check.activeFocus || focusButton.activeFocus || editButton.activeFocus || deleteButton.activeFocus
      readonly property int pomos: modelData.pomos || 0
      width: list.width; height: root.rowHeight

      HoverHandler { id: hover }
      Rectangle {
        anchors.fill: parent; radius: Math.min(8, Style.cornerRadius)
        color: row.editing ? "transparent"
             : row.active ? Style.hoverFillFor(root.fg, Color.accent)
             : row.linked && !row.done ? Util.alpha(Color.accent, 0.12)
             : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
      }
      // The whole row links / unlinks the task; the ring and buttons sit above it.
      MouseArea {
        id: rowMouse
        anchors.fill: parent; enabled: !row.done && !row.editing
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.svc) root.svc.setActiveTask(row.taskId)
      }

      // Completion ring.
      Rectangle {
        id: check
        x: 8; anchors.verticalCenter: parent.verticalCenter
        width: 18; height: 18; radius: 9
        color: row.done ? Color.accent : "transparent"
        border.width: row.done ? 0 : (activeFocus ? 2.5 : 1.5)
        border.color: activeFocus ? Color.accent : Util.alpha(root.fg, 0.55)
        activeFocusOnTab: true
        Accessible.role: Accessible.CheckBox
        Accessible.name: row.modelData.title
        Accessible.checked: row.done
        Keys.onSpacePressed: if (root.svc) root.svc.toggleTask(row.taskId)
        Keys.onReturnPressed: if (root.svc && !row.done) root.svc.setActiveTask(row.taskId)
        // The task linked to the timer carries an accent dot.
        Rectangle {
          anchors.centerIn: parent; visible: row.linked && !row.done
          width: 8; height: 8; radius: 4; color: Color.accent
        }
        Text {
          anchors.centerIn: parent; visible: row.done
          text: "󰄬"; color: root.tickInk
          font.family: Style.font.family; font.pixelSize: 12
        }
        MouseArea {
          anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
          onClicked: if (root.svc) root.svc.toggleTask(row.taskId)
        }
      }

      Text {
        id: title
        anchors.left: check.right; anchors.leftMargin: 12
        anchors.right: row.active ? actions.left : (row.pomos > 0 ? pomoLabel.left : parent.right)
        anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
        visible: !row.editing
        text: row.modelData.title; textFormat: Text.PlainText; elide: Text.ElideRight
        color: row.done ? Util.alpha(root.fg, 0.45) : root.fg
        font.family: Style.font.family; font.pixelSize: Style.font.body
        font.weight: row.linked ? Font.DemiBold : Font.Normal
        font.strikeout: row.done
      }

      Text {
        id: pomoLabel
        anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
        visible: row.pomos > 0 && !row.active && !row.editing
        text: "󰔛 " + row.pomos
        color: Util.alpha(root.fg, 0.5); font.family: Style.font.family; font.pixelSize: Style.font.caption
      }

      Row {
        id: actions
        anchors.right: parent.right; anchors.rightMargin: 3; anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        opacity: row.active && !row.editing ? 1 : 0
        visible: !row.editing
        Behavior on opacity { NumberAnimation { duration: 120 } }
        StudioButton {
          id: focusButton
          width: 28; height: 28; quiet: true; icon: "󰐊"; hint: "Focus on this task now"
          foreground: Color.accent
          visible: !row.done && !(row.linked && !!root.svc && root.svc.phase === "focus" && root.svc.running)
          onClicked: root.focusNow(row.taskId)
        }
        StudioButton {
          id: editButton
          width: 28; height: 28; quiet: true; icon: "󰏫"; hint: "Rename"
          onClicked: { root.editingId = row.taskId; edit.text = row.modelData.title; edit.forceActiveFocus(); edit.selectAll() }
        }
        StudioButton {
          id: deleteButton
          width: 28; height: 28; quiet: true; icon: "󰆴"; hint: "Delete"
          onClicked: if (root.svc) root.svc.removeTask(row.taskId)
        }
      }

      StudioInput {
        id: edit
        anchors.left: check.right; anchors.leftMargin: 6; anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter; height: 32
        visible: row.editing
        function commit() {
          if (root.svc && text.trim()) root.svc.editTask(row.taskId, text)
          root.editingId = ""
        }
        onAccepted: commit()
        onEditingFinished: if (visible) commit()
      }
    }
  }

  Text {
    width: parent.width; visible: list.count === 0
    leftPadding: 2; topPadding: 2; bottomPadding: 4
    text: "Add the one thing you want to work on."
    wrapMode: Text.WordWrap; textFormat: Text.PlainText
    color: Util.alpha(root.fg, 0.55); font.family: Style.font.family; font.pixelSize: Style.font.body
  }

  StudioInput {
    id: taskInput
    width: parent.width
    placeholderText: "Add a task"
    onAccepted: root.submit()
  }
}
