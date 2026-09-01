function boundedText(value, maxLength) {
  var text = String(value === undefined || value === null ? "" : value)
  return text.length > maxLength ? text.slice(0, maxLength) : text
}

function asDate(value) {
  if (!value) return null
  var parsed = new Date(String(value))
  return isNaN(parsed.getTime()) ? null : parsed
}

function normalizeTournament(raw) {
  if (!raw) return null
  var start = asDate(String(raw.startDate || "") + "T00:00:00Z")
  var end = asDate(String(raw.endDate || "") + "T23:59:59Z")
  if (!start || !end) return null
  return {
    id: boundedText(raw.id, 64),
    name: boundedText(raw.name, 96),
    city: boundedText(raw.city, 64),
    country: boundedText(raw.country, 64),
    start: start,
    end: end
  }
}

function normalizeMatch(raw) {
  if (!raw) return null
  var home = boundedText(raw.home, 48)
  var away = boundedText(raw.away, 48)
  if (!home && !away) return null
  return {
    id: boundedText(raw.id, 64),
    round: boundedText(raw.round, 48),
    start: asDate(raw.start),
    status: boundedText(raw.status, 24),
    live: raw.live === true,
    bestOf: Math.max(0, Math.min(99, Number(raw.bestOf || 0) || 0)),
    home: home || "TBD",
    away: away || "TBD",
    homeScore: Math.max(0, Math.min(99, Number(raw.homeScore || 0) || 0)),
    awayScore: Math.max(0, Math.min(99, Number(raw.awayScore || 0) || 0)),
    frames: []
  }
}

function sameDay(a, b) {
  return !!a && !!b && a.getFullYear() === b.getFullYear()
      && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
}

function parsePayload(raw, now) {
  try {
    var data = JSON.parse(String(raw || ""))
    var current = normalizeTournament(data && data.current)
    if (!current) return { ok: false, error: "No tournament in the calendar", matches: [], upcoming: [] }

    var reference = now instanceof Date ? now : new Date()
    var matches = []
    var rawMatches = Array.isArray(data.matches) ? data.matches : []
    // A single event cannot approach this bound; ignore surplus records.
    var matchCount = Math.min(rawMatches.length, 64)
    for (var i = 0; i < matchCount; i++) {
      var match = normalizeMatch(rawMatches[i])
      if (match) matches.push(match)
    }

    var upcoming = []
    var rawUpcoming = Array.isArray(data.upcoming) ? data.upcoming : []
    var upcomingCount = Math.min(rawUpcoming.length, 12)
    for (var j = 0; j < upcomingCount; j++) {
      var tournament = normalizeTournament(rawUpcoming[j])
      if (tournament) upcoming.push(tournament)
    }

    var live = []
    var today = []
    var later = []
    var results = []
    for (var k = 0; k < matches.length; k++) {
      var entry = matches[k]
      if (entry.live) live.push(entry)
      else if (entry.status.toLowerCase() === "completed") results.push(entry)
      else if (sameDay(entry.start, reference)) today.push(entry)
      else later.push(entry)
    }

    return {
      ok: true,
      error: "",
      running: current.start.getTime() <= reference.getTime() && reference.getTime() <= current.end.getTime(),
      current: current,
      round: live.length ? live[0].round : (today.length ? today[0].round : (results.length ? results[0].round : "")),
      matches: matches,
      live: live,
      today: today,
      later: later.slice(0, 6),
      results: results.slice(0, 6),
      upcoming: upcoming
    }
  } catch (e) {
    return { ok: false, error: "Could not read the calendar", matches: [], upcoming: [] }
  }
}

function mergeLive(schedule, raw) {
  if (!schedule || !Array.isArray(schedule.live)) return schedule
  var scores
  try {
    scores = JSON.parse(String(raw || "{}"))
  } catch (e) {
    return schedule
  }
  if (!scores || typeof scores !== "object") return schedule

  for (var i = 0; i < schedule.live.length; i++) {
    var match = schedule.live[i]
    var update = scores[match.id]
    if (!update) continue
    match.homeScore = Math.max(0, Math.min(99, Number(update.home || 0) || 0))
    match.awayScore = Math.max(0, Math.min(99, Number(update.away || 0) || 0))
    match.meta = boundedText(update.meta, 24)
    match.frames = Array.isArray(update.frames) ? update.frames.slice(-12) : []
  }
  return schedule
}

function frameLine(match) {
  if (!match || !match.frames || !match.frames.length) return ""
  var parts = []
  for (var i = 0; i < match.frames.length; i++) {
    var frame = match.frames[i]
    parts.push(String(Number(frame.h) || 0) + "-" + String(Number(frame.a) || 0))
  }
  return parts.join("  ")
}

function metaLabel(match) {
  if (!match) return ""
  if (match.meta === "IN_PLAY") return "IN PLAY"
  if (match.meta === "FRAME_HAS_ENDED") return "BETWEEN FRAMES"
  if (match.meta === "INTERVAL") return "INTERVAL"
  return "LIVE"
}

function pad(value) { return value < 10 ? "0" + value : String(value) }

function countdown(target, now, compact, includeSeconds) {
  if (!target) return "—"
  var current = now instanceof Date ? now.getTime() : Number(now || Date.now())
  var diff = target.getTime() - current
  if (diff <= 0 && diff > -4 * 60 * 60 * 1000) return "LIVE"
  if (diff <= 0) return "DONE"
  var totalSeconds = Math.floor(diff / 1000)
  var days = Math.floor(totalSeconds / 86400)
  var hours = Math.floor((totalSeconds % 86400) / 3600)
  var minutes = Math.floor((totalSeconds % 3600) / 60)
  var seconds = totalSeconds % 60
  if (compact) {
    if (days > 0) return days + "D " + pad(hours) + "H"
    if (hours > 0) return hours + "H " + pad(minutes) + "M"
    return minutes + "M"
  }
  if (days > 0) {
    var value = "T− " + days + "D " + pad(hours) + "H " + pad(minutes) + "M"
    return includeSeconds ? value + " " + pad(seconds) + "S" : value
  }
  return "T− " + pad(hours) + ":" + pad(minutes) + ":" + pad(seconds)
}

function dateRange(tournament, formatter) {
  if (!tournament) return ""
  var start = tournament.start
  var end = tournament.end
  if (start.getMonth() === end.getMonth())
    return formatter(start, "d") + "–" + formatter(end, "d MMM")
  return formatter(start, "d MMM") + " – " + formatter(end, "d MMM")
}

function place(tournament) {
  if (!tournament) return ""
  var parts = []
  if (tournament.city) parts.push(tournament.city)
  if (tournament.country) parts.push(tournament.country)
  return parts.join(" · ")
}
