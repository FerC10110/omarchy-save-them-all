// Recording and checking a Hyprflip shortcut, after OmaCards'
// ShortcutsContent.qml (MIT, see NOTICE). Masks are Hyprland's (Super 64,
// Ctrl 4, Alt 8, Shift 1). Key codes and modifier bits are Qt's, written
// out here so node can test this without QML.

var KEY = {
  Escape: 0x01000000, Tab: 0x01000001, Backtab: 0x01000002, Backspace: 0x01000003, Return: 0x01000004,
  Insert: 0x01000006, Delete: 0x01000007, Home: 0x01000010, End: 0x01000011, Left: 0x01000012,
  Up: 0x01000013, Right: 0x01000014, Down: 0x01000015, PageUp: 0x01000016, PageDown: 0x01000017,
  Shift: 0x01000020, Control: 0x01000021, Meta: 0x01000022, Alt: 0x01000023, AltGr: 0x01001103,
  F1: 0x01000030, F35: 0x01000052, Space: 0x20, A: 0x41, Z: 0x5a, D0: 0x30, D9: 0x39
}
var MOD = { Shift: 0x02000000, Control: 0x04000000, Alt: 0x08000000, Meta: 0x10000000 }

// Hyprland's names for the keys that are not a letter, a digit or F1–F35.
var NAMED = {}
NAMED[KEY.Space] = "space"
NAMED[KEY.Escape] = "Escape"
NAMED[KEY.Return] = "Return"
NAMED[KEY.Tab] = "Tab"
NAMED[KEY.Backtab] = "Tab"
NAMED[KEY.Backspace] = "BackSpace"
NAMED[KEY.Delete] = "Delete"
NAMED[KEY.Insert] = "Insert"
NAMED[KEY.Home] = "Home"
NAMED[KEY.End] = "End"
NAMED[KEY.PageUp] = "Prior"
NAMED[KEY.PageDown] = "Next"
NAMED[KEY.Left] = "Left"
NAMED[KEY.Right] = "Right"
NAMED[KEY.Up] = "Up"
NAMED[KEY.Down] = "Down"

function chord(mask, key, t) {
  var names = []
  if (mask & 64) names.push("Super")
  if (mask & 4) names.push("Ctrl")
  if (mask & 8) names.push("Alt")
  if (mask & 1) names.push("Shift")
  names.push(key === "space" ? t("Space") : key === "Escape" ? "Esc" : key)
  return names.join("+")
}

// One key press while recording. -> { ignore } (a modifier alone, a
// repeat), { cancel } (Esc alone), { error } or { mask, key }.
function capture(code, modifiers, autoRepeat, t) {
  if (autoRepeat) return { ignore: true }
  if ([KEY.Control, KEY.Shift, KEY.Alt, KEY.Meta, KEY.AltGr].indexOf(code) >= 0) return { ignore: true }
  var any = MOD.Shift | MOD.Control | MOD.Alt | MOD.Meta
  if (code === KEY.Escape && !(modifiers & any)) return { cancel: true }
  var mask = 0
  if (modifiers & MOD.Meta) mask |= 64
  if (modifiers & MOD.Control) mask |= 4
  if (modifiers & MOD.Alt) mask |= 8
  if (modifiers & MOD.Shift) mask |= 1
  if (!(mask & 76)) return { error: t("Include Super, Ctrl or Alt.") }
  var key = ""
  if ((code >= KEY.A && code <= KEY.Z) || (code >= KEY.D0 && code <= KEY.D9)) key = String.fromCharCode(code)
  else if (code >= KEY.F1 && code <= KEY.F35) key = "F" + (code - KEY.F1 + 1)
  else key = NAMED[code] || ""
  if (!key) return { error: t("Use a letter, a number, a function key or a navigation key.") }
  return { mask: mask, key: key }
}

// Why the chord cannot go to selectedId, or "": the same refusals as the
// helper's shortcuts.save, binding by binding in its order. A binding in a
// submap only counts when it is universal; a physical-key binding, or one
// Hyprland reported without a key, blocks its modifiers; and a binding that
// shares the action's current chord (current: { mask, key }) blocks any
// change, since the helper would not know which one to unbind.
function conflict(occupied, selectedId, mask, key, t, labelOf, current) {
  var now = current && current.key ? [current.mask, String(current.key).toLowerCase()] : null
  var list = occupied || []
  for (var i = 0; i < list.length; i++) {
    var b = list[i]
    if (b.id === selectedId && !b.submap) continue
    var bKey = String(b.key || "").toLowerCase()
    var counts = !b.submap || b.universal
    if (now && b.mask === now[0] && bKey === now[1])
      return t("%1 also uses this action's current shortcut, so Hyprflip cannot change it. Change that one first.", [labelOf(b)])
    if (counts && b.mask === mask && bKey !== "" && bKey === String(key).toLowerCase())
      return t("Used by %1. Choose another shortcut.", [labelOf(b)])
    if (counts && b.mask === mask && b.keycode)
      return t("A physical-key shortcut uses these modifiers. Choose other modifiers.")
    if (counts && b.mask === mask && bKey === "")
      return t("Hyprland did not report the key of %1, so it cannot be checked. Choose other modifiers.", [labelOf(b)])
  }
  return ""
}

if (typeof module !== "undefined") {
  module.exports = { chord: chord, capture: capture, conflict: conflict }
}
