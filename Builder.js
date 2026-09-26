// The card builder's draft and every rule about it, without QML: which
// windows can join a card and why not, where each one goes, and the request
// Hyprflip's `create` gets. The builder page and the pick overlay only draw
// this and call it. t is the panel's translation function.
//
// draft: { mode: "create" | "edit", card: null | { kind, id, faces, axes, ratios },
//          workspace, faces: [[address…], [address…]],
//          axes: ["row" | "column", …], visible: 0 | 1,
//          floating: null | { at, size }, name, cursor }

var MAX_PER_SIDE = 5

function copy(draft) {
  return JSON.parse(JSON.stringify(draft))
}

function newDraft(workspace) {
  return { mode: "create", card: null, workspace: workspace, faces: [[], []], axes: ["row", "row"],
           visible: 0, floating: null, name: "", cursor: "" }
}

// A side's ratios as a snapshot face lists them, or null when it does not
// (the helper's snapshot does not carry them yet) or they are not usable:
// one number in (0, 1] per window.
function faceRatios(face) {
  var r = face.ratios
  if (!Array.isArray(r) || r.length !== face.panes.length) return null
  return r.every(function(x) { return typeof x === "number" && x > 0 && x <= 1 }) ? r.slice() : null
}

// card: a snapshot card; name: its name; rect: { at, size } of the window it
// shows when it floats, so it keeps its place. draft.card keeps what the
// card was (sides, axes, ratios): what the edit is compared against.
function editDraft(card, name, rect) {
  var faces = card.faces.map(function(f) { return f.panes.map(function(p) { return p.address }) })
  var axes = card.faces.map(function(f) { return f.axis === "vertical" ? "column" : "row" })
  return { mode: "edit", card: { kind: card.kind, id: card.id, faces: faces, axes: axes, ratios: card.faces.map(faceRatios) },
           workspace: card.workspace, faces: copy(faces), axes: axes.slice(),
           visible: card.active === 1 ? 1 : 0, floating: card.floating && rect ? rect : null,
           name: name || "", cursor: "" }
}

function faceOf(draft, address) {
  if (!draft) return -1
  for (var i = 0; i < 2; i++) if (draft.faces[i].indexOf(address) >= 0) return i
  return -1
}

// A stable key for a draft's faces (or one side of them): equal for two
// drafts with the same windows on the same sides in the same order, even
// though place()/remove()/setAxis() clone every side's array on every call.
// The builder page and FaceBox use these to skip rebuilding a window list
// (and its live thumbnails) on a cursor move or a name edit, which also
// replace the draft as a whole (Service.qml reassigns it wholesale).
function facesKey(draft) {
  return draft ? JSON.stringify(draft.faces) : ""
}

function faceKey(draft, face) {
  return draft ? JSON.stringify(draft.faces[face]) : "[]"
}

// What reason() needs: the windows of other cards, the windows of the card
// being edited, and whether Hyprflip takes floating windows.
function context(cards, draft, capabilities) {
  var owned = {}, own = {}
  var editing = draft && draft.card ? draft.card : null
  ;(cards || []).forEach(function(c) {
    var mine = editing && c.kind === editing.kind && c.id === editing.id
    c.faces.forEach(function(f) {
      f.panes.forEach(function(p) { if (mine) own[p.address] = true; else owned[p.address] = true })
    })
  })
  return { owned: owned, own: own, floatingOk: !!(capabilities && capabilities.floating_members) }
}

// A stable key for what context() says: which windows are taken, which
// are the edited card's own, and whether floating windows may join. The
// builder rebuilds its window list when this changes (a card made or taken
// apart elsewhere), not on every snapshot, which is a new object each time.
function contextKey(ctx) {
  return ctx ? JSON.stringify([Object.keys(ctx.owned).sort(), Object.keys(ctx.own).sort(), ctx.floatingOk]) : ""
}

