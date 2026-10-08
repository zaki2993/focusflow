import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// FocusFlow bar widget.
// Shows the running timer, or the open task count while idle.
// Left-click → toggle panel. Middle-click → pause/resume. Right-click → reset.
BarWidget {
  id: root
  moduleName: "zakarch.focusflow"

  readonly property var svc: bar && bar.shell ? bar.shell.serviceFor("zakarch.focusflow") : null

  // ── Icon & Text formatting ────────────────────────────────────────────────
  function barText() {
    if (!svc) return ""
    if (svc.phase !== "idle") return Model.formatRemaining(svc.remaining)
    return svc.openCount > 0 ? String(svc.openCount) : ""
  }

  function tooltipText() {
    if (!svc) return "FocusFlow"
    var lines = ["FocusFlow"]
    if (svc.phase !== "idle") {
      var state = svc.phase === "focus" ? "󱫠 Focus" : "󰅶 Break"
      if (svc.running) state += " · " + Model.formatRemaining(svc.remaining)
      else state += " · Paused"
      lines.push(state)
      if (svc.activeTask) {
        var prioTag = svc.activeTask.priority ? ("[" + Model.priorityLabel(svc.activeTask.priority) + "] ") : ""
        lines.push("Task: " + prioTag + svc.activeTask.title)
      }
    }
    var focusTimeText = svc.totalFocusMinutesToday > 0 ? (" · " + Model.formatMinutes(svc.totalFocusMinutesToday) + " focused") : ""
    lines.push("Today: " + svc.countToday + "/" + svc.dailyGoal + " sessions" + focusTimeText + " · " + svc.openCount + " open tasks")
    lines.push("Middle-click: pause/resume · Right-click: reset")
    return lines.join("\n")
  }

  // ── Panel Integration ─────────────────────────────────────────────────────
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  function open()         { if (panelLoader.item) panelLoader.item.open() }
  function close()        { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel()  { if (panelLoader.item) panelLoader.item.toggle() }

  readonly property real openPanelIndicatorWidth:  content.implicitWidth
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
    source: Qt.resolvedUrl("StudioPanel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  IpcHandler {
    target: "zakarch.focusflow.widget"
    function open(): void   { root.open() }
    function close(): void  { root.close() }
    function toggle(): void { root.togglePanel() }
    function settings(section: string): void { if (panelLoader.item) panelLoader.item.showSettings(section) }
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
    labelVisible: false
    hasVisualContent: true
    implicitWidth: vertical ? barSize : content.implicitWidth + Style.spaceReal(12)
    implicitHeight: barSize
    fontSize: Style.bar.iconFont
    tooltipText: root.tooltipText()

    Row {
      id: content
      anchors.centerIn: parent
      spacing: Style.space(5)

      Canvas {
        id: logo
        width: Style.bar.iconCanvas
        height: width
        antialiasing: true
        readonly property color ink: button.foreground
        readonly property bool paused: root.svc && root.svc.phase !== "idle" && !root.svc.running
        readonly property real progress: root.svc && root.svc.phase !== "idle"
          ? Math.max(0, Math.min(1, root.svc.elapsedSeconds / root.svc.totalSeconds)) : 0
        onInkChanged: requestPaint()
        onPausedChanged: requestPaint()
        onProgressChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
          var c = getContext("2d"), cx = width / 2, cy = height / 2
          var r = width * 0.38, stroke = Math.max(1.4, width * 0.085)
          c.reset()
          c.lineCap = "round"
          c.lineWidth = stroke
          // Open orbit and satellite: a consistent mark in every timer state.
          c.strokeStyle = ink
          c.beginPath()
          c.arc(cx, cy, r, -Math.PI * 0.06, Math.PI * 1.58)
          c.stroke()
          var angle = -Math.PI * 0.23
          c.fillStyle = ink
          c.beginPath()
          c.arc(cx + Math.cos(angle) * r, cy + Math.sin(angle) * r, stroke * 1.05, 0, Math.PI * 2)
          c.fill()
          // A quieter inner orbit carries progress without changing the logo.
          c.strokeStyle = Util.alpha(ink, 0.35)
          c.lineWidth = Math.max(1, stroke * 0.7)
          c.beginPath()
          c.arc(cx, cy, r * 0.58, 0, Math.PI * 2)
          c.stroke()
          if (progress > 0) {
            c.strokeStyle = ink
            c.beginPath()
            c.arc(cx, cy, r * 0.58, -Math.PI/2, -Math.PI/2 + progress*Math.PI*2)
            c.stroke()
          }
          c.fillStyle = ink
          if (paused) {
            c.fillRect(cx - stroke * 1.2, cy - stroke, stroke * 0.8, stroke * 2)
            c.fillRect(cx + stroke * 0.4, cy - stroke, stroke * 0.8, stroke * 2)
          } else {
            c.beginPath()
            c.arc(cx, cy, stroke, 0, Math.PI * 2)
            c.fill()
          }
        }
      }
      Text {
        visible: !button.vertical && text !== ""
        anchors.verticalCenter: parent.verticalCenter
        text: root.barText()
        color: button.foreground
        font.family: button.fontFamily
        font.pixelSize: Style.bar.iconFont
        renderType: Text.NativeRendering
      }
    }

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
