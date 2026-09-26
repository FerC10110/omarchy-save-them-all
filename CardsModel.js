// The Cards tab's view of Hyprflip's cards: grouped by workspace, the one
// on screen first, each with a readable title and the apps on each side.
// No QML in here. t is the panel's translation function.

function faceNames(card, byAddress, appName) {
  return card.faces.map(function(f) {
    return f.panes.map(function(p) { return byAddress[p.address] ? appName(byAddress[p.address]) : String(p.label || p.address) })
  })
}

// The name given in the builder, else its apps: "kitty ↔ obsidian + btop".
function title(card, names, byAddress, appName) {
  var name = names ? names[String(card.id)] : ""
  if (name) return String(name)
  return faceNames(card, byAddress, appName).map(function(f) { return f.join(" + ") }).join(" ↔ ")
}

function groups(cards, focused) {
  var by = {}
  ;(cards || []).forEach(function(c) {
    if (!by[c.workspace]) by[c.workspace] = []
    by[c.workspace].push(c)
  })
  return Object.keys(by).map(Number).sort(function(a, b) {
    if (a === focused) return -1
    if (b === focused) return 1
    return a - b
  }).map(function(ws) { return { workspace: ws, current: ws === focused, cards: by[ws] } })
}

function flat(list) {
  var out = []
  ;(list || []).forEach(function(g) { g.cards.forEach(function(c) { out.push(c) }) })
  return out
}

// The key of the card delta places away from key (the first card when key
// is not shown), or "" with no cards.
function step(list, key, delta) {
  var cards = flat(list)
  if (cards.length === 0) return ""
  var i = cards.findIndex(function(c) { return c.key === key })
  if (i < 0) return cards[0].key
  return cards[Math.max(0, Math.min(cards.length - 1, i + delta))].key
}

function modeText(card, t) {
  if (card.unfolded) return t("Unfolded")
  return card.floating ? t("Floating") : t("Tiled")
}

function sideText(face, names, t) {
  return face === 0 ? t("Front: %1", [names.join(" + ")]) : t("Back: %1", [names.join(" + ")])
}

// What Hyprflip.run's `card` option checks against a fresh snapshot.
function reference(card) {
  return { kind: card.kind, id: card.id,
           faces: card.faces.map(function(f) { return f.panes.map(function(p) { return p.address }) }) }
}

// The card a create just made, for the name given in the builder:
// waiting = { faces, name, until } (until: a Date.now() deadline). Only the
// first snapshots after that create count: later, a card with the same
// windows was made some other way and keeps its own name.
function namedCard(cards, waiting, now) {
  if (!waiting || now > waiting.until) return null
  var want = JSON.stringify(waiting.faces)
  return (cards || []).find(function(c) { return JSON.stringify(reference(c).faces) === want }) || null
}

// What the Cards tab's keys (and buttons) can do to card now. The helper
// only unfolds a container (a native pair has nothing to unfold), and
// floating needs Hyprflip's floating cards; canCreate and canUnpair are
// Hyprflip's own. card null: nothing is chosen, only a new card.
function allowed(card, capabilities, canCreate, canUnpair) {
  var caps = capabilities || {}
  var some = !!card
  return { flip: some, edit: some && canCreate === true, dismantle: some && canUnpair === true,
           unfold: some && card.kind === "container", float: some && caps.floating === true,
           create: canCreate === true }
}

// The key hints under the list, each on or off (shown greyed) per allowed().
function hints(can, t) {
  return [{ text: t("v flip"), on: can.flip }, { text: t("e edit"), on: can.edit },
          { text: t("d dismantle"), on: can.dismantle }, { text: t("u unfold"), on: can.unfold },
          { text: t("t float"), on: can.float }, { text: t("n new"), on: can.create }]
}

if (typeof module !== "undefined") {
  module.exports = { faceNames: faceNames, title: title, groups: groups, flat: flat, step: step,
                     modeText: modeText, sideText: sideText, reference: reference, namedCard: namedCard,
                     allowed: allowed, hints: hints }
}