// Why a window cannot join the card, or "".
function reason(win, ctx, t) {
  var mine = ctx.own[win.address] === true
  if (ctx.owned[win.address]) return t("Already in a card")
  if (win.fullscreen) return t("Fullscreen")
  if (!win.workspace || win.workspace.id <= 0) return t("On a special workspace")
  if (win["class"] === "org.quickshell") return t("This panel")
  if (!mine && win.grouped && win.grouped.length > 0) return t("In a window group")
  if (win.pinned) return t("Pinned")
  if (!mine && win.floating && !ctx.floatingOk) return t("Floating; Hyprflip needs it tiled")
  return ""
}

function byPosition(a, b) {
  return (a.win.at[0] - b.win.at[0]) || (a.win.at[1] - b.win.at[1])
}

// The builder's window list: groups by workspace, the draft's first, then
// the other workspaces in order, then the special ones.
function candidates(clients, draft, ctx, t) {
  var groups = {}
  ;(clients || []).forEach(function(c) {
    if (c.mapped === false) return
    var ws = c.workspace ? c.workspace.id : 0
    if (!groups[ws]) groups[ws] = []
    groups[ws].push({ address: c.address, win: c, reason: reason(c, ctx, t), face: faceOf(draft, c.address) })
  })
  var ids = Object.keys(groups).map(Number).sort(function(a, b) {
    if (a === draft.workspace) return -1
    if (b === draft.workspace) return 1
    if ((a > 0) !== (b > 0)) return a > 0 ? -1 : 1
    return a - b
  })
  return ids.map(function(id) {
    return { workspace: id, current: id === draft.workspace, windows: groups[id].sort(byPosition) }
  })
}

// Put a window on a side at index (-1: at the end), taking it off the
// other side. Reordering within the same side takes the window out first,
// which shifts every later index down by one; a drop target computed
// against the array before that removal (FaceBox's DropArea, against
// box.members) needs the same shift, or it lands one slot past where it
// was dropped. -> { draft, problem }; on a problem the draft is unchanged.
function place(draft, address, face, index, t) {
  var d = copy(draft)
  var from = faceOf(d, address)
  var at = index
  if (from >= 0) {
    var sourceIndex = d.faces[from].indexOf(address)
    d.faces[from].splice(sourceIndex, 1)
    if (from === face && at !== undefined && at >= 0 && sourceIndex < at) at -= 1
  }
  if (d.faces[face].length >= MAX_PER_SIDE) return { draft: draft, problem: t("A side holds up to %1 windows.", [MAX_PER_SIDE]) }
  at = at === undefined || at < 0 || at > d.faces[face].length ? d.faces[face].length : at
  d.faces[face].splice(at, 0, address)
  d.cursor = address
  return { draft: d, problem: "" }
}

function remove(draft, address) {
  var d = copy(draft)
  d.faces = d.faces.map(function(f) { return f.filter(function(a) { return a !== address }) })
  return d
}

function setAxis(draft, face, axis) {
  var d = copy(draft)
  d.axes[face] = axis === "column" ? "column" : "row"
  return d
}

// Take closed windows out. -> { draft, gone: [address…] }
function prune(draft, clients) {
  var open = {}
  ;(clients || []).forEach(function(c) { open[c.address] = true })
  var gone = []
  draft.faces.forEach(function(f) { f.forEach(function(a) { if (!open[a]) gone.push(a) }) })
  var d = draft
  gone.forEach(function(a) { d = remove(d, a) })
  if (gone.indexOf(d.cursor) >= 0) d.cursor = ""
  return { draft: d, gone: gone }
}

function ready(draft) {
  return !!draft && draft.faces[0].length > 0 && draft.faces[1].length > 0
}

