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

// ── Web App Blocker Helpers ──────────────────────────────────────────────────

var DEFAULT_BLOCKED_APPS = [
  {
    id: "whatsapp",
    name: "WhatsApp",
    domain: "web.whatsapp.com",
    pattern: "whatsapp",
    url: "https://web.whatsapp.com",
    enabled: true
  },
  {
    id: "x",
    name: "X (Twitter)",
    domain: "x.com",
    pattern: "x.com",
    url: "https://x.com",
    enabled: true
  }
]

var PRESET_BLOCKED_APPS = [
  { id: "whatsapp", name: "WhatsApp", domain: "web.whatsapp.com", pattern: "whatsapp", url: "https://web.whatsapp.com" },
  { id: "x", name: "X (Twitter)", domain: "x.com", pattern: "x.com", url: "https://x.com" },
  { id: "youtube", name: "YouTube", domain: "youtube.com", pattern: "youtube", url: "https://youtube.com" },
  { id: "reddit", name: "Reddit", domain: "reddit.com", pattern: "reddit", url: "https://reddit.com" },
  { id: "instagram", name: "Instagram", domain: "instagram.com", pattern: "instagram", url: "https://instagram.com" },
  { id: "discord", name: "Discord", domain: "discord.com", pattern: "discord", url: "https://discord.com" },
  { id: "tiktok", name: "TikTok", domain: "tiktok.com", pattern: "tiktok", url: "https://tiktok.com" },
  { id: "facebook", name: "Facebook", domain: "facebook.com", pattern: "facebook", url: "https://facebook.com" }
]

function defaultBlockedWebApps() {
  return JSON.parse(JSON.stringify(DEFAULT_BLOCKED_APPS))
}

function presetWebApps() {
  return JSON.parse(JSON.stringify(PRESET_BLOCKED_APPS))
}

