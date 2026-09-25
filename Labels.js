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

// The English label of a Hyprflip shortcut id, or fallback.
function shortcutLabel(id, fallback) {
  var found = SHORTCUTS.find(function(x) { return x.id === id })
  return found ? found.label : fallback
}

if (typeof module !== "undefined") {
  module.exports = { TRANSITIONS: TRANSITIONS, SPEEDS: SPEEDS, APPEARANCES: APPEARANCES, SPACINGS: SPACINGS,
                     LANGUAGES: LANGUAGES, SHORTCUTS: SHORTCUTS, transitions: transitions, shortcutLabel: shortcutLabel }
}
