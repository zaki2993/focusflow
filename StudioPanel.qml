pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "zakarch.focusflow"
  ipcTarget: "zakarch.focusflow.panel"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var svc: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property color fg: Color.popups.text
  readonly property color accent: Color.accent
  property int activeTab: 0   // 0 Focus · 1 Tasks · 2 Settings
  property string settingsPage: "general"   // "general" | "shield" | "activity"
  property bool confirmListReset: false
  property string blockerFeedback: ""
  readonly property string heroTime: !svc ? "25:00" : svc.phase === "idle" ? Model.formatRemaining(svc.focusMinutes*60000) : svc.displayTime
  readonly property string phaseLabel: !svc || svc.phase === "idle" ? "READY" : !svc.running ? "PAUSED" : svc.phase === "break" ? "BREAK" : "FOCUS"
  readonly property real progress: svc && svc.phase !== "idle" ? Math.max(0,Math.min(1,svc.elapsedSeconds/svc.totalSeconds)) : 0
  readonly property var settingsPages: [{id: "general", label: "General"}, {id: "shield", label: "Shield"}, {id: "activity", label: "Activity"}]
  readonly property var timerPresets: [{focus: 25, rest: 5}, {focus: 50, rest: 10}, {focus: 90, rest: 20}]
  readonly property var shieldActions: [{id: "notify", label: "Notify"}, {id: "switch", label: "Switch away"}, {id: "close", label: "Close"}]
  readonly property var shieldHints: ({
    notify: "Only sends a notification when a blocked site opens.",
    switch: "Jumps back to your previous workspace when a blocked site is focused.",
    close: "Closes matching windows. Unsaved work in them is lost."
  })
  onActiveTabChanged: scroller.contentY = 0
  onSettingsPageChanged: { scroller.contentY = 0; confirmListReset = false }
  function showSettings(section) {
    activeTab = 2
    settingsPage = section === "shield" ? "shield" : section === "activity" ? "activity" : "general"
    scroller.contentY = 0
  }
  function cycleSettingsPage(direction) {
    var i = 0
    for (var n = 0; n < settingsPages.length; n++) if (settingsPages[n].id === settingsPage) i = n
    settingsPage = settingsPages[(i + direction + settingsPages.length) % settingsPages.length].id
  }
  function primaryAction() {
    if (!svc) return
    if (svc.phase === "idle") svc.startFocus()
    else if (svc.running) svc.pause()
    else svc.resume()
  }
  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function") return bar.switchPanelFrom(barIdentity,direction)
    return false
  }
  function addDomain() {
    if (svc && svc.addBlockedWebApp(domainInput.text)) { domainInput.clear(); blockerFeedback = "" }
    else blockerFeedback = "Enter a valid domain, e.g. youtube.com."
  }
  component Copy: Text {
    color: root.fg; font.family: Style.font.family; font.pixelSize: Style.font.body; textFormat: Text.PlainText
  }
  component Caption: Copy { color: Util.alpha(root.fg,0.65); font.pixelSize: Style.font.caption }
  // A whole-row toggle: label, optional description, native switch on the right.
  component SwitchRow: Item {
    id: sw
    property string label: ""
    property string description: ""
    property bool checked: false
    signal toggled()
    height: Math.max(36, textCol.implicitHeight + 12)
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checked: checked
    Keys.onSpacePressed: toggled()
    Keys.onReturnPressed: toggled()
    Rectangle {
      anchors.fill: parent; radius: Math.min(8, Style.cornerRadius)
      color: sw.activeFocus ? Style.focusFillFor(root.fg, root.accent) : rowMouse.containsMouse ? Style.hoverFillFor(root.fg, root.accent) : "transparent"
      border.width: sw.activeFocus ? 2 : 0; border.color: root.accent
      Behavior on color { ColorAnimation { duration: 130 } }
    }
    Column {
      id: textCol
      anchors.left: parent.left; anchors.leftMargin: 8; anchors.right: knob.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
      spacing: 1
      Copy { width: parent.width; text: sw.label; elide: Text.ElideRight }
      Caption { visible: sw.description !== ""; width: parent.width; text: sw.description; wrapMode: Text.WordWrap }
    }
    ToggleSwitch {
      id: knob
      anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
      checked: sw.checked; interactive: false; cursorRing: false
      foreground: root.fg; accent: root.accent
    }
    MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled() }
  }
  component Stepper: Item {
    id: step
    property string label: ""
    property string unit: "min"
    property int value: 25
    property int minimum: 1
    property int maximum: 1440
    property int increment: 1
    signal picked(int next)
    height: 38
    Copy { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: step.label; width: parent.width-controls.width-20; elide: Text.ElideRight }
    Row {
      id: controls; anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 4
      StudioButton { width: 28; height: 28; text: "−"; hint: "Decrease " + step.label; enabled: step.value > step.minimum; onClicked: step.picked(Math.max(step.minimum,step.value-step.increment)) }
      Copy { width: 74; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignHCenter; text: step.value + " " + step.unit; font.weight: Font.DemiBold }
      StudioButton { width: 28; height: 28; text: "+"; hint: "Increase " + step.label; enabled: step.value < step.maximum; onClicked: step.picked(Math.min(step.maximum,step.value+step.increment)) }
    }
  }
  // Pick-one row of equal-width buttons.
  component Segmented: Row {
    id: seg
    property var options: []
    property string value: ""
    signal picked(string id)
    spacing: 4
    Repeater {
      model: seg.options
      StudioButton {
        required property var modelData
        width: (seg.width - seg.spacing * (seg.options.length - 1)) / seg.options.length
        height: 28; text: modelData.label; selected: seg.value === modelData.id
        onClicked: seg.picked(modelData.id)
      }
    }
  }
  component SectionLabel: Text {
    color: Util.alpha(root.fg, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption
    font.bold: true; font.letterSpacing: 1.2; textFormat: Text.PlainText; topPadding: 4
  }
  component Stat: Rectangle {
    id: stat
    property string label: ""
    property string value: "0"
    height: 52; radius: Math.min(8, Style.cornerRadius)
    color: Style.normalFillFor(root.fg, root.accent); border.width: 1; border.color: Util.alpha(root.fg, 0.15)
    Column {
      anchors.centerIn: parent; spacing: 1
      Copy { anchors.horizontalCenter: parent.horizontalCenter; text: stat.value; font.pixelSize: Style.font.title; font.weight: Font.DemiBold }
      Caption { anchors.horizontalCenter: parent.horizontalCenter; text: stat.label }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem; owner: root.barIdentity; bar: root.bar; open: root.opened
    centerOnBar: false; padding: 14
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(360)
    contentHeight: panel.fittedContentHeight(main.implicitHeight, root.activeTab === 0 ? 420 : root.activeTab === 1 ? 450 : 520)
    PanelKeyCatcher {
      id: keyCatcher; anchors.fill: parent; blocked: !activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(d) { var next = nextItemInFocusChain(d > 0); if (next) next.forceActiveFocus(Qt.TabFocusReason) }
      onActivateRequested: if (root.activeTab === 0) root.primaryAction()
      onMoveRequested: function(dx,dy) {
        if (dx && root.activeTab >= 2) root.cycleSettingsPage(dx > 0 ? 1 : -1)
        else if (dx) root.activeTab = root.activeTab === 0 ? 1 : 0
        else scroller.contentY = Math.max(0,Math.min(scroller.contentHeight-scroller.height,scroller.contentY+dy*40))
      }
      onTextKey: function(t) {
        if (t === "1") root.activeTab = 0
        else if (t === "2") root.activeTab = 1
        else if (t === "3") root.activeTab = 2
        else if (t.toLowerCase() === "s" || t.toLowerCase() === "p") root.primaryAction()
        else if (t.toLowerCase() === "r" && root.svc) root.svc.reset()
      }
      // Esc in a text field first leaves the field (cancelling a task edit);
      // a second Esc closes the panel.
      Shortcut {
        sequence: "Escape"; enabled: root.opened
        onActivated: {
          var f = keyCatcher.Window.activeFocusItem
          if (f && f !== keyCatcher && f.cursorPosition !== undefined) {
            taskQueue.cancelEdit()
            keyCatcher.forceActiveFocus()
          } else root.close()
        }
      }
      Flickable {
        id: scroller; anchors.fill: parent; clip: true
        contentWidth: width; contentHeight: main.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: Controls.ScrollBar {}
        Column {
          id: main; width: scroller.width; spacing: 12
          Item {
            width: parent.width; height: 25
            Copy { anchors.verticalCenter: parent.verticalCenter; text: "◎ FocusFlow"; font.pixelSize: Style.font.title; font.weight: Font.DemiBold }
            StudioButton { anchors.right: parent.right; text: root.activeTab >= 2 ? "Back" : "Settings"; width: 82; height: 25; quiet: true; hint: "Settings"; onClicked: { root.activeTab = root.activeTab >= 2 ? 0 : 2; keyCatcher.forceActiveFocus() } }
          }
          Row {
            visible: root.activeTab < 2; width: parent.width; spacing: 6
            StudioButton { width: (parent.width-6)/2; height: 29; text: "Focus"; selected: root.activeTab === 0; quiet: true; onClicked: { root.activeTab = 0; keyCatcher.forceActiveFocus() } }
            StudioButton { width: (parent.width-6)/2; height: 29; text: "Tasks" + (root.svc ? " · " + root.svc.openCount : ""); selected: root.activeTab === 1; quiet: true; onClicked: { root.activeTab = 1; keyCatcher.forceActiveFocus() } }
          }
          Column {
            visible: root.activeTab === 0; width: parent.width; spacing: 10
            OrbitDial { anchors.horizontalCenter: parent.horizontalCenter; width: Math.min(parent.width,186); height: width; timeText: root.heroTime; phaseText: root.phaseLabel; progress: root.progress; running: root.svc && root.svc.running; animate: root.opened && root.activeTab === 0 }
            Row {
              width: parent.width; spacing: 6
              StudioButton { id: startButton; width: parent.width-40; height: 36; primary: true; enabled: !!root.svc; text: !root.svc || root.svc.phase === "idle" ? "Start focus" : root.svc.running ? "Pause" : "Resume"; onClicked: root.primaryAction() }
              StudioButton { width: 34; height: 36; text: "󰑓"; hint: "Reset session"; onClicked: if (root.svc) root.svc.reset() }
            }
            Rectangle {
              width: parent.width; height: 38; radius: Math.min(8,Style.cornerRadius)
              color: Style.normalFillFor(root.fg, root.accent)
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activeTab = 1 }
              Copy { x: 11; anchors.verticalCenter: parent.verticalCenter; width: parent.width-44; elide: Text.ElideRight; text: root.svc && root.svc.activeTask ? root.svc.activeTask.title : "Choose a task →"; font.strikeout: root.svc && root.svc.activeTask && root.svc.activeTask.done }
              StudioButton { anchors.right: parent.right; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter; width: 27; height: 27; quiet: true; text: "✓"; visible: root.svc && !!root.svc.activeTask; hint: "Complete linked task"; onClicked: root.svc.toggleTask(root.svc.activeTaskId) }
            }
            Item {
              width: parent.width; height: 22
              Row {
                id: goalRow
                anchors.verticalCenter: parent.verticalCenter; spacing: 8
                // One pip per session toward the daily goal (capped so it never crowds the row).
                Row {
                  anchors.verticalCenter: parent.verticalCenter; spacing: 4
                  visible: !!root.svc && root.svc.dailyGoal <= 12
                  Repeater {
                    model: root.svc ? Math.min(12, root.svc.dailyGoal) : 0
                    Rectangle {
                      required property int index
                      width: 7; height: 7; radius: 3.5
                      color: root.svc && index < root.svc.countToday ? root.accent : "transparent"
                      border.width: 1; border.color: root.svc && index < root.svc.countToday ? root.accent : Util.alpha(root.fg, 0.35)
                    }
                  }
                }
                Caption { anchors.verticalCenter: parent.verticalCenter; text: root.svc ? root.svc.countToday + " / " + root.svc.dailyGoal + " today" : "Connecting…" }
              }
              StudioButton { anchors.right: parent.right; text: "Break"; height: 22; quiet: true; hint: "Start a break"; onClicked: if (root.svc) root.svc.startBreak() }
            }
          }
          Column {
            visible: root.activeTab === 1; width: parent.width; spacing: 10
            Caption { text: "Click a task to focus on it.  ⋯ for more."; width: parent.width; wrapMode: Text.WordWrap }
            TaskQueue { id: taskQueue; width: parent.width; height: 313; svc: root.svc }
          }
          Column {
            visible: root.activeTab >= 2; width: parent.width; spacing: 10
            Segmented { width: parent.width; options: root.settingsPages; value: root.settingsPage; onPicked: function(id) { root.settingsPage = id } }

            // ── General: timer, automation, alerts ──
            Column {
              visible: root.settingsPage === "general"; width: parent.width; spacing: 2
              SectionLabel { text: "TIMER" }
              Row {
                width: parent.width; spacing: 4
                Repeater {
                  model: root.timerPresets
                  StudioButton {
                    required property var modelData
                    width: (parent.width - 8) / 3; height: 28
                    text: modelData.focus + " / " + modelData.rest
                    hint: modelData.focus + " min focus, " + modelData.rest + " min break"
                    selected: !!root.svc && root.svc.focusMinutes === modelData.focus && root.svc.breakMinutes === modelData.rest
                    onClicked: if (root.svc) { root.svc.focusMinutes = modelData.focus; root.svc.breakMinutes = modelData.rest }
                  }
                }
              }
              Stepper { width: parent.width; label: "Focus length"; value: root.svc ? root.svc.focusMinutes : 25; increment: 5; onPicked: function(next) { if (root.svc) root.svc.focusMinutes = next } }
              Stepper { width: parent.width; label: "Break length"; value: root.svc ? root.svc.breakMinutes : 5; onPicked: function(next) { if (root.svc) root.svc.breakMinutes = next } }
              Stepper { width: parent.width; label: "Daily goal"; unit: "sessions"; maximum: 30; value: root.svc ? root.svc.dailyGoal : 4; onPicked: function(next) { if (root.svc) root.svc.dailyGoal = next } }
              Caption { leftPadding: 8; width: parent.width; text: "Length changes apply to the next session."; wrapMode: Text.WordWrap }

              SectionLabel { topPadding: 14; text: "AUTOMATION" }
              SwitchRow { width: parent.width; label: "Auto-start breaks"; description: "Begin the break as soon as focus ends."; checked: !!root.svc && root.svc.autoStartBreak; onToggled: if (root.svc) root.svc.autoStartBreak = !root.svc.autoStartBreak }
              SwitchRow { width: parent.width; label: "Auto-start focus"; description: "Begin the next focus session when a break ends."; checked: !!root.svc && root.svc.autoStartFocus; onToggled: if (root.svc) root.svc.autoStartFocus = !root.svc.autoStartFocus }

              SectionLabel { topPadding: 14; text: "ALERTS" }
              Segmented {
                width: parent.width
                options: [{id: "notification", label: "Notification"}, {id: "overlay", label: "Full-screen"}]
                value: root.svc ? root.svc.reminderMode : "notification"
                onPicked: function(id) { if (root.svc) root.svc.reminderMode = id }
              }
              SwitchRow { width: parent.width; label: "Session sounds"; description: "Chime when a session ends or a site is blocked."; checked: !!root.svc && root.svc.soundAlert; onToggled: if (root.svc) root.svc.soundAlert = !root.svc.soundAlert }
              SwitchRow { width: parent.width; label: "Task sounds"; description: "Play a sound when you tick a task."; checked: !!root.svc && root.svc.taskSoundAlert; onToggled: if (root.svc) root.svc.taskSoundAlert = !root.svc.taskSoundAlert }
            }

            // ── Shield: distraction blocking ──
            Column {
              visible: root.settingsPage === "shield"; width: parent.width; spacing: 2
              Timer { running: root.confirmListReset; interval: 4000; onTriggered: root.confirmListReset = false }
              SwitchRow { width: parent.width; label: "Distraction shield"; description: "Watches browser and web app windows during focus."; checked: !!root.svc && root.svc.blockerEnabled; onToggled: if (root.svc) root.svc.blockerEnabled = !root.svc.blockerEnabled }
              Caption { visible: !!root.svc && root.svc.blockedCountToday > 0; leftPadding: 8; width: parent.width; text: "Blocked " + (root.svc ? root.svc.blockedCountToday : 0) + " time" + (root.svc && root.svc.blockedCountToday === 1 ? "" : "s") + " today." }
              Column {
                width: parent.width; spacing: 2
                enabled: !!root.svc && root.svc.blockerEnabled
                opacity: enabled ? 1 : 0.4
                Behavior on opacity { NumberAnimation { duration: 130 } }

                SectionLabel { topPadding: 12; text: "WHEN A BLOCKED SITE APPEARS" }
                Segmented { width: parent.width; options: root.shieldActions; value: root.svc ? root.svc.blockerAction : "close"; onPicked: function(id) { if (root.svc) root.svc.blockerAction = id } }
                Caption {
                  leftPadding: 8; width: parent.width; wrapMode: Text.WordWrap
                  text: root.shieldHints[root.svc ? root.svc.blockerAction : "close"] || ""
                  color: root.svc && root.svc.blockerAction === "close" ? Color.urgent : Util.alpha(root.fg, 0.65)
                }
                SwitchRow { width: parent.width; label: "Scan when focus starts"; description: "Also handles windows that are already open."; checked: !!root.svc && root.svc.blockerScanOnStart; onToggled: if (root.svc) root.svc.blockerScanOnStart = !root.svc.blockerScanOnStart }

                SectionLabel { topPadding: 12; text: "BLOCKED WEBSITES" + (root.svc ? "  ·  " + root.svc.activeBlockedCount + " ACTIVE" : "") }
                Row {
                  width: parent.width; spacing: 5
                  StudioInput { id: domainInput; width: parent.width-39; placeholderText: "Add a domain, e.g. youtube.com"; onAccepted: root.addDomain() }
                  StudioButton { text: "+"; width: 34; height: domainInput.height; primary: true; hint: "Add blocked website"; onClicked: root.addDomain() }
                }
                Caption { visible: root.blockerFeedback !== ""; text: root.blockerFeedback; color: Color.urgent; width: parent.width; wrapMode: Text.WordWrap }
                Caption { visible: !!root.svc && root.svc.blockedWebApps.length === 0; leftPadding: 8; width: parent.width; wrapMode: Text.WordWrap; text: "Nothing blocked yet. Add a domain above or pick one below." }
                ListView {
                  id: blockedList; width: parent.width; clip: true; spacing: 3
                  visible: count > 0
                  height: Math.min(150, count * 35)
                  model: root.svc ? root.svc.blockedWebApps : []; boundsBehavior: Flickable.StopAtBounds
                  Controls.ScrollBar.vertical: Controls.ScrollBar {}
                  delegate: Item {
                    id: blockedRow; required property var modelData
                    width: blockedList.width; height: 32
                    Copy { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; width: parent.width-90; text: blockedRow.modelData.domain; elide: Text.ElideRight; opacity: blockedRow.modelData.enabled ? 1 : 0.5 }
                    Row {
                      anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                      ToggleSwitch { anchors.verticalCenter: parent.verticalCenter; trackHeight: 20; cursorRing: false; foreground: root.fg; accent: root.accent; checked: blockedRow.modelData.enabled; onToggled: if (root.svc) root.svc.toggleBlockedWebApp(blockedRow.modelData.id) }
                      StudioButton { text: "×"; width: 26; height: 26; quiet: true; hint: "Remove " + blockedRow.modelData.domain; onClicked: if (root.svc) root.svc.removeBlockedWebApp(blockedRow.modelData.id) }
                    }
                  }
                }

                SectionLabel { topPadding: 12; text: "QUICK ADD"; visible: presetRepeater.count > 0 }
                Flow {
                  width: parent.width; spacing: 4
                  Repeater {
                    id: presetRepeater
                    // Only presets that are not on the list yet.
                    model: {
                      var listed = root.svc ? root.svc.blockedWebApps.map(function(a) { return a.domain }) : []
                      return Model.presetWebApps().filter(function(p) { return listed.indexOf(p.domain) === -1 })
                    }
                    StudioButton { required property var modelData; text: "+ " + modelData.name; height: 26; quiet: true; onClicked: if (root.svc) root.svc.addPresetWebApp(modelData.id) }
                  }
                }
                StudioButton {
                  width: parent.width; height: 28; quiet: true
                  text: root.confirmListReset ? "Click again to replace the list with defaults" : "Restore default list"
                  onClicked: { if (root.confirmListReset) { if (root.svc) root.svc.resetBlockedWebAppsToDefault(); root.confirmListReset = false } else root.confirmListReset = true }
                }
              }
            }

            // ── Activity: real completed sessions ──
            Column {
              visible: root.settingsPage === "activity"; width: parent.width; spacing: 8
              Row {
                width: parent.width; spacing: 6
                Stat { width: (parent.width - 18) / 4; label: "Today"; value: root.svc ? root.svc.countToday + "/" + root.svc.dailyGoal : "0" }
                Stat { width: (parent.width - 18) / 4; label: "Week"; value: root.svc ? String(root.svc.countWeek) : "0" }
                Stat { width: (parent.width - 18) / 4; label: "Month"; value: root.svc ? String(root.svc.countMonth) : "0" }
                Stat { width: (parent.width - 18) / 4; label: "Blocked"; value: root.svc ? String(root.svc.blockedCountToday) : "0" }
              }
              Rhythm { width: parent.width; height: 90; svc: root.svc }
              Caption { width: parent.width; wrapMode: Text.WordWrap; text: "Counts completed focus sessions only. Empty days stay empty." }
            }
          }
        }
      }
    }
  }
}