function cleanDomain(input) {
  var s = String(input || "").trim().toLowerCase()
  s = s.replace(/^[a-zA-Z]+:\/\//, "")
  s = s.split("/")[0].split("?")[0].split("#")[0]
  s = s.replace(/^www\./, "")
  s = s.split(":")[0]
  return s
}

function guessWebappName(domainOrUrl) {
  var d = cleanDomain(domainOrUrl)
  if (!d) return "Web App"
  if (d.indexOf("whatsapp") !== -1) return "WhatsApp"
  if (d === "x.com" || d.indexOf("twitter") !== -1) return "X (Twitter)"
  if (d.indexOf("youtube") !== -1) return "YouTube"
  if (d.indexOf("reddit") !== -1) return "Reddit"
  if (d.indexOf("instagram") !== -1) return "Instagram"
  if (d.indexOf("facebook") !== -1) return "Facebook"
  if (d.indexOf("tiktok") !== -1) return "TikTok"
  if (d.indexOf("discord") !== -1) return "Discord"
  if (d.indexOf("twitch") !== -1) return "Twitch"
  if (d.indexOf("netflix") !== -1) return "Netflix"
  if (d.indexOf("linkedin") !== -1) return "LinkedIn"
  if (d.indexOf("threads") !== -1) return "Threads"
  if (d.indexOf("pinterest") !== -1) return "Pinterest"
  if (d.indexOf("github") !== -1) return "GitHub"

  var parts = d.split(".")
  var namePart = parts[0]
  if (namePart === "web" || namePart === "app" || namePart === "m" || namePart === "news") {
    if (parts.length > 1) namePart = parts[1]
  }
  if (namePart.length > 0) {
    return namePart.charAt(0).toUpperCase() + namePart.slice(1)
  }
  return d
}

function webappIcon(nameOrDomain) {
  var s = String(nameOrDomain || "").toLowerCase()
  if (s.indexOf("whatsapp") !== -1) return "󰖣"
  if (s === "x" || s.indexOf("x.com") !== -1 || s.indexOf("twitter") !== -1) return "󰕄"
  if (s.indexOf("youtube") !== -1) return "󰗃"
  if (s.indexOf("reddit") !== -1) return "󰑍"
  if (s.indexOf("instagram") !== -1) return "󰛏"
  if (s.indexOf("discord") !== -1) return "󰙯"
  if (s.indexOf("facebook") !== -1) return "󰈌"
  if (s.indexOf("music") !== -1 || s.indexOf("spotify") !== -1) return "󰓇"
  return "󰈈"
}

function parseWebappInput(rawInput, customName) {
  var s = String(rawInput || "").trim()
  if (!s) return null
  var url = s
  if (!/^[a-zA-Z]+:\/\//.test(url)) {
    url = "https://" + url
  }
  var domain = cleanDomain(s)
  if (!domain) return null
  var name = String(customName || "").trim() || guessWebappName(domain)
  var pattern = domain

  if (domain.indexOf("whatsapp") !== -1) pattern = "whatsapp"
  else if (domain === "x.com" || domain.indexOf("twitter") !== -1) pattern = "x.com"
  else if (domain.indexOf("youtube") !== -1) pattern = "youtube"
  else if (domain.indexOf("reddit") !== -1) pattern = "reddit"
  else if (domain.indexOf("instagram") !== -1) pattern = "instagram"

  return {
    id: "app_" + Date.now() + "_" + Math.floor(Math.random() * 1000),
    name: name,
    domain: domain,
    pattern: pattern,
    url: url,
    enabled: true
  }
}

function validBlockedWebApps(raw) {
  if (!Array.isArray(raw)) return defaultBlockedWebApps()
  var out = []
  for (var i = 0; i < raw.length; i++) {
    var item = raw[i]
    if (!item || (!item.domain && !item.url && !item.name)) continue
    var domain = cleanDomain(item.domain || item.url || "")
    if (!domain) continue
    var name = String(item.name || "").trim() || guessWebappName(domain)
    var pattern = String(item.pattern || "").trim() || domain
    var url = String(item.url || "").trim() || ("https://" + domain)
    var enabled = item.enabled === undefined ? true : item.enabled === true
    out.push({
      id: String(item.id || ("app_" + i)),
      name: name,
      domain: domain,
      pattern: pattern,
      url: url,
      enabled: enabled
    })
  }
  return out
}

function isSafeWindow(win) {
  var cls = String((win && (win.class || win.initialClass)) || "").toLowerCase()
  var safeClasses = [
    "ghostty", "kitty", "alacritty", "foot", "terminal",
    "code", "vscodium", "neovim", "nvim", "zed", "cursor",
    "nautilus", "thunar", "dolphin", "pcmanfm", "quickshell",
    "rofi", "wofi", "walker", "dmenu"
  ]
  for (var i = 0; i < safeClasses.length; i++) {
    if (cls.indexOf(safeClasses[i]) !== -1) return true
  }
  return false
}

function isBrowserOrWebappWindow(win) {
  var cls = String((win && (win.class || win.initialClass)) || "").toLowerCase()
  var browserTokens = [
    "chrome", "chromium", "brave", "firefox", "edge",
    "opera", "vivaldi", "zen", "librewolf", "floorp"
  ]
  for (var i = 0; i < browserTokens.length; i++) {
    if (cls.indexOf(browserTokens[i]) !== -1) return true
  }
  return false
}

function matchWindowToBlockedApp(win, blockedItem) {
  if (!win || !blockedItem || !blockedItem.enabled) return false
  if (isSafeWindow(win)) return false

  var cls = String(win.class || "").toLowerCase()
  var initCls = String(win.initialClass || "").toLowerCase()
  var title = String(win.title || "").toLowerCase()
  var initTitle = String(win.initialTitle || "").toLowerCase()

  var domain = String(blockedItem.domain || "").toLowerCase()
  var pattern = String(blockedItem.pattern || "").toLowerCase()
  var name = String(blockedItem.name || "").toLowerCase()

  if (domain && (cls.indexOf(domain) !== -1 || initCls.indexOf(domain) !== -1)) return true
  if (pattern && (cls.indexOf(pattern) !== -1 || initCls.indexOf(pattern) !== -1)) return true
  if (domain && (initTitle.indexOf(domain) !== -1)) return true

  if (isBrowserOrWebappWindow(win)) {
    if (domain && (title.indexOf(domain) !== -1 || initTitle.indexOf(domain) !== -1)) return true
    if (pattern && (title.indexOf(pattern) !== -1 || initTitle.indexOf(pattern) !== -1)) return true

    if (domain.indexOf("whatsapp") !== -1 || name.indexOf("whatsapp") !== -1) {
      if (title.indexOf("whatsapp") !== -1 || initTitle.indexOf("whatsapp") !== -1) return true
    }

    if (domain === "x.com" || domain.indexOf("twitter") !== -1 || name === "x" || name.indexOf("x (") !== -1 || name.indexOf("twitter") !== -1) {
      if (title.indexOf("twitter") !== -1 || initTitle.indexOf("twitter") !== -1) return true
      if (title.indexOf("x.com") !== -1 || initTitle.indexOf("x.com") !== -1) return true
      var xRegex = /(?:^|\s|\/|\|)x(?:\s*[-–—|]|\s*$)/
      if (xRegex.test(title)) return true
    }

    if (domain.indexOf("youtube") !== -1 || name.indexOf("youtube") !== -1) {
      if (title.indexOf("youtube") !== -1) return true
    }

    if (domain.indexOf("reddit") !== -1 || name.indexOf("reddit") !== -1) {
      if (title.indexOf("reddit") !== -1) return true
    }

    if (name && name.length > 2 && name !== "web app" && name !== "browser") {
      if (title.indexOf(name) !== -1) return true
    }
  }

  return false
}

function findBlockedMatch(win, blockedList) {
  if (!win || !Array.isArray(blockedList)) return null
  for (var i = 0; i < blockedList.length; i++) {
    var item = blockedList[i]
    if (item && item.enabled && matchWindowToBlockedApp(win, item)) {
      return item
    }
  }
  return null
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
    parseTaskInput: parseTaskInput,
    defaultBlockedWebApps: defaultBlockedWebApps,
    presetWebApps: presetWebApps,
    cleanDomain: cleanDomain,
    guessWebappName: guessWebappName,
    webappIcon: webappIcon,
    parseWebappInput: parseWebappInput,
    validBlockedWebApps: validBlockedWebApps,
    isSafeWindow: isSafeWindow,
    isBrowserOrWebappWindow: isBrowserOrWebappWindow,
    matchWindowToBlockedApp: matchWindowToBlockedApp,
    findBlockedMatch: findBlockedMatch
  }
}
