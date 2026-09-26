// Run with: node --test tests/
const test = require("node:test")
const assert = require("node:assert/strict")
const { load } = require("./load.js")
const Protocol = load("Protocol.js")
const I18n = load("I18n.js")

const en = (s, a) => I18n.t(s, "en", a)
const es = (s, a) => I18n.t(s, "es", a)

test("parseSnapshot keeps a protocol 1 snapshot and fills what is missing", () => {
  const r = Protocol.parseSnapshot(JSON.stringify({ protocol: 1, available: true, context: { workspace: 3 }, cards: [{ id: 1 }] }))
  assert.equal(r.problem, "")
  assert.equal(r.snapshot.available, true)
  assert.deepEqual(r.snapshot.cards, [{ id: 1 }])
  assert.deepEqual(r.snapshot.capabilities, {})
  assert.deepEqual(r.snapshot.shortcuts, { available: false, rows: [], occupied: [] })
})

test("parseSnapshot refuses garbage and other protocols", () => {
  assert.equal(Protocol.parseSnapshot("not json").problem, "unreadable")
  assert.equal(Protocol.parseSnapshot("[1]").problem, "unreadable")
  assert.equal(Protocol.parseSnapshot('{"protocol": 2}').problem, "protocol")
  assert.equal(Protocol.parseSnapshot('{"protocol": 2}').snapshot.available, false)
  const r = Protocol.parseSnapshot('{"protocol": 1, "available": "yes", "cards": {}, "shortcuts": {"rows": []}}')
  assert.equal(r.snapshot.available, false)
  assert.deepEqual(r.snapshot.cards, [])
  assert.deepEqual(r.snapshot.shortcuts.occupied, [])
})

test("request puts protocol, action and context first", () => {
  assert.deepEqual(Protocol.request("flip", { workspace: 3 }, { target: { id: 1 } }),
    { protocol: 1, action: "flip", context: { workspace: 3 }, target: { id: 1 } })
  assert.deepEqual(Protocol.request("unpair", null), { protocol: 1, action: "unpair", context: null })
})

test("receive reads each helper line", () => {
  assert.deepEqual(Protocol.receive('{"type":"handoff","id":4}'), { kind: "handoff", id: 4, message: "" })
  assert.deepEqual(Protocol.receive('{"type":"done","message":"Tarjeta creada."}'), { kind: "done", id: null, message: "Tarjeta creada." })
  assert.equal(Protocol.receive("  ").kind, "blank")
  assert.equal(Protocol.receive("oops").kind, "unreadable")
  assert.equal(Protocol.receive('{"type":"launch-missiles"}').kind, "unreadable")
})

test("sameFaces compares the addresses of both sides in order", () => {
  const card = { faces: [{ panes: [{ address: "0x1" }] }, { panes: [{ address: "0x2" }, { address: "0x3" }] }] }
  assert.deepEqual(Protocol.faceAddresses(card), [["0x1"], ["0x2", "0x3"]])
  assert.ok(Protocol.sameFaces([["0x1"], ["0x2", "0x3"]], Protocol.faceAddresses(card)))
  assert.ok(!Protocol.sameFaces([["0x1"], ["0x3", "0x2"]], Protocol.faceAddresses(card)))
  assert.ok(!Protocol.sameFaces(null, [["0x1"]]))
  assert.deepEqual(Protocol.cardTarget({ kind: "container", id: 7, token: "t", faces: [] }), { kind: "container", id: 7, token: "t" })
})

test("unavailableText says what happened and what to run", () => {
  assert.equal(Protocol.unavailableText({ reason: "ok" }, en), "")
  assert.equal(Protocol.unavailableText({ reason: "no-plugin", fix: "make" }, en), "Hyprflip is not loaded. Install it with: make")
  assert.equal(Protocol.unavailableText({ reason: "mismatch", hyprland: "0.57.0", built_for: "0.56.2", fix: "make" }, es),
    "Hyprflip no cargó: Hyprland es 0.57.0 y Hyprflip se compiló para 0.56.2. Recompilalo con: make")
  assert.equal(Protocol.unavailableText({}, en), "Checking Hyprflip…")
  for (const reason of ["no-hyprland", "no-helper", "protocol", "helper"])
    assert.notEqual(Protocol.unavailableText({ reason: reason, fix: "x", detail: "y" }, es), Protocol.unavailableText({ reason: reason, fix: "x", detail: "y" }, en))
})

test("canCreate needs the same helper as bin/cards: create_faces and a container provider", () => {
  const snap = caps => Object.assign(Protocol.emptySnapshot(), { available: true, capabilities: caps })
  assert.equal(Protocol.canCreate(true, snap({ create_faces: true, containers: true })), true)
  assert.equal(Protocol.canCreate(true, snap({ create_faces: true, containers: false })), false)
  assert.equal(Protocol.canCreate(true, snap({ create_faces: true })), false)
  assert.equal(Protocol.canCreate(true, snap({ containers: true })), false)
  assert.equal(Protocol.canCreate(false, snap({ create_faces: true, containers: true })), false)
  assert.equal(Protocol.canCreate(true, Protocol.emptySnapshot()), false)
})

test("whyUnavailable: the status first, then an unreadable snapshot, then what the snapshot says", () => {
  const ok = { available: true, reason: "ok" }
  const snap = Object.assign(Protocol.emptySnapshot(), { available: true })
  assert.equal(Protocol.whyUnavailable(ok, snap, "", en), "")
  assert.equal(Protocol.whyUnavailable({ available: false, reason: "no-plugin", fix: "make" }, snap, "", en),
    "Hyprflip is not loaded. Install it with: make")
  assert.equal(Protocol.whyUnavailable(ok, snap, "unreadable", en), "The Hyprflip helper sent an unreadable answer.")
  // A protocol 1 snapshot that says available: false carries the reason.
  const down = Protocol.parseSnapshot(JSON.stringify({ protocol: 1, available: false, error: "Hyprland no responde." })).snapshot
  assert.equal(Protocol.whyUnavailable(ok, down, "", en), "The Hyprflip helper reports: Hyprland no responde.")
  assert.equal(Protocol.whyUnavailable(ok, Protocol.emptySnapshot(), "", en), "The Hyprflip helper reports: ?")
})
