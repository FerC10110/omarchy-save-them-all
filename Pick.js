.import "Builder.js" as Builder

// "Pick on screen": the windows drawn on the monitor, which one is under the
// pointer, and what a click does to the draft. No QML in here.

// The shown windows of a workspace, in monitor coordinates, topmost first:
// floating windows, then by how recently each had focus.
function rects(clients, workspace, origin) {
  return (clients || []).filter(function(c) {
    return c.workspace && c.workspace.id === workspace && !c.hidden && c.mapped !== false
  }).sort(function(a, b) {
    if (!!a.floating !== !!b.floating) return a.floating ? -1 : 1
    return (a.focusHistoryID || 0) - (b.focusHistoryID || 0)
  }).map(function(c) {
    return { address: c.address, x: c.at[0] - origin.x, y: c.at[1] - origin.y, w: c.size[0], h: c.size[1] }
  })
}

function hit(list, x, y) {
  for (var i = 0; i < list.length; i++) {
    var r = list[i]
    if (x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h) return r.address
  }
  return ""
}

// A click: a picked window comes out, any other goes to the active side.
function toggle(draft, address, face, t) {
  if (Builder.faceOf(draft, address) >= 0) return { draft: Builder.remove(draft, address), problem: "" }
  return Builder.place(draft, address, face, -1, t)
}

function faceOfPick(draft, address) {
  return Builder.faceOf(draft, address)
}

// pin: { name, x, y, workspace } recorded by the overlay's open(), once.
// True once the pinned monitor no longer shows the workspace it showed
// then — a workspace-switch keybind fired while the overlay held the
// exclusive keyboard grab (Hyprland still runs those) — so the caller
// knows to cancel the pick instead of showing (and letting a click add
// from) another workspace's windows. activeWorkspace < 0 means no reading
// of the pinned monitor yet: never a change.
function pinChanged(pin, activeWorkspace) {
  return !!pin && activeWorkspace >= 0 && activeWorkspace !== pin.workspace
}

if (typeof module !== "undefined") {
  module.exports = { rects: rects, hit: hit, toggle: toggle, faceOfPick: faceOfPick, pinChanged: pinChanged }
}
