// The Hyprflip helper's panel protocol (version 1), as Save Them All speaks
// it: what a snapshot holds, how a request is built and how each line the
// helper writes back is read. No QML in here, so node can test it.

var PROTOCOL = 1
var KINDS = ["handoff", "question", "opening", "done", "error", "cancelled"]

function emptySnapshot() {
  return { protocol: PROTOCOL, available: false, error: "", context: null, capabilities: {},
           cards: [], transition: "flip", transition_modes: [], duration_ms: null,
           appearance: null, card_gap: null,
           shortcuts: { available: false, rows: [], occupied: [] } }
}

// text: what `control.py snapshot` printed. -> { snapshot, problem }, with
// problem "" | "unreadable" | "protocol"; the snapshot is always safe to read.
function parseSnapshot(text) {
  var data
  try {
    data = JSON.parse(String(text || ""))
  } catch (e) {
    return { snapshot: emptySnapshot(), problem: "unreadable" }
  }
  if (!data || typeof data !== "object" || Array.isArray(data)) return { snapshot: emptySnapshot(), problem: "unreadable" }
  if (data.protocol !== PROTOCOL) return { snapshot: emptySnapshot(), problem: "protocol" }
  var out = emptySnapshot()
  for (var k in data) if (Object.prototype.hasOwnProperty.call(data, k)) out[k] = data[k]
  out.available = data.available === true
  if (!Array.isArray(out.cards)) out.cards = []
  if (!out.capabilities || typeof out.capabilities !== "object") out.capabilities = {}
  if (!out.shortcuts || typeof out.shortcuts !== "object" || !Array.isArray(out.shortcuts.rows))
    out.shortcuts = { available: false, rows: [], occupied: [] }
  if (!Array.isArray(out.shortcuts.occupied)) out.shortcuts.occupied = []
  return { snapshot: out, problem: "" }
}

function request(action, context, extra) {
  var out = { protocol: PROTOCOL, action: action, context: context }
  var more = extra || {}
  for (var k in more) if (Object.prototype.hasOwnProperty.call(more, k)) out[k] = more[k]
  return out
}

// One line of `control.py run`. -> { kind, id, message }: kind is the
// helper's type, "blank" for an empty line, "unreadable" for anything else.
function receive(line) {
  var text = String(line || "").trim()
  if (text === "") return { kind: "blank", id: null, message: "" }
  var m
  try {
    m = JSON.parse(text)
  } catch (e) {
    return { kind: "unreadable", id: null, message: "" }
  }
  if (!m || typeof m !== "object" || KINDS.indexOf(m.type) < 0) return { kind: "unreadable", id: null, message: "" }
  return { kind: m.type, id: m.id === undefined ? null : m.id, message: typeof m.message === "string" ? m.message : "" }
}

// A snapshot card's sides as lists of addresses.
function faceAddresses(card) {
  return ((card && card.faces) || []).map(function(f) { return (f.panes || []).map(function(p) { return p.address }) })
}

function sameFaces(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) return false
  return JSON.stringify(a) === JSON.stringify(b)
}

// Whether whole cards can be made and edited: the same check as bin/cards
// helper_can_create (the helper's create_faces, and a real container
// provider; a stale one can advertise create_faces without containers).
// available: Hyprflip.available, which already covers protocol and status.
function canCreate(available, snapshot) {
  var caps = (snapshot && snapshot.capabilities) || {}
  return available === true && caps.create_faces === true && caps.containers === true
}

function cardTarget(card) {
  return { kind: card.kind, id: card.id, token: card.token }
}

// Why cards cannot be used, from `bin/cards status`, in the panel's
// language (t is the panel's translation function).
function unavailableText(status, t) {
  var s = status || {}
  switch (s.reason) {
  case "ok": return ""
  case "no-hyprland": return t("Hyprland is not answering, so cards are paused.")
  case "no-plugin": return t("Hyprflip is not loaded. Install it with: %1", [s.fix])
  case "mismatch": return t("Hyprflip did not load: Hyprland is %1 and Hyprflip was built for %2. Rebuild it with: %3", [s.hyprland, s.built_for, s.fix])
  case "no-helper": return t("The Hyprflip helper is not installed. Install it with: %1", [s.fix])
  case "protocol": return t("The Hyprflip helper speaks another protocol. Update it with: %1", [s.fix])
  case "helper": return t("The Hyprflip helper reports: %1", [s.detail])
  default: return t("Checking Hyprflip…")
  }
}

if (typeof module !== "undefined") {
  module.exports = { emptySnapshot: emptySnapshot, parseSnapshot: parseSnapshot, request: request, receive: receive,
                     faceAddresses: faceAddresses, sameFaces: sameFaces, cardTarget: cardTarget, canCreate: canCreate,
                     unavailableText: unavailableText }
}
