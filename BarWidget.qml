import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Focus Flow bar widget.
// Displays live focus/break timers or open task count during idle.
// Left-click → toggle panel. Middle-click → pause/resume. Right-click → reset.
BarWidget {
  id: root
  moduleName: "zakarch.focusflow"

  readonly property var svc: bar && bar.shell ? bar.shell.serviceFor("zakarch.focusflow") : null

  // ── Icon & Text formatting ────────────────────────────────────────────────
  function barText() {
    if (!svc) return "󰏫"
    
    // Timer only when in focus phase
    if (svc.phase === "focus") {
      var icon = svc.running ? "󱎫" : "󰏤"
      return icon + " " + Model.formatRemaining(svc.remaining)
    }
    
    // Timer only when in break phase
    if (svc.phase === "break") {
      return "󰅶 " + Model.formatRemaining(svc.remaining)
    }

    // Idle phase: show ONLY open tasks count (clean & compact)
    return "󰏫 " + svc.openCount
  }

  function tooltipText() {
    if (!svc) return "Focus Flow"
    var lines = ["Focus Flow"]
    if (svc.phase !== "idle") {
      var state = svc.phase === "focus" ? "󱎫 Focus" : "󰅶 Break"
      if (svc.running) state += " · " + Model.formatRemaining(svc.remaining)
      else state += " · Paused"
      lines.push(state)
      if (svc.activeTask) {
        var prioTag = svc.activeTask.priority ? ("[" + Model.priorityLabel(svc.activeTask.priority) + "] ") : ""
        lines.push("Active Task: " + prioTag + svc.activeTask.title)
      }
    }
    var focusTimeText = svc.totalFocusMinutesToday > 0 ? (" · " + Model.formatMinutes(svc.totalFocusMinutesToday) + " focused") : ""
    lines.push("Today: " + svc.countToday + " sessions" + focusTimeText + " · " + svc.openCount + " open tasks")
    return lines.join("\n")
  }

  // ── Panel Integration ─────────────────────────────────────────────────────
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  function open()         { if (panelLoader.item) panelLoader.item.open() }
  function close()        { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel()  { if (panelLoader.item) panelLoader.item.toggle() }

  readonly property real openPanelIndicatorWidth:  button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var t = panelLoader.item
    if (!t) return
    if ("bar"        in t) t.bar        = root.bar
    if ("settings"   in t) t.settings   = root.settings
    if ("anchorItem" in t) t.anchorItem = button
    if ("hostWidget" in t) t.hostWidget = root
  }

  implicitWidth:  button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged:      injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  IpcHandler {
    target: "zakarch.focusflow.widget"
    function open(): void   { root.open() }
    function close(): void  { root.close() }
    function toggle(): void { root.togglePanel() }
    function setTab(tab: string): void {
      if (panelLoader.item) {
        var n = parseInt(tab, 10)
        if (!isNaN(n)) panelLoader.item.activeTab = n
      }
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barText()
    fontSize: Style.bar.iconFont
    horizontalMargin: 6
    verticalPadding: 5
    tooltipText: root.tooltipText()

    onPressed: function(b) {
      if (!root.svc) return
      if (b === Qt.RightButton) root.svc.reset()
      else if (b === Qt.MiddleButton) {
        if (root.svc.running) root.svc.pause()
        else root.svc.resume()
      } else {
        root.togglePanel()
      }
    }
  }
}
