// Our own names for Hyprflip's choices, in English: the panel shows
// t(entry.label) and t(entry.detail). Hyprflip's helper names them in
// Spanish only, so its labels are the fallback for ids we do not know.

var TRANSITIONS = [
  { value: "flip", label: "Flip", detail: "Turns sideways" },
  { value: "vertical", label: "Vertical", detail: "Turns top to bottom" },
  { value: "slide", label: "Slide", detail: "The sides slide across" },
  { value: "fade", label: "Fade", detail: "The sides fade into each other" },
  { value: "dissolve", label: "Dissolve", detail: "Experimental · Reveals in soft fragments" },
  { value: "portal", label: "Portal", detail: "Experimental · Reveals from the center" },
  { value: "instant", label: "Instant", detail: "Switches without animation" }
]

var SPEEDS = [
  { ms: 280, label: "Fast" },
  { ms: 420, label: "Normal" },
  { ms: 600, label: "Slow" }
]

var APPEARANCES = [
  { value: "classic", label: "Classic tabs", detail: "Tab bars over tiled cards" },
  { value: "frame", label: "Card frame", detail: "A shared outline and a small Flip control · Experimental" }
]

var SPACINGS = [
  { value: -1, label: "Desktop spacing", detail: "The same gaps as other tiled windows" },
  { value: 12, label: "Compact spacing", detail: "12 px between the apps of a card" }
]

var LANGUAGES = [
  { value: "auto", label: "Automatic" },
  { value: "en", label: "English" },
  { value: "es", label: "Español" }
]

var SHORTCUTS = [
  { id: "flip", label: "Flip the card" },
  { id: "create", label: "Create a card" },
  { id: "edit", label: "Edit the card" },
  { id: "library", label: "Card library" },
  { id: "find", label: "Find an app" },
  { id: "peek", label: "Peek at the other side" },
  { id: "unpair", label: "Take the card apart" },
  { id: "mark", label: "Mark an app" },
  { id: "pair", label: "Pair with the marked app" },
  { id: "attach_h", label: "Attach side by side" },
  { id: "attach_v", label: "Attach stacked" },
  { id: "release", label: "Release an app" },
  { id: "cancel", label: "Cancel" }
]

// The transitions Hyprflip offers, in our order.
function transitions(modes) {
  return TRANSITIONS.filter(function(x) { return (modes || []).indexOf(x.value) >= 0 })
}

// The speed rows for Hyprflip's duration_ms: the presets, and a "Custom"
// one when it is set to something else (by hand, or by another tool), so
// the Settings tab still shows which speed is on.
function speeds(duration) {
  var out = SPEEDS.slice()
  if (typeof duration === "number" && !SPEEDS.some(function(s) { return s.ms === duration }))
    out.push({ ms: duration, label: "Custom", custom: true })
  return out
}

// The English label of a Hyprflip shortcut id, or fallback.
function shortcutLabel(id, fallback) {
  var found = SHORTCUTS.find(function(x) { return x.id === id })
  return found ? found.label : fallback
}

// The id of the row delta places from id in rows (each with its own `id`),
// or "" with no rows; an id not found (removed, or the first call) starts
// from the first row. Keeps a keyboard cursor stable across a row list that
// is rebuilt on every change (SettingsTab's rows, a shortcut's own
// bindings), after CardsModel's `step`.
function step(rows, id, delta) {
  var list = rows || []
  if (list.length === 0) return ""
  var i = list.findIndex(function(r) { return r.id === id })
  if (i < 0) return list[0].id
  return list[Math.max(0, Math.min(list.length - 1, i + delta))].id
}

// Where a scroll view (its top at viewTop, viewHeight tall) should stand
// so a row at top, height tall, shows: unchanged when it already does, else
// the least move; a row taller than the view shows its top. The panel uses
// it to follow a keyboard cursor down a long list.
function scrollFor(top, height, viewTop, viewHeight) {
  if (top < viewTop || height > viewHeight) return top
  if (top + height > viewTop + viewHeight) return top + height - viewHeight
  return viewTop
}

if (typeof module !== "undefined") {
  module.exports = { TRANSITIONS: TRANSITIONS, SPEEDS: SPEEDS, APPEARANCES: APPEARANCES, SPACINGS: SPACINGS,
                     LANGUAGES: LANGUAGES, SHORTCUTS: SHORTCUTS, transitions: transitions, speeds: speeds, shortcutLabel: shortcutLabel,
                     step: step, scrollFor: scrollFor }
}
