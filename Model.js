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

if (typeof module !== "undefined") {
  module.exports = {
    dateKey: dateKey, parseKey: parseKey, isoWeekInfo: isoWeekInfo,
    countToday: countToday, countWeek: countWeek, countMonth: countMonth,
    formatRemaining: formatRemaining, clampInt: clampInt,
    validReminderMode: validReminderMode, validSessions: validSessions,
    pruneSessions: pruneSessions
  }
}
