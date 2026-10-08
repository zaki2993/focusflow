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
  readonly property color hairline: Util.alpha(fg, 0.1)
  property int activeTab: 0   // 0 Timer and tasks · 2 Settings (1 is kept for old IPC callers)
  property string settingsPage: "general"   // "general" | "shield" | "activity"
  property bool confirmListReset: false
  property string blockerFeedback: ""
  readonly property bool idle: !svc || svc.phase === "idle"
  readonly property string heroTime: !svc ? "25:00" : idle ? Model.formatRemaining(svc.focusMinutes * 60000) : svc.displayTime
  readonly property string phaseLabel: idle ? "Ready" : !svc.running ? "Paused" : svc.phase === "break" ? "Break" : "Focus"
  readonly property real progress: svc && !idle ? Math.max(0, Math.min(1, svc.elapsedSeconds / svc.totalSeconds)) : 0
  readonly property var settingsPages: [{id: "general", label: "General"}, {id: "shield", label: "Shield"}, {id: "activity", label: "Activity"}]
  readonly property var timerPresets: [{focus: 25, rest: 5}, {focus: 50, rest: 10}, {focus: 90, rest: 20}]
  readonly property var shieldActions: [{id: "notify", label: "Notify"}, {id: "switch", label: "Switch away"}, {id: "close", label: "Close"}]
  readonly property var shieldHints: ({
    notify: "Sends one reminder per window when a blocked site opens.",
    switch: "Jumps back to your previous workspace when a blocked site is focused.",
    close: "Closes the whole browser window, including its other tabs."
  })
  onActiveTabChanged: {
    if (activeTab === 1) { activeTab = 0; Qt.callLater(taskQueue.focusInput); return }
    scroller.contentY = 0
  }
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
  function addDomain() {
    if (svc && svc.addBlockedWebApp(domainInput.text)) { domainInput.clear(); blockerFeedback = "" }
    else blockerFeedback = "Enter a domain like youtube.com."
  }

  component Copy: Text {
    color: root.fg; font.family: Style.font.family; font.pixelSize: Style.font.body; textFormat: Text.PlainText
  }
  component Caption: Copy { color: Util.alpha(root.fg, 0.55); font.pixelSize: Style.font.caption }
  component Gap: Item { width: 1 }
  component SectionLabel: Copy {
    color: Util.alpha(root.fg, 0.55); font.pixelSize: Style.font.bodySmall; font.weight: Font.DemiBold
    leftPadding: 8; topPadding: 16; bottomPadding: 4
  }
  // A whole-row toggle: label, optional description, native switch on the right.
  component SwitchRow: Item {
    id: sw
    property string label: ""
    property string description: ""
    property bool checked: false
    signal toggled()
    height: Math.max(38, textCol.implicitHeight + 14)
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checked: checked
    Keys.onSpacePressed: toggled()
    Keys.onReturnPressed: toggled()
    Rectangle {
      anchors.fill: parent; radius: Math.min(8, Style.cornerRadius)
      color: sw.activeFocus || rowMouse.containsMouse ? Style.hoverFillFor(root.fg, root.accent) : "transparent"
      border.width: sw.activeFocus ? 2 : 0; border.color: root.accent
      Behavior on color { ColorAnimation { duration: 120 } }
    }
    Column {
      id: textCol
      anchors.left: parent.left; anchors.leftMargin: 8; anchors.right: knob.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
      spacing: 2
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
    Copy { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: step.label; width: parent.width - controls.width - 20; elide: Text.ElideRight }
    Row {
      id: controls; anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter; spacing: 2
      StudioButton { width: 30; height: 30; quiet: true; text: "−"; hint: "Decrease " + step.label.toLowerCase(); enabled: step.value > step.minimum; onClicked: step.picked(Math.max(step.minimum, step.value - step.increment)) }
      Copy { width: 82; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignHCenter; text: step.value + " " + step.unit; font.weight: Font.DemiBold }
      StudioButton { width: 30; height: 30; quiet: true; text: "+"; hint: "Increase " + step.label.toLowerCase(); enabled: step.value < step.maximum; onClicked: step.picked(Math.min(step.maximum, step.value + step.increment)) }
    }
  }
  // Pick-one group on a shared track; the chosen option is filled.
  component Segmented: Rectangle {
    id: seg
    property var options: []
    property string value: ""
    signal picked(string id)
    height: 34; radius: Math.min(9, Style.cornerRadius + 1)
    color: Style.normalFillFor(root.fg, root.accent)
    Row {
      anchors.fill: parent; anchors.margins: 2; spacing: 2
      Repeater {
        model: seg.options
        StudioButton {
          required property var modelData
          width: (seg.width - 4 - 2 * (seg.options.length - 1)) / seg.options.length
          height: 30; quiet: true; text: modelData.label; selected: seg.value === modelData.id
          hint: modelData.hint || ""
          onClicked: seg.picked(modelData.id)
        }
      }
    }
  }
  component Stat: Column {
    id: stat
    property string label: ""
    property string value: "0"
    spacing: 0
    Copy { text: stat.value; font.pixelSize: Style.font.display; font.weight: Font.Light }
    Caption { text: stat.label }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem; owner: root.barIdentity; bar: root.bar; open: root.opened
    centerOnBar: false; padding: 18
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(344)
    contentHeight: panel.fittedContentHeight(main.implicitHeight, 600)
    PanelKeyCatcher {
      id: keyCatcher; anchors.fill: parent; blocked: !activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(d) { var next = nextItemInFocusChain(d > 0); if (next) next.forceActiveFocus(Qt.TabFocusReason) }
      onActivateRequested: if (root.activeTab === 0) root.primaryAction()
      onMoveRequested: function(dx, dy) {
        if (dx && root.activeTab === 2) root.cycleSettingsPage(dx > 0 ? 1 : -1)
        else if (dy) scroller.contentY = Math.max(0, Math.min(scroller.contentHeight - scroller.height, scroller.contentY + dy * 40))
      }
      onTextKey: function(t) {
        var k = t.toLowerCase()
        if (k === "1") root.activeTab = 0
        else if (k === "2") { root.activeTab = 0; taskQueue.focusInput() }
        else if (k === "3") root.activeTab = 2
        else if (root.activeTab === 0 && (k === "s" || k === "p")) root.primaryAction()
        else if (root.activeTab === 0 && k === "r" && root.svc) root.svc.reset()
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
          } else if (root.activeTab === 2) root.activeTab = 0
          else root.close()
        }
      }
      Flickable {
        id: scroller; anchors.fill: parent; clip: true
        contentWidth: width; contentHeight: main.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: Controls.ScrollBar {}
        Column {
          id: main; width: scroller.width; spacing: 0

          // ── Timer and tasks ──
          Column {
            visible: root.activeTab !== 2; width: parent.width; spacing: 0
            Item {
              width: parent.width; height: 28
              Copy {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                text: root.phaseLabel; font.pixelSize: Style.font.subtitle
                color: !root.idle && root.svc.running ? root.accent : Util.alpha(root.fg, 0.6)
              }
              StudioButton {
                anchors.right: parent.right; anchors.rightMargin: -6; anchors.verticalCenter: parent.verticalCenter
                width: 30; height: 30; quiet: true; icon: "󰒓"; hint: "Settings"
                onClicked: { root.activeTab = 2; keyCatcher.forceActiveFocus() }
              }
            }
            Copy {
              id: hero
              x: -3
              text: root.heroTime
              font.pixelSize: Math.round(Style.font.baseSize * (root.heroTime.length > 5 ? 4.4 : 5.4))
              font.weight: Font.Light; font.letterSpacing: -2
              color: root.svc && root.svc.phase !== "idle" && !root.svc.running ? Util.alpha(root.fg, 0.55) : root.fg
              Behavior on color { ColorAnimation { duration: 200 } }
            }
            Gap { height: 4 }
            SessionTrack {
              width: parent.width; height: 8
              goal: root.svc ? root.svc.dailyGoal : 4
              done: root.svc ? root.svc.countToday : 0
              phase: root.svc ? root.svc.phase : "idle"
              running: !!root.svc && root.svc.running
              progress: root.progress
            }
            Gap { height: 10 }
            Item {
              width: parent.width; height: 18
              Copy {
                anchors.left: parent.left; anchors.right: countLabel.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight; font.pixelSize: Style.font.bodySmall
                readonly property var task: root.svc ? root.svc.activeTask : null
                text: task ? task.title : root.svc && root.svc.openCount > 0 ? "Click a task below to focus on it" : "Add a task below to focus on it"
                color: task ? Util.alpha(root.fg, 0.85) : Util.alpha(root.fg, 0.45)
                font.strikeout: !!task && task.done
              }
              Caption {
                id: countLabel
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: root.svc ? root.svc.countToday + " of " + root.svc.dailyGoal + " today" : ""
              }
            }
            Gap { height: 18 }
            Item {
              width: parent.width; height: 38
              Row {
                spacing: 4
                StudioButton {
                  id: startButton
                  width: 148; height: 38; primary: true; enabled: !!root.svc
                  icon: !root.svc || root.svc.phase === "idle" || !root.svc.running ? "󰐊" : "󰏤"
                  text: !root.svc || root.svc.phase === "idle" ? "Start focus" : root.svc.running ? "Pause" : "Resume"
                  onClicked: root.primaryAction()
                }
                StudioButton {
                  width: 38; height: 38; quiet: true; icon: "󰑓"; hint: "Reset session"
                  visible: !root.idle
                  onClicked: if (root.svc) root.svc.reset()
                }
              }
              StudioButton {
                anchors.right: parent.right; anchors.rightMargin: -6; anchors.verticalCenter: parent.verticalCenter
                height: 34; quiet: true
                readonly property bool onBreak: !!root.svc && root.svc.phase === "break"
                icon: onBreak ? "󰒭" : "󰅶"
                text: onBreak ? "Skip break" : "Break"
                hint: onBreak ? "End the break and start focusing" : "Start a " + (root.svc ? root.svc.breakMinutes : 5) + " minute break"
                onClicked: if (root.svc) { if (onBreak) root.svc.skipToNext(); else root.svc.startBreak() }
              }
            }
            Gap { height: 20 }
            Rectangle { width: parent.width; height: 1; color: root.hairline }
            Gap { height: 14 }
            TaskQueue { id: taskQueue; width: parent.width; svc: root.svc }
          }

          // ── Settings ──
          Column {
            visible: root.activeTab === 2; width: parent.width; spacing: 0
            Item {
              width: parent.width; height: 30
              StudioButton {
                id: backButton
                anchors.left: parent.left; anchors.leftMargin: -6; anchors.verticalCenter: parent.verticalCenter
                height: 30; quiet: true; icon: "󰁍"; text: "Settings"; fontSize: Style.font.subtitle; hint: "Back to timer"
                onClicked: { root.activeTab = 0; keyCatcher.forceActiveFocus() }
              }
            }
            Gap { height: 8 }
            // Page tabs: plain words, the current one underlined in the accent.
            Row {
              spacing: 18; leftPadding: 2
              Repeater {
                model: root.settingsPages
                Item {
                  id: pageTab
                  required property var modelData
                  readonly property bool current: root.settingsPage === modelData.id
                  width: pageLabel.implicitWidth; height: 28
                  activeFocusOnTab: true
                  Accessible.role: Accessible.PageTab
                  Accessible.name: modelData.label
                  Keys.onSpacePressed: root.settingsPage = modelData.id
                  Keys.onReturnPressed: root.settingsPage = modelData.id
                  Copy {
                    id: pageLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: pageTab.modelData.label
                    color: pageTab.current || tabMouse.containsMouse || pageTab.activeFocus ? root.fg : Util.alpha(root.fg, 0.5)
                    font.weight: pageTab.current ? Font.DemiBold : Font.Normal
                  }
                  Rectangle {
                    anchors.bottom: parent.bottom; width: parent.width; height: 2; radius: 1
                    color: pageTab.current ? root.accent : pageTab.activeFocus ? Util.alpha(root.accent, 0.5) : "transparent"
                  }
                  MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.settingsPage = pageTab.modelData.id }
                }
              }
            }
            Rectangle { width: parent.width; height: 1; color: root.hairline }

            // General: timer, automation, alerts
            Column {
              visible: root.settingsPage === "general"; width: parent.width; spacing: 2
              SectionLabel { text: "Timer" }
              Segmented {
                width: parent.width
                options: root.timerPresets.map(function(p) { return { id: p.focus + "/" + p.rest, label: p.focus + " / " + p.rest, hint: p.focus + " min focus, " + p.rest + " min break" } })
                value: root.svc ? root.svc.focusMinutes + "/" + root.svc.breakMinutes : ""
                onPicked: function(id) { if (root.svc) { var p = id.split("/"); root.svc.focusMinutes = parseInt(p[0], 10); root.svc.breakMinutes = parseInt(p[1], 10) } }
              }
              Gap { height: 4 }
              Stepper { width: parent.width; label: "Focus"; value: root.svc ? root.svc.focusMinutes : 25; increment: 5; onPicked: function(next) { if (root.svc) root.svc.focusMinutes = next } }
              Stepper { width: parent.width; label: "Break"; value: root.svc ? root.svc.breakMinutes : 5; onPicked: function(next) { if (root.svc) root.svc.breakMinutes = next } }
              Stepper { width: parent.width; label: "Daily goal"; unit: "sessions"; maximum: 30; value: root.svc ? root.svc.dailyGoal : 4; onPicked: function(next) { if (root.svc) root.svc.dailyGoal = next } }
              Caption { leftPadding: 8; width: parent.width; text: "New lengths apply from the next session."; wrapMode: Text.WordWrap }

              SectionLabel { text: "Automation" }
              SwitchRow { width: parent.width; label: "Start breaks automatically"; checked: !!root.svc && root.svc.autoStartBreak; onToggled: if (root.svc) root.svc.autoStartBreak = !root.svc.autoStartBreak }
              SwitchRow { width: parent.width; label: "Start focus after a break"; checked: !!root.svc && root.svc.autoStartFocus; onToggled: if (root.svc) root.svc.autoStartFocus = !root.svc.autoStartFocus }

              SectionLabel { text: "When a session ends" }
              Segmented {
                width: parent.width
                options: [{id: "notification", label: "Notification"}, {id: "overlay", label: "Full screen"}]
                value: root.svc ? root.svc.reminderMode : "notification"
                onPicked: function(id) { if (root.svc) root.svc.reminderMode = id }
              }
              Gap { height: 4 }
              SwitchRow { width: parent.width; label: "Session sounds"; description: "When a session ends or a site is blocked"; checked: !!root.svc && root.svc.soundAlert; onToggled: if (root.svc) root.svc.soundAlert = !root.svc.soundAlert }
              SwitchRow { width: parent.width; label: "Task sound"; description: "When you complete a task"; checked: !!root.svc && root.svc.taskSoundAlert; onToggled: if (root.svc) root.svc.taskSoundAlert = !root.svc.taskSoundAlert }
            }

            // Shield: distraction blocking
            Column {
              visible: root.settingsPage === "shield"; width: parent.width; spacing: 2
              Timer { running: root.confirmListReset; interval: 4000; onTriggered: root.confirmListReset = false }
              Gap { height: 10 }
              SwitchRow {
                width: parent.width; label: "Distraction shield"
                description: !root.svc ? "" : root.svc.blockedCountToday > 0
                  ? "Caught " + root.svc.blockedCountToday + " distraction" + (root.svc.blockedCountToday === 1 ? "" : "s") + " today"
                  : "Watches browser windows during focus"
                checked: !!root.svc && root.svc.blockerEnabled
                onToggled: if (root.svc) root.svc.blockerEnabled = !root.svc.blockerEnabled
              }
              Column {
                width: parent.width; spacing: 2
                enabled: !!root.svc && root.svc.blockerEnabled
                opacity: enabled ? 1 : 0.4
                Behavior on opacity { NumberAnimation { duration: 120 } }

                SectionLabel { text: "When a blocked site appears" }
                Segmented { width: parent.width; options: root.shieldActions; value: root.svc ? root.svc.blockerAction : "notify"; onPicked: function(id) { if (root.svc) root.svc.blockerAction = id } }
                Caption {
                  leftPadding: 8; topPadding: 4; width: parent.width; wrapMode: Text.WordWrap
                  text: root.shieldHints[root.svc ? root.svc.blockerAction : "notify"] || ""
                  color: root.svc && root.svc.blockerAction === "close" ? Color.urgent : Util.alpha(root.fg, 0.55)
                }
                Gap { height: 4 }
                SwitchRow { width: parent.width; label: "Check open windows on start"; description: "Not just ones opened during focus"; checked: !!root.svc && root.svc.blockerScanOnStart; onToggled: if (root.svc) root.svc.blockerScanOnStart = !root.svc.blockerScanOnStart }

                SectionLabel { text: "Blocked sites" + (root.svc && root.svc.blockedWebApps.length > 0 ? " (" + root.svc.activeBlockedCount + " on)" : "") }
                Row {
                  width: parent.width; spacing: 4
                  StudioInput { id: domainInput; width: parent.width - addDomainButton.width - 4; placeholderText: "youtube.com"; onAccepted: root.addDomain() }
                  StudioButton { id: addDomainButton; text: "Add"; height: domainInput.height; onClicked: root.addDomain() }
                }
                Caption { visible: root.blockerFeedback !== ""; leftPadding: 8; topPadding: 2; text: root.blockerFeedback; color: Color.urgent; width: parent.width; wrapMode: Text.WordWrap }
                Caption { visible: !!root.svc && root.svc.blockedWebApps.length === 0; leftPadding: 8; topPadding: 4; width: parent.width; wrapMode: Text.WordWrap; text: "Nothing blocked yet. Add a domain or pick one below." }
                Gap { height: 4 }
                ListView {
                  id: blockedList; width: parent.width; clip: true; spacing: 0
                  visible: count > 0
                  height: Math.min(5, count) * 36
                  interactive: count > 5
                  model: root.svc ? root.svc.blockedWebApps : []; boundsBehavior: Flickable.StopAtBounds
                  Controls.ScrollBar.vertical: Controls.ScrollBar {}
                  delegate: Item {
                    id: blockedRow; required property var modelData
                    width: blockedList.width; height: 36
                    HoverHandler { id: blockedHover }
                    Rectangle { anchors.fill: parent; radius: Math.min(8, Style.cornerRadius); color: blockedHover.hovered ? Style.hoverFillFor(root.fg, root.accent) : "transparent" }
                    Copy { anchors.left: parent.left; anchors.leftMargin: 8; anchors.right: blockedControls.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: blockedRow.modelData.domain; elide: Text.ElideRight; opacity: blockedRow.modelData.enabled ? 1 : 0.45 }
                    Row {
                      id: blockedControls
                      anchors.right: parent.right; anchors.rightMargin: 2; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                      StudioButton { anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; quiet: true; icon: "󰆴"; hint: "Remove " + blockedRow.modelData.domain; opacity: blockedHover.hovered || activeFocus ? 1 : 0; onClicked: if (root.svc) root.svc.removeBlockedWebApp(blockedRow.modelData.id) }
                      ToggleSwitch { anchors.verticalCenter: parent.verticalCenter; trackHeight: 20; cursorRing: false; foreground: root.fg; accent: root.accent; checked: blockedRow.modelData.enabled; onToggled: if (root.svc) root.svc.toggleBlockedWebApp(blockedRow.modelData.id) }
                      Gap { height: 1; width: 4 }
                    }
                  }
                }
                Flow {
                  width: parent.width; spacing: 4; topPadding: 8
                  visible: presetRepeater.count > 0
                  Repeater {
                    id: presetRepeater
                    // Only presets that are not on the list yet.
                    model: {
                      var listed = root.svc ? root.svc.blockedWebApps.map(function(a) { return a.domain }) : []
                      return Model.presetWebApps().filter(function(p) { return listed.indexOf(p.domain) === -1 })
                    }
                    StudioButton { required property var modelData; text: "+ " + modelData.name; height: 28; fontSize: Style.font.bodySmall; onClicked: if (root.svc) root.svc.addPresetWebApp(modelData.id) }
                  }
                }
                Gap { height: 8 }
                StudioButton {
                  height: 28; quiet: true; fontSize: Style.font.bodySmall
                  text: root.confirmListReset ? "Click again to replace your list" : "Restore default list"
                  foreground: root.confirmListReset ? Color.urgent : root.fg
                  onClicked: { if (root.confirmListReset) { if (root.svc) root.svc.resetBlockedWebAppsToDefault(); root.confirmListReset = false } else root.confirmListReset = true }
                }
              }
            }

            // Activity: real completed sessions
            Column {
              visible: root.settingsPage === "activity"; width: parent.width; spacing: 0
              Gap { height: 16 }
              Row {
                width: parent.width; leftPadding: 2
                Stat { width: (parent.width - 2) / 4; label: "today"; value: root.svc ? String(root.svc.countToday) : "0" }
                Stat { width: (parent.width - 2) / 4; label: "week"; value: root.svc ? String(root.svc.countWeek) : "0" }
                Stat { width: (parent.width - 2) / 4; label: "month"; value: root.svc ? String(root.svc.countMonth) : "0" }
                Stat { width: (parent.width - 2) / 4; label: "blocked"; value: root.svc ? String(root.svc.blockedCountToday) : "0" }
              }
              Gap { height: 22 }
              Rhythm { width: parent.width; height: 84; svc: root.svc }
              Gap { height: 12 }
              Caption {
                leftPadding: 2; width: parent.width; wrapMode: Text.WordWrap
                text: root.svc && root.svc.totalFocusMinutesToday > 0
                  ? Model.formatMinutes(root.svc.totalFocusMinutesToday) + " focused today. Only finished focus sessions count."
                  : "Only finished focus sessions count."
              }
            }
          }
        }
      }
    }
  }
}
