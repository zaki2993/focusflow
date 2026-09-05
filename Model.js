// Pure pomodoro math + date bucketing (shared logic from lucas.pomodoro, adapted for Focus Flow)

var MS_PER_DAY = 86400000

function pad2(n) {
  var x = Number(n)
  return (x < 10 ? "0" : "") + x
}

function dateKey(date) {
  return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate())
}

function parseKey(key) {
  var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(key || ""))
  if (!m) return null
  var month = parseInt(m[2], 10) - 1
  var day = parseInt(m[3], 10)
  if (month < 0 || month > 11 || day < 1 || day > 31) return null
  return { year: parseInt(m[1], 10), month: month, day: day }
}

function isoWeekInfo(year, month, day) {
  var date = new Date(Date.UTC(year, month, day))
  var weekday = date.getUTCDay() || 7
  date.setUTCDate(date.getUTCDate() + 4 - weekday)
  var isoYear = date.getUTCFullYear()
  var yearStart = new Date(Date.UTC(isoYear, 0, 1))
  var week = Math.ceil(((date.getTime() - yearStart.getTime()) / MS_PER_DAY + 1) / 7)
  return { year: isoYear, week: week }
}

function countToday(sessions, now) {
  var target = dateKey(now)
  var count = 0
  for (var i = 0; i < sessions.length; i++) if (sessions[i] === target) count++
  return count
}

function countWeek(sessions, now) {
  var target = isoWeekInfo(now.getFullYear(), now.getMonth(), now.getDate())
  var count = 0
  for (var i = 0; i < sessions.length; i++) {
    var p = parseKey(sessions[i])
    if (!p) continue
    var info = isoWeekInfo(p.year, p.month, p.day)
    if (info.year === target.year && info.week === target.week) count++
  }
  return count
}

function countMonth(sessions, now) {
  var targetYear = now.getFullYear()
  var targetMonth = now.getMonth()
  var count = 0
  for (var i = 0; i < sessions.length; i++) {
    var p = parseKey(sessions[i])
    if (!p) continue
    if (p.year === targetYear && p.month === targetMonth) count++
  }
  return count
}

function formatRemaining(ms) {
  var total = Math.max(0, Math.floor(Number(ms) / 1000) || 0)
  var hours = Math.floor(total / 3600)
  var minutes = Math.floor((total % 3600) / 60)
  var seconds = Math.floor(total % 60)
  if (hours > 0) return hours + ":" + pad2(minutes) + ":" + pad2(seconds)
  return minutes + ":" + pad2(seconds)
}

function clampInt(value, fallback, min, max) {
  var n = parseInt(value, 10)
  if (!isFinite(n)) n = fallback
  if (n < min) n = min
  if (n > max) n = max
  return n
}

function validReminderMode(value) {
  var modes = ["notification", "overlay"]
  var s = String(value || "")
  return modes.indexOf(s) !== -1 ? s : "notification"
}

function validSessions(raw) {
  if (!Array.isArray(raw)) return []
  var out = []
  for (var i = 0; i < raw.length; i++) {
    var p = parseKey(raw[i])
    if (p) out.push(dateKey(new Date(p.year, p.month, p.day)))
  }
  out.sort()
  return out
}

function pruneSessions(sessions, now, days) {
  var cutoff = new Date(now.getFullYear(), now.getMonth(), now.getDate() - days)
  var key = dateKey(cutoff)
  var out = []
  for (var i = 0; i < sessions.length; i++) if (sessions[i] >= key) out.push(sessions[i])
  return out
}

function formatMinutes(mins) {
  var total = Math.max(0, Math.floor(Number(mins) || 0))
  var h = Math.floor(total / 60)
  var m = total % 60
  if (h > 0 && m > 0) return h + "h " + m + "m"
  if (h > 0) return h + "h"
  return m + "m"
}

function dailyGoalPercent(count, goal) {
  var g = Math.max(1, parseInt(goal, 10) || 4)
  var c = Math.max(0, parseInt(count, 10) || 0)
  return Math.min(100, Math.round((c / g) * 100))
}

function validPriority(value) {
  var s = String(value || "").toLowerCase().trim()
  if (s === "high" || s === "h" || s === "urgent") return "high"
  if (s === "low" || s === "l") return "low"
  if (s === "medium" || s === "med" || s === "m" || s === "normal") return "medium"
  return "medium"
}

function priorityWeight(priority) {
  var p = validPriority(priority)
  if (p === "high") return 3
  if (p === "medium") return 2
  if (p === "low") return 1
  return 2
}

function priorityColor(priority) {
  var p = validPriority(priority)
  if (p === "high") return "#ef4444"
  if (p === "medium") return "#f59e0b"
  if (p === "low") return "#3b82f6"
  return "#f59e0b"
}

function priorityLabel(priority) {
  var p = validPriority(priority)
  if (p === "high") return "High"
  if (p === "medium") return "Medium"
  if (p === "low") return "Low"
  return "Medium"
}

function priorityIcon(priority) {
  var p = validPriority(priority)
  if (p === "high") return "▲"
  if (p === "medium") return "▬"
  if (p === "low") return "▼"
  return "▬"
}

function taskStats(tasks) {
  if (!Array.isArray(tasks)) return { total: 0, done: 0, pending: 0, percent: 0 }
  var total = tasks.length
  var done = 0
  for (var i = 0; i < tasks.length; i++) {
    if (tasks[i] && tasks[i].done) done++
  }
  var pending = total - done
  var percent = total > 0 ? Math.min(100, Math.round((done / total) * 100)) : 0
  return { total: total, done: done, pending: pending, percent: percent }
}

function nextPriority(priority) {
  var p = validPriority(priority)
  if (p === "medium") return "high"
  if (p === "high") return "low"
  return "medium"
}

function parseTaskInput(text) {
  var s = String(text || "").trim()
  if (!s) return { title: "", priority: null }
  var regex = /(?:^|\s)(?:!|#|p:)(high|med|medium|urgent|h|low|l|m)(?:\b|$)/i
  var match = regex.exec(s)
  if (match) {
    var prio = validPriority(match[1])
    var cleanTitle = s.replace(match[0], " ").replace(/\s+/g, " ").trim()
    return { title: cleanTitle, priority: prio }
  }
  return { title: s, priority: null }
}

if (typeof module !== "undefined") {
  module.exports = {
    dateKey: dateKey, parseKey: parseKey, isoWeekInfo: isoWeekInfo,
    countToday: countToday, countWeek: countWeek, countMonth: countMonth,
    formatRemaining: formatRemaining, clampInt: clampInt,
    validReminderMode: validReminderMode, validSessions: validSessions,
    pruneSessions: pruneSessions, formatMinutes: formatMinutes,
    dailyGoalPercent: dailyGoalPercent, taskStats: taskStats,
    validPriority: validPriority, priorityWeight: priorityWeight,
    priorityColor: priorityColor, priorityLabel: priorityLabel,
    priorityIcon: priorityIcon, nextPriority: nextPriority,
    parseTaskInput: parseTaskInput
  }
}
