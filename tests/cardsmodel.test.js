// Run with: node --test tests/
const test = require("node:test")
const assert = require("node:assert/strict")
const { load } = require("./load.js")
const CardsModel = load("CardsModel.js")

const t = (s, a) => s.replace(/%(\d+)/g, (m, n) => (a && a[n - 1] !== undefined ? String(a[n - 1]) : m))
const card = (id, ws, faces, extra) => Object.assign({ id, kind: "container", key: "container:" + id, token: "t" + id,
  workspace: ws, active: 0, floating: false, unfolded: false,
  faces: faces.map(f => ({ axis: "horizontal", panes: f.map(a => ({ address: a, label: "L" + a })) })) }, extra || {})
const byAddress = { "0x1": { class: "kitty" }, "0x2": { class: "obsidian" } }
const appName = w => w.class

test("a card is called by its name, else by its apps", () => {
  const c = card(1, 3, [["0x1"], ["0x2", "0x9"]])
  assert.equal(CardsModel.title(c, { 1: "Notes" }, byAddress, appName), "Notes")
  assert.equal(CardsModel.title(c, {}, byAddress, appName), "kitty ↔ obsidian + L0x9")
  assert.deepEqual(CardsModel.faceNames(c, byAddress, appName), [["kitty"], ["obsidian", "L0x9"]])
})

test("groups put the workspace on screen first", () => {
  const cards = [card(1, 5, [["0x1"], ["0x2"]]), card(2, 3, [["0x3"], ["0x4"]]), card(3, 1, [["0x5"], ["0x6"]])]
  const g = CardsModel.groups(cards, 3)
  assert.deepEqual(g.map(x => [x.workspace, x.current]), [[3, true], [1, false], [5, false]])
  assert.deepEqual(CardsModel.flat(g).map(c => c.id), [2, 3, 1])
})

test("step walks the cards in the order shown", () => {
  const g = CardsModel.groups([card(1, 5, [["a"], ["b"]]), card(2, 3, [["c"], ["d"]])], 3)
  assert.equal(CardsModel.step(g, "", 0), "container:2")
  assert.equal(CardsModel.step(g, "container:2", 1), "container:1")
  assert.equal(CardsModel.step(g, "container:1", 1), "container:1")
  assert.equal(CardsModel.step([], "", 1), "")
})

test("mode and side texts", () => {
  assert.equal(CardsModel.modeText(card(1, 3, [["a"], ["b"]]), t), "Tiled")
  assert.equal(CardsModel.modeText(card(1, 3, [["a"], ["b"]], { floating: true }), t), "Floating")
  assert.equal(CardsModel.modeText(card(1, 3, [["a"], ["b"]], { unfolded: true, floating: true }), t), "Unfolded")
  assert.equal(CardsModel.sideText(1, ["a", "b"], t), "Back: a + b")
})

test("reference is what the service checks against a fresh snapshot", () => {
  assert.deepEqual(CardsModel.reference(card(4, 3, [["0x1"], ["0x2", "0x3"]])),
    { kind: "container", id: 4, faces: [["0x1"], ["0x2", "0x3"]] })
})

test("a native pair reads and is referenced like a one-and-one card", () => {
  const pair = card(5, 3, [["0x1"], ["0x2"]], { kind: "pair", key: "pair:5", active: 1, current: "0x2" })
  assert.equal(CardsModel.title(pair, {}, byAddress, appName), "kitty ↔ obsidian")
  assert.deepEqual(CardsModel.reference(pair), { kind: "pair", id: 5, faces: [["0x1"], ["0x2"]] })
  assert.deepEqual(CardsModel.groups([pair], 3)[0].cards.map(c => c.key), ["pair:5"])
})

test("allowed: u only unfolds a container, t needs floating cards, e/n need create, d needs unpair", () => {
  const box = card(1, 3, [["0x1"], ["0x2"]])
  const pair = card(5, 3, [["0x3"], ["0x4"]], { kind: "pair", key: "pair:5" })
  const all = { floating: true }
  assert.deepEqual(CardsModel.allowed(box, all, true, true),
    { flip: true, edit: true, dismantle: true, unfold: true, float: true, create: true })
  assert.deepEqual(CardsModel.allowed(pair, {}, false, false),
    { flip: true, edit: false, dismantle: false, unfold: false, float: false, create: false })
  assert.deepEqual(CardsModel.allowed(null, all, true, true),
    { flip: false, edit: false, dismantle: false, unfold: false, float: false, create: true })
})

test("hints list every key, off where it cannot act", () => {
  const pair = card(5, 3, [["0x3"], ["0x4"]], { kind: "pair", key: "pair:5" })
  assert.deepEqual(CardsModel.hints(CardsModel.allowed(pair, {}, true, true), t).map(h => [h.text, h.on]),
    [["v flip", true], ["e edit", true], ["d dismantle", true], ["u unfold", false], ["t float", false], ["n new", true]])
})

test("namedCard: the card a create just made, while the name still waits for it", () => {
  const made = card(7, 3, [["0x1"], ["0x2", "0x3"]])
  const other = card(8, 3, [["0x4"], ["0x5"]])
  const waiting = { faces: [["0x1"], ["0x2", "0x3"]], name: "Work", until: 1000 }
  assert.equal(CardsModel.namedCard([other, made], waiting, 500), made)
  // Not listed (yet): nothing to name.
  assert.equal(CardsModel.namedCard([other], waiting, 500), null)
  // Same windows in another order is another card.
  assert.equal(CardsModel.namedCard([card(9, 3, [["0x1"], ["0x3", "0x2"]])], waiting, 500), null)
  // Too late: whatever card has those windows now was not made by that create.
  assert.equal(CardsModel.namedCard([made], waiting, 1001), null)
  assert.equal(CardsModel.namedCard([made], null, 0), null)
})