// The fields of Hyprflip's `create`. An edited card keeps a side's ratios
// while that side holds the same windows in the same order (its axis may
// turn); any other side starts equal, and with nothing kept, ratios is
// null: the helper's "start equal", a new layout.
function request(draft) {
  var was = draft.card && Array.isArray(draft.card.ratios) ? draft.card : null
  var kept = draft.faces.map(function(f, i) {
    return was && was.ratios[i] && JSON.stringify(f) === JSON.stringify(was.faces[i]) ? was.ratios[i].slice() : null
  })
  var ratios = kept.some(function(r) { return r !== null }) ? kept.map(function(r, i) {
    var n = draft.faces[i].length
    return r || draft.faces[i].map(function() { return 1 / n })
  }) : null
  return { faces: draft.faces.map(function(f) { return f.map(function(a) { return "address:" + a }) }),
           axes: draft.axes.slice(), ratios: ratios, visible: draft.visible, floating: draft.floating }
}

// An edit that changed nothing but the name (the builder cannot change the
// visible side or where it floats): no reason to rebuild the card.
function nameOnly(draft) {
  if (!draft || draft.mode !== "edit" || !draft.card || !Array.isArray(draft.card.axes)) return false
  return JSON.stringify(draft.faces) === JSON.stringify(draft.card.faces)
    && JSON.stringify(draft.axes) === JSON.stringify(draft.card.axes)
}

// Windows of the draft that live on another workspace: creating the card
// moves them to the card's.
function movesFrom(draft, byAddress) {
  var out = []
  draft.faces.forEach(function(f) {
    f.forEach(function(a) {
      var w = byAddress[a]
      if (w && w.workspace && w.workspace.id !== draft.workspace) out.push(a)
    })
  })
  return out
}

// Where a window is among windows with its name on its workspace, so two
// kitty windows read "left" and "right". [] when it has no twin.
function twinWords(win, clients, appName) {
  var name = appName(win)
  var ws = win.workspace ? win.workspace.id : null
  var same = (clients || []).filter(function(c) { return c.workspace && c.workspace.id === ws && appName(c) === name })
  if (same.length < 2) return []
  function cx(c) { return c.at[0] + c.size[0] / 2 }
  function cy(c) { return c.at[1] + c.size[1] / 2 }
  var xs = same.map(cx), ys = same.map(cy)
  var minX = Math.min.apply(null, xs), maxX = Math.max.apply(null, xs)
  var minY = Math.min.apply(null, ys), maxY = Math.max.apply(null, ys)
  var words = []
  if (maxX - minX > 10) words.push(cx(win) <= minX + 10 ? "left" : cx(win) >= maxX - 10 ? "right" : "center")
  if (maxY - minY > 10) words.push(cy(win) <= minY + 10 ? "top" : cy(win) >= maxY - 10 ? "bottom" : "middle")
  return words
}

function wordText(word, t) {
  switch (word) {
  case "left": return t("left")
  case "right": return t("right")
  case "center": return t("center")
  case "top": return t("top")
  case "bottom": return t("bottom")
  case "middle": return t("middle")
  default: return word
  }
}

function label(win, clients, appName, t) {
  var words = twinWords(win, clients, appName).map(function(w) { return wordText(w, t) })
  return appName(win) + (words.length ? " · " + words.join(" ") : "")
}

// Width over height of the place the card will take: its first front window.
function slotAspect(draft, byAddress) {
  var first = draft && draft.faces[0].length ? byAddress[draft.faces[0][0]] : null
  if (first && first.size && first.size[0] > 0 && first.size[1] > 0) return first.size[0] / first.size[1]
  return 16 / 9
}

function submitText(draft, t) {
  return draft && draft.mode === "edit" ? t("Save changes") : t("Create card")
}

if (typeof module !== "undefined") {
  module.exports = { MAX_PER_SIDE: MAX_PER_SIDE, newDraft: newDraft, editDraft: editDraft, faceOf: faceOf,
                     facesKey: facesKey, faceKey: faceKey,
                     context: context, contextKey: contextKey, reason: reason, candidates: candidates, place: place, remove: remove,
                     setAxis: setAxis, prune: prune, ready: ready, request: request, nameOnly: nameOnly, movesFrom: movesFrom,
                     twinWords: twinWords, wordText: wordText, label: label, slotAspect: slotAspect,
                     submitText: submitText }
}
