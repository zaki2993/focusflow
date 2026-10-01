import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Focus Flow — unified pomodoro + task service.
Item {
  id: root

  property var shell: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string statePath: home + "/.local/state/omarchy/focusflow-studio.json"

  // ── Web App Blocker settings & state ─────────────────────────────────────────
  property bool blockerEnabled: true
  property string blockerAction: "close"   // "close" | "switch" | "notify"
  property bool blockerScanOnStart: true
  property var blockedWebApps: Model.defaultBlockedWebApps()
  property int blockedCountToday: 0
  property double lastBlockNotificationTime: 0
  property string lastBlockedAppNotified: ""

  readonly property int activeBlockedCount: {
    var count = 0
    if (Array.isArray(blockedWebApps)) {
      for (var i = 0; i < blockedWebApps.length; i++) {
        if (blockedWebApps[i] && blockedWebApps[i].enabled) count++
      }
    }
    return count
  }

  // ── Pomodoro settings ──────────────────────────────────────────────────────
  property int focusMinutes: 25
  property int breakMinutes: 5
  property bool autoStartBreak: true
  property bool autoStartFocus: false
  property string reminderMode: "notification"
  property bool soundAlert: true
  property bool taskSoundAlert: true
  property int dailyGoal: 4

  // ── Pomodoro stats ─────────────────────────────────────────────────────────
  property var sessions: []
  readonly property int totalFocusMinutesToday: countToday * focusMinutes

  // ── Pomodoro runtime ───────────────────────────────────────────────────────
  property string phase: "idle"   // "idle" | "focus" | "break"
  property bool running: false
  property double endAt: 0
  property double remainingMs: 0
  property double totalMs: 0
  property string lastCompleted: ""

  property double _now: Date.now()

  readonly property double remaining: running
    ? Math.max(0, endAt - _now)
    : remainingMs

  readonly property string displayTime: Model.formatRemaining(remaining)
  readonly property int totalSeconds: Math.max(1, Math.round(totalMs / 1000))
  readonly property int elapsedSeconds: Math.max(0, Math.round((totalMs - remaining) / 1000))

  readonly property int countToday: Model.countToday(sessions, new Date(_now))
  readonly property int countWeek:  Model.countWeek(sessions, new Date(_now))
  readonly property int countMonth: Model.countMonth(sessions, new Date(_now))

  // ── Tasks ──────────────────────────────────────────────────────────────────
  property var tasks: []
  property bool loaded: false

  // The task currently linked to the running focus session (id, or "")
  property string activeTaskId: ""

  readonly property int openCount: {
    var n = 0
    for (var i = 0; i < tasks.length; i++) if (!tasks[i].done) n++
    return n
  }

  readonly property var activeTask: {
    if (!activeTaskId) return null
    for (var i = 0; i < tasks.length; i++)
      if (String(tasks[i].id) === String(activeTaskId)) return tasks[i]
    return null
  }

  // ── Task operations ────────────────────────────────────────────────────────
  function addTask(title, priority) {
    var parsed = Model.parseTaskInput(title)
    var val = parsed.title || String(title || "").trim()
    if (!val) return false
    var prio = priority ? Model.validPriority(priority) : (parsed.priority || "medium")
    var next = tasks.slice()
    next.unshift({
      id: String(Date.now()) + Math.random(),
      title: val,
      done: false,
      pomos: 0,
      priority: prio
    })
    tasks = next
    scheduleSave()
    return true
  }

  function setTaskPriority(id, priority) {
    var prio = Model.validPriority(priority)
    var next = tasks.slice()
    for (var i = 0; i < next.length; i++) {
      if (String(next[i].id) === String(id)) {
        next[i] = {
          id: next[i].id,
          title: next[i].title,
          done: next[i].done,
          pomos: next[i].pomos || 0,
          priority: prio
        }
        break
      }
    }
    tasks = next
    scheduleSave()
  }

  function cycleTaskPriority(id) {
    var next = tasks.slice()
    for (var i = 0; i < next.length; i++) {
      if (String(next[i].id) === String(id)) {
        var currentPrio = Model.validPriority(next[i].priority)
        var nextPrio = Model.nextPriority(currentPrio)
        next[i] = {
          id: next[i].id,
          title: next[i].title,
          done: next[i].done,
          pomos: next[i].pomos || 0,
          priority: nextPrio
        }
        break
      }
    }
    tasks = next
    scheduleSave()
  }

  function toggleTask(id) {
    var next = tasks.slice()
    var nowDone = false
    for (var i = 0; i < next.length; i++) {
      if (String(next[i].id) === String(id)) {
        nowDone = !next[i].done
        next[i] = {
          id: next[i].id,
          title: next[i].title,
          done: nowDone,
          pomos: next[i].pomos || 0,
          priority: Model.validPriority(next[i].priority)
        }
        break
      }
    }
    tasks = next
    scheduleSave()
    if (nowDone) {
      playTaskDoneSound()
    }
  }

  function playTaskDoneSound() {
    if (!taskSoundAlert) return
    var soundPath = home + "/.config/omarchy/plugins/zakarch.focusflow-studio/sounds/task_done.wav"
    Quickshell.execDetached(["bash", "-c", "canberra-gtk-play -f " + soundPath + " 2>/dev/null || pw-play " + soundPath + " 2>/dev/null || paplay " + soundPath + " 2>/dev/null"])
  }

  function removeTask(id) {
    tasks = tasks.filter(function(t) { return String(t.id) !== String(id) })
    if (activeTaskId === String(id)) activeTaskId = ""
    scheduleSave()
  }

  function setActiveTask(id) {
    activeTaskId = (activeTaskId === String(id)) ? "" : String(id)
    scheduleSave()
  }

  function clearCompletedTasks() {
    tasks = tasks.filter(function(t) { return !t.done })
    scheduleSave()
  }

  function editTask(id, newTitle, newPriority) {
    var val = String(newTitle || "").trim()
    if (!val) return false
    var next = tasks.slice()
    for (var i = 0; i < next.length; i++) {
      if (String(next[i].id) === String(id)) {
        var prio = (newPriority !== undefined && newPriority !== null)
          ? Model.validPriority(newPriority)
          : Model.validPriority(next[i].priority)
        next[i] = {
          id: next[i].id,
          title: val,
          done: next[i].done,
          pomos: next[i].pomos || 0,
          priority: prio
        }
        break
      }
    }
    tasks = next
    scheduleSave()
    return true
  }

  function _bumpActiveTaskPomos() {
    if (!activeTaskId) return
    var next = tasks.slice()
    for (var i = 0; i < next.length; i++) {
      if (String(next[i].id) === String(activeTaskId)) {
        next[i] = {
          id: next[i].id,
          title: next[i].title,
          done: next[i].done,
          pomos: (next[i].pomos || 0) + 1,
          priority: Model.validPriority(next[i].priority)
        }
        break
      }
    }
    tasks = next
  }

  // ── Blocker operations ──────────────────────────────────────────────────────
  function addBlockedWebApp(urlOrDomain, customName) {
    var parsed = Model.parseWebappInput(urlOrDomain, customName)
    if (!parsed) return false
    var next = blockedWebApps.slice()
    for (var i = 0; i < next.length; i++) {
      if (next[i].domain === parsed.domain) {
        next[i] = {
          id: next[i].id,
          name: customName ? customName : next[i].name,
          domain: next[i].domain,
          pattern: next[i].pattern,
          url: parsed.url,
          enabled: true
        }
        blockedWebApps = next
        scheduleSave()
        return true
      }
    }
    next.unshift(parsed)
    blockedWebApps = next
    scheduleSave()
    return true
  }

  function removeBlockedWebApp(id) {
    blockedWebApps = blockedWebApps.filter(function(app) {
      return String(app.id) !== String(id)
    })
    scheduleSave()
  }

  function toggleBlockedWebApp(id) {
    var next = blockedWebApps.slice()
    for (var i = 0; i < next.length; i++) {
      if (String(next[i].id) === String(id)) {
        next[i] = {
          id: next[i].id,
          name: next[i].name,
          domain: next[i].domain,
          pattern: next[i].pattern,
          url: next[i].url,
          enabled: !next[i].enabled
        }
        break
      }
    }
    blockedWebApps = next
    scheduleSave()
  }

  function addPresetWebApp(key) {
    var presets = Model.presetWebApps()
    for (var i = 0; i < presets.length; i++) {
      if (presets[i].id === key || presets[i].name.toLowerCase().indexOf(key.toLowerCase()) !== -1) {
        return addBlockedWebApp(presets[i].url, presets[i].name)
      }
    }
    return false
  }

  function resetBlockedWebAppsToDefault() {
    blockedWebApps = Model.defaultBlockedWebApps()
    scheduleSave()
  }

  function closeHyprlandWindow(address) {
    if (address) {
      var luaCmd = 'hl.dispatch(hl.dsp.window.close({ address = "' + address + '" }))'
      Quickshell.execDetached(["bash", "-c", "hyprctl eval '" + luaCmd + "' 2>/dev/null || hyprctl dispatch closewindow address:" + address + " 2>/dev/null"])
    } else {
      Quickshell.execDetached(["bash", "-c", "hyprctl eval 'hl.dispatch(hl.dsp.window.close())' 2>/dev/null || hyprctl dispatch 'hl.dsp.window.close()' 2>/dev/null"])
    }
  }

  function checkAndEnforceBlocker() {
    if (!running || phase !== "focus" || !blockerEnabled) return
    if (!activeWindowCheckProc.running) {
      activeWindowCheckProc.running = true
    }
  }

  function scanAndEnforceAllWindows() {
    if (!running || phase !== "focus" || !blockerEnabled) return
    if (!allClientsScanProc.running) {
      allClientsScanProc.running = true
    }
  }

  function _handleActiveWindowOutput(raw) {
    if (!running || phase !== "focus" || !blockerEnabled) return
    var win = null
    try { win = JSON.parse(raw || "{}") } catch (e) { return }
    if (!win || !win.address || win.address === "0x0") return

    var matchedApp = Model.findBlockedMatch(win, blockedWebApps)
    if (matchedApp) {
      enforceBlockOnWindow(win, matchedApp)
    }
  }

  function enforceBlockOnWindow(win, matchedApp) {
    var address = String(win.address || "")
    var now = Date.now()

    if (blockerAction === "close") {
      closeHyprlandWindow(address)
    } else if (blockerAction === "switch") {
      Quickshell.execDetached(["hyprctl", "dispatch", "workspace", "m+1"])
    }

    if (now - lastBlockNotificationTime > 3000 || lastBlockedAppNotified !== matchedApp.name) {
      lastBlockNotificationTime = now
      lastBlockedAppNotified = matchedApp.name
      blockedCountToday++
      scheduleSave()

      var notifTitle = "Focus Flow Blocker"
      var notifBody = matchedApp.name + " is blocked during your focus session! 🛑\nStay in flow until break time."
      var glyph = Model.webappIcon(matchedApp.name)

      if (soundAlert) {
        Quickshell.execDetached(["canberra-gtk-play", "-i", "dialog-warning"])
      }
      var notifBin = (omarchyPath ? (omarchyPath + "/bin/omarchy-notification-send") : "omarchy-notification-send")
      Quickshell.execDetached([notifBin, notifTitle, notifBody, "-g", glyph])
    }
  }

  function _handleAllClientsOutput(raw) {
    if (!running || phase !== "focus" || !blockerEnabled) return
    var clients = []
    try { clients = JSON.parse(raw || "[]") } catch (e) { return }
    if (!Array.isArray(clients)) return

    var closedNames = []
    for (var i = 0; i < clients.length; i++) {
      var win = clients[i]
      if (!win || !win.address) continue
      var matchedApp = Model.findBlockedMatch(win, blockedWebApps)
      if (matchedApp) {
        if (blockerAction === "close") {
          closeHyprlandWindow(win.address)
          if (closedNames.indexOf(matchedApp.name) === -1) {
            closedNames.push(matchedApp.name)
          }
        }
      }
    }

    if (closedNames.length > 0) {
      blockedCountToday += closedNames.length
      scheduleSave()
      var notifTitle = "Focus Flow Blocker"
      var notifBody = "Auto-closed " + closedNames.join(", ") + " for your focus session! 🎯"
      var notifBin = (omarchyPath ? (omarchyPath + "/bin/omarchy-notification-send") : "omarchy-notification-send")
      Quickshell.execDetached([notifBin, notifTitle, notifBody, "-g", "󰈈"])
    }
  }

  // ── Pomodoro operations ────────────────────────────────────────────────────
  function startFocus() {
    _now = Date.now()
    phase = "focus"
    totalMs = focusMinutes * 60 * 1000
    remainingMs = totalMs
    endAt = _now + totalMs
    running = true
    lastCompleted = ""
    if (blockerEnabled && blockerScanOnStart) {
      Qt.callLater(scanAndEnforceAllWindows)
    }
  }

  function startBreak() {
    _now = Date.now()
    phase = "break"
    totalMs = breakMinutes * 60 * 1000
    remainingMs = totalMs
    endAt = _now + totalMs
    running = true
    lastCompleted = ""
  }

  function pause() {
    if (!running || phase === "idle") return
    _now = Date.now()
    remainingMs = Math.max(0, endAt - _now)
    endAt = 0
    running = false
  }

  function resume() {
    if (running || phase === "idle" || remainingMs <= 0) return
    _now = Date.now()
    endAt = _now + remainingMs
    running = true
    if (phase === "focus" && blockerEnabled && blockerScanOnStart) {
      Qt.callLater(scanAndEnforceAllWindows)
    }
  }

  function reset() {
    running = false
    phase = "idle"
    endAt = 0
    remainingMs = 0
    totalMs = 0
    lastCompleted = ""
  }

  function skipToNext() {
    if (phase === "focus") {
      complete()
    } else if (phase === "break") {
      startFocus()
    } else {
      startFocus()
    }
  }

  function nudgeMinutes(deltaMinutes) {
    var deltaMs = deltaMinutes * 60 * 1000
    if (running) {
      endAt += deltaMs
      totalMs = Math.max(60000, totalMs + deltaMs)
      if (endAt <= _now) complete()
    } else if (phase !== "idle") {
      remainingMs = Math.max(60000, remainingMs + deltaMs)
      totalMs = Math.max(60000, totalMs + deltaMs)
    } else {
      focusMinutes = Model.clampInt(focusMinutes + deltaMinutes, 25, 1, 1440)
    }
  }

  function complete() {
    var completedPhase = phase
    running = false
    endAt = 0
    remainingMs = 0
    lastCompleted = completedPhase
    if (completedPhase === "focus") {
      _bumpActiveTaskPomos()
      recordSession()
      var taskName = activeTask ? " · \"" + activeTask.title + "\"" : ""
      remind("FocusFlow Studio", "Focus complete" + taskName + " — take a break! 🎉", "󰔛")
      if (autoStartBreak) startBreak()
      else phase = "idle"
    } else if (completedPhase === "break") {
      remind("FocusFlow Studio", "Break over — ready to flow again 🚀", "󰅶")
      if (autoStartFocus) startFocus()
      else phase = "idle"
    }
  }

  function recordSession() {
    var list = sessions.slice()
    list.push(Model.dateKey(new Date()))
    sessions = Model.pruneSessions(list, new Date(), 400)
    scheduleSave()
  }

  // ── Reminders ──────────────────────────────────────────────────────────────
  property bool overlayVisible: false
  property string overlayTitle: ""
  property string overlayBody: ""
  property string overlayGlyph: "󰔛"

  function remind(title, body, glyph) {
    if (soundAlert) {
      Quickshell.execDetached(["canberra-gtk-play", "-i", "complete"])
    }
    if (reminderMode === "overlay") {
      overlayTitle = title
      overlayBody = body
      overlayGlyph = glyph
      overlayVisible = true
    } else {
      var notifBin = (omarchyPath ? (omarchyPath + "/bin/omarchy-notification-send") : "omarchy-notification-send")
      Quickshell.execDetached([notifBin, title, body, "-g", glyph])
    }
  }

  // ── Persistence ────────────────────────────────────────────────────
  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.hydrate(text())
    onLoadFailed: if (!root.loaded) legacyFile.path = root.home + "/.local/state/omarchy/focusflow.json"
  }

  // One-time migration: future reads and writes use Studio's own file.
  FileView {
    id: legacyFile
    watchChanges: false
    printErrors: false
    onLoaded: { root.hydrate(text()); root.scheduleSave() }
    onLoadFailed: { root.hydrate(""); root.scheduleSave() }
  }

  Timer {
    id: saveTimer
    interval: 200
    repeat: false
    onTriggered: root.flush()
  }

  function scheduleSave() {
    if (!loaded) return
    saveTimer.restart()
  }

  function hydrate(raw) {
    if (loaded) return
    var data = {}
    try { data = JSON.parse(raw || "{}") } catch (e) { data = {} }

    // Pomodoro settings
    focusMinutes   = Model.clampInt(data.focusMinutes, 25, 1, 1440)
    breakMinutes   = Model.clampInt(data.breakMinutes, 5, 1, 1440)
    autoStartBreak = data.autoStartBreak === undefined ? true : data.autoStartBreak === true
    autoStartFocus = data.autoStartFocus === true
    reminderMode   = Model.validReminderMode(data.reminderMode)
    soundAlert     = data.soundAlert === undefined ? true : data.soundAlert === true
    taskSoundAlert = data.taskSoundAlert === undefined ? true : data.taskSoundAlert === true
    dailyGoal      = Model.clampInt(data.dailyGoal, 4, 1, 30)
    sessions       = Model.validSessions(data.sessions)

    // Tasks
    var result = []
    if (Array.isArray(data.tasks)) {
      for (var i = 0; i < data.tasks.length; i++) {
        var t = data.tasks[i]
        if (t && String(t.title || "").trim())
          result.push({
            id: String(t.id || Date.now() + i),
            title: String(t.title).trim(),
            done: t.done === true,
            pomos: parseInt(t.pomos, 10) || 0,
            priority: Model.validPriority(t.priority)
          })
      }
    }
    tasks = result
    activeTaskId = String(data.activeTaskId || "")

    // Blocker settings
    blockerEnabled     = data.blockerEnabled === undefined ? true : data.blockerEnabled === true
    blockerAction      = (data.blockerAction === "switch" || data.blockerAction === "notify") ? data.blockerAction : "close"
    blockerScanOnStart = data.blockerScanOnStart === undefined ? true : data.blockerScanOnStart === true
    blockedWebApps     = Model.validBlockedWebApps(data.blockedWebApps)
    blockedCountToday  = parseInt(data.blockedCountToday, 10) || 0

    var runtime = data.runtime || {}
    if ((runtime.phase === "focus" || runtime.phase === "break") && Number(runtime.totalMs) > 0) {
      phase = runtime.phase
      totalMs = Number(runtime.totalMs)
      remainingMs = Math.max(0, Number(runtime.remainingMs) || 0)
      endAt = Number(runtime.endAt) || 0
      running = runtime.running === true && endAt > 0
    }
    loaded = true
  }

  function flush() {
    stateFile.setText(JSON.stringify({
      version: 1,
      runtime: { phase: phase, running: running, endAt: endAt, remainingMs: remainingMs, totalMs: totalMs },
      focusMinutes: focusMinutes,
      breakMinutes: breakMinutes,
      autoStartBreak: autoStartBreak,
      autoStartFocus: autoStartFocus,
      reminderMode: reminderMode,
      soundAlert: soundAlert,
      taskSoundAlert: taskSoundAlert,
      dailyGoal: dailyGoal,
      sessions: sessions,
      tasks: tasks,
      activeTaskId: activeTaskId,
      blockerEnabled: blockerEnabled,
      blockerAction: blockerAction,
      blockerScanOnStart: blockerScanOnStart,
      blockedWebApps: blockedWebApps,
      blockedCountToday: blockedCountToday
    }, null, 2) + "\n")
  }

  onPhaseChanged: scheduleSave()
  onRunningChanged: scheduleSave()
  onEndAtChanged: scheduleSave()
  onRemainingMsChanged: scheduleSave()
  onFocusMinutesChanged:       scheduleSave()
  onBreakMinutesChanged:       scheduleSave()
  onAutoStartBreakChanged:     scheduleSave()
  onAutoStartFocusChanged:     scheduleSave()
  onReminderModeChanged:       scheduleSave()
  onSoundAlertChanged:         scheduleSave()
  onTaskSoundAlertChanged:     scheduleSave()
  onDailyGoalChanged:          scheduleSave()
  onActiveTaskIdChanged:       scheduleSave()
  onBlockerEnabledChanged:     scheduleSave()
  onBlockerActionChanged:      scheduleSave()
  onBlockerScanOnStartChanged: scheduleSave()

  Process {
    id: ensureDirProc
    command: ["mkdir", "-p", root.home + "/.local/state/omarchy"]
  }

  Component.onCompleted: {
    ensureDirProc.running = true
    Qt.callLater(function() { stateFile.reload() })
  }

  // ── Tick ───────────────────────────────────────────────────────────────────
  Timer {
    id: tick
    interval: 1000
    repeat: true
    running: true
    onTriggered: {
      root._now = Date.now()
      if (root.running && root.endAt > 0 && root._now >= root.endAt)
        root.complete()
    }
  }

  // ── Hyprland Blocker Watcher ───────────────────────────────────────────────
  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (!root.running || root.phase !== "focus" || !root.blockerEnabled) return
      var name = String(event && event.name ? event.name : "")
      if (name === "openwindow" || name === "activewindow" || name === "activewindowv2") {
        blockerDebounceTimer.restart()
      }
    }

    function onActiveToplevelChanged() {
      if (!root.running || root.phase !== "focus" || !root.blockerEnabled) return
      blockerDebounceTimer.restart()
    }
  }

  Timer {
    id: blockerDebounceTimer
    interval: 150
    repeat: false
    onTriggered: root.checkAndEnforceBlocker()
  }

  Timer {
    id: blockerPeriodicTimer
    interval: 1500
    repeat: true
    running: root.running && root.phase === "focus" && root.blockerEnabled
    onTriggered: root.checkAndEnforceBlocker()
  }

  Process {
    id: activeWindowCheckProc
    command: ["hyprctl", "activewindow", "-j"]
    stdout: StdioCollector {
      id: activeWindowCollector
    }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root._handleActiveWindowOutput(activeWindowCollector.text)
      }
    }
  }

  Process {
    id: allClientsScanProc
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      id: allClientsCollector
    }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root._handleAllClientsOutput(allClientsCollector.text)
      }
    }
  }

  // ── IPC ────────────────────────────────────────────────────────────────────
  IpcHandler {
    target: "focusflow-studio"

    function startFocus(): string   { root.startFocus();   return "ok" }
    function startBreak(): string   { root.startBreak();   return "ok" }
    function pause(): string        { root.pause();        return "ok" }
    function resume(): string       { root.resume();       return "ok" }
    function reset(): string        { root.reset();        return "ok" }
    function skip(): string         { root.skipToNext();   return "ok" }
    function nudge(mins: string): string {
      var n = parseInt(mins, 10) || 0
      if (n !== 0) root.nudgeMinutes(n)
      return "ok"
    }
    function addTask(title: string): string {
      return root.addTask(title) ? "ok" : "err:empty"
    }
    function addTaskWithPriority(title: string, priority: string): string {
      return root.addTask(title, priority) ? "ok" : "err:empty"
    }
    function setPriority(id: string, priority: string): string {
      root.setTaskPriority(id, priority)
      return "ok"
    }
    function cyclePriority(id: string): string {
      root.cycleTaskPriority(id)
      return "ok"
    }
    function editTask(id: string, title: string): string {
      return root.editTask(id, title) ? "ok" : "err"
    }
    function removeTask(id: string): string { root.removeTask(id); return "ok" }
    function toggleTask(id: string): string { root.toggleTask(id); return "ok" }
    function setActive(id: string): string  { root.setActiveTask(id); return "ok" }
    function clearDone(): string    { root.clearCompletedTasks(); return "ok" }

    // Blocker IPC methods
    function addBlockedApp(url: string, name: string): string {
      return root.addBlockedWebApp(url, name) ? "ok" : "err"
    }
    function removeBlockedApp(id: string): string {
      root.removeBlockedWebApp(id)
      return "ok"
    }
    function toggleBlockedApp(id: string): string {
      root.toggleBlockedWebApp(id)
      return "ok"
    }
    function addPresetApp(key: string): string {
      return root.addPresetWebApp(key) ? "ok" : "err"
    }
    function resetBlockedApps(): string {
      root.resetBlockedWebAppsToDefault()
      return "ok"
    }
    function setBlockerEnabled(enabled: string): string {
      root.blockerEnabled = (enabled === "true" || enabled === "1")
      return "ok"
    }
    function setBlockerAction(action: string): string {
      if (action === "close" || action === "switch" || action === "notify") {
        root.blockerAction = action
        return "ok"
      }
      return "err"
    }

    function status(): string {
      return JSON.stringify({
        phase: root.phase,
        running: root.running,
        remaining: Math.round(root.remaining),
        total: Math.round(root.totalMs),
        focusMinutes: root.focusMinutes,
        breakMinutes: root.breakMinutes,
        autoStartBreak: root.autoStartBreak,
        autoStartFocus: root.autoStartFocus,
        reminderMode: root.reminderMode,
        soundAlert: root.soundAlert,
        dailyGoal: root.dailyGoal,
        today: root.countToday,
        week: root.countWeek,
        month: root.countMonth,
        openTasks: root.openCount,
        activeTaskId: root.activeTaskId,
        blockerEnabled: root.blockerEnabled,
        blockerAction: root.blockerAction,
        blockerScanOnStart: root.blockerScanOnStart,
        blockedWebAppsCount: root.blockedWebApps.length,
        activeBlockedCount: root.activeBlockedCount,
        blockedCountToday: root.blockedCountToday
      })
    }
  }

  // ── Full-screen overlay reminder ───────────────────────────────────────────
  PanelWindow {
    id: overlay
    visible: root.overlayVisible
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-focusflow-studio-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.overlayVisible = false
    }

    BorderSurface {
      anchors.centerIn: parent
      width: Style.space(360)
      height: overlayContent.implicitHeight + Style.spacing.panelPadding * 2
      radius: Style.cornerRadius
      color: Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))

      Column {
        id: overlayContent
        anchors.horizontalCenter: parent.horizontalCenter
        y: Style.spacing.panelPadding
        spacing: Style.space(10)

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.overlayGlyph
          font.family: Style.font.family
          font.pixelSize: 64
          color: Color.menu.text
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.overlayTitle
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          font.bold: true
          color: Color.menu.text
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.overlayBody
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          color: Qt.darker(Color.menu.text, 1.4)
        }
        Button {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.topMargin: Style.space(6)
          text: "Dismiss"
          foreground: Color.menu.text
          accent: Color.accent
          onClicked: root.overlayVisible = false
        }
      }
    }
  }
}
