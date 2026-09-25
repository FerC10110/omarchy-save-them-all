// Run with: node --test tests/
const test = require("node:test")
const assert = require("node:assert/strict")
const { load } = require("./load.js")
const Builder = load("Builder.js")

const t = (s, a) => s.replace(/%(\d+)/g, (m, n) => (a && a[n - 1] !== undefined ? String(a[n - 1]) : m))
const win = (address, cls, ws, extra) => Object.assign({ address, class: cls, title: cls, at: [0, 0], size: [800, 600],
  workspace: { id: ws, name: String(ws) }, floating: false, hidden: false, grouped: [], fullscreen: 0, pinned: false,
  mapped: true, focusHistoryID: 1 }, extra || {})
const appName = w => w.class
const CARD = { id: 1, kind: "container", token: "t", workspace: 3, active: 1, floating: false, current: "0x3",
  faces: [{ axis: "horizontal", panes: [{ address: "0x2" }] }, { axis: "vertical", panes: [{ address: "0x3" }, { address: "0x4" }] }] }

test("newDraft starts empty on its workspace", () => {
  assert.deepEqual(Builder.newDraft(3), { mode: "create", card: null, workspace: 3, faces: [[], []], axes: ["row", "row"],
    visible: 0, floating: null, name: "", cursor: "" })
})

test("editDraft loads a card: sides, axes, the visible side and where it floats", () => {
  const d = Builder.editDraft(CARD, "Notes", null)
  assert.deepEqual(d.faces, [["0x2"], ["0x3", "0x4"]])
  assert.deepEqual(d.axes, ["row", "column"])
  assert.equal(d.visible, 1)
  assert.deepEqual(d.card, { kind: "container", id: 1, faces: [["0x2"], ["0x3", "0x4"]] })
  assert.equal(d.name, "Notes")
  const f = Builder.editDraft(Object.assign({}, CARD, { floating: true }), "", { at: [10, 20], size: [800, 600] })
  assert.deepEqual(f.floating, { at: [10, 20], size: [800, 600] })
})

test("reason says why a window cannot join", () => {
  const ctx = Builder.context([CARD], Builder.newDraft(3), {})
  assert.equal(Builder.reason(win("0x2", "a", 3), ctx, t), "Already in a card")
  assert.equal(Builder.reason(win("0x9", "a", 3, { fullscreen: 2 }), ctx, t), "Fullscreen")
  assert.equal(Builder.reason(win("0x9", "a", -98), ctx, t), "On a special workspace")
  assert.equal(Builder.reason(win("0x9", "org.quickshell", 3), ctx, t), "This panel")
  assert.equal(Builder.reason(win("0x9", "a", 3, { grouped: ["0x9", "0x8"] }), ctx, t), "In a window group")
  assert.equal(Builder.reason(win("0x9", "a", 3, { pinned: true }), ctx, t), "Pinned")
  assert.equal(Builder.reason(win("0x9", "a", 3, { floating: true }), ctx, t), "Floating; Hyprflip needs it tiled")
  assert.equal(Builder.reason(win("0x9", "a", 3, { floating: true }), Builder.context([], Builder.newDraft(3), { floating_members: true }), t), "")
  assert.equal(Builder.reason(win("0x9", "a", 3), ctx, t), "")
})

test("the card being edited does not stand in the way of its own windows", () => {
  const ctx = Builder.context([CARD], Builder.editDraft(CARD, "", null), {})
  assert.equal(Builder.reason(win("0x3", "b", 3, { hidden: true, grouped: ["0x2", "0x3", "0x4"] }), ctx, t), "")
})

test("candidates: this workspace first, then the others, then the special ones", () => {
  const clients = [win("0x5", "e", 5), win("0x1", "a", 3, { at: [900, 0] }), win("0x6", "f", -98), win("0x7", "g", 1), win("0x8", "h", 3)]
  const draft = Builder.place(Builder.newDraft(3), "0x8", 1, -1, t).draft
  const groups = Builder.candidates(clients, draft, Builder.context([], draft, {}), t)
  assert.deepEqual(groups.map(g => [g.workspace, g.current]), [[3, true], [1, false], [5, false], [-98, false]])
  assert.deepEqual(groups[0].windows.map(w => [w.address, w.face]), [["0x8", 1], ["0x1", -1]])
  assert.equal(groups[3].windows[0].reason, "On a special workspace")
})

test("place moves a window between sides and keeps the order asked", () => {
  let d = Builder.newDraft(3)
  d = Builder.place(d, "0x1", 0, -1, t).draft
  d = Builder.place(d, "0x2", 0, 0, t).draft
  assert.deepEqual(d.faces, [["0x2", "0x1"], []])
  d = Builder.place(d, "0x2", 1, -1, t).draft
  assert.deepEqual(d.faces, [["0x1"], ["0x2"]])
  assert.equal(d.cursor, "0x2")
  d = Builder.place(d, "0x1", 1, 0, t).draft
  assert.deepEqual(d.faces, [[], ["0x1", "0x2"]])
})

test("a side holds up to five windows", () => {
  let d = Builder.newDraft(3)
  for (const a of ["0x1", "0x2", "0x3", "0x4", "0x5"]) d = Builder.place(d, a, 0, -1, t).draft
  const r = Builder.place(d, "0x6", 0, -1, t)
  assert.equal(r.problem, "A side holds up to 5 windows.")
  assert.deepEqual(r.draft, d)
  assert.deepEqual(Builder.place(d, "0x5", 0, 0, t).draft.faces[0], ["0x5", "0x1", "0x2", "0x3", "0x4"])
})

test("prune removes closed windows and says which", () => {
  let d = Builder.place(Builder.place(Builder.newDraft(3), "0x1", 0, -1, t).draft, "0x2", 1, -1, t).draft
  d = Builder.place(d, "0x3", 1, -1, t).draft
  const r = Builder.prune(d, [win("0x1", "a", 3), win("0x3", "c", 3)])
  assert.deepEqual(r.gone, ["0x2"])
  assert.deepEqual(r.draft.faces, [["0x1"], ["0x3"]])
  assert.deepEqual(Builder.prune(r.draft, [win("0x1", "a", 3), win("0x3", "c", 3)]).gone, [])
})

test("request names every window by address; ratios start equal", () => {
  let d = Builder.editDraft(CARD, "Notes", null)
  d = Builder.setAxis(d, 0, "column")
  assert.ok(Builder.ready(d))
  assert.deepEqual(Builder.request(d), { faces: [["address:0x2"], ["address:0x3", "address:0x4"]],
    axes: ["column", "column"], ratios: null, visible: 1, floating: null })
  assert.ok(!Builder.ready(Builder.newDraft(3)))
})

test("movesFrom lists the windows that will change workspace", () => {
  const d = Builder.place(Builder.place(Builder.newDraft(3), "0x1", 0, -1, t).draft, "0x5", 1, -1, t).draft
  assert.deepEqual(Builder.movesFrom(d, { "0x1": win("0x1", "a", 3), "0x5": win("0x5", "e", 5) }), ["0x5"])
})

test("twins get where they are on screen", () => {
  const left = win("0x1", "kitty", 3, { at: [0, 0], size: [960, 1080] })
  const top = win("0x2", "kitty", 3, { at: [960, 0], size: [960, 540] })
  const bottom = win("0x3", "kitty", 3, { at: [960, 540], size: [960, 540] })
  const all = [left, top, bottom, win("0x4", "other", 3)]
  assert.deepEqual(Builder.twinWords(left, all, appName), ["left", "middle"])
  assert.deepEqual(Builder.twinWords(top, all, appName), ["right", "top"])
  assert.deepEqual(Builder.twinWords(win("0x4", "other", 3), all, appName), [])
  assert.equal(Builder.label(bottom, all, appName, t), "kitty · right bottom")
  assert.equal(Builder.label(all[3], all, appName, t), "other")
})

test("slotAspect is the shape of the first front window, 16:9 without one", () => {
  const d = Builder.place(Builder.newDraft(3), "0x1", 0, -1, t).draft
  assert.equal(Builder.slotAspect(d, { "0x1": win("0x1", "a", 3, { size: [960, 1080] }) }), 960 / 1080)
  assert.equal(Builder.slotAspect(Builder.newDraft(3), {}), 16 / 9)
})

test("submitText follows the mode", () => {
  assert.equal(Builder.submitText(Builder.newDraft(3), t), "Create card")
  assert.equal(Builder.submitText(Builder.editDraft(CARD, "", null), t), "Save changes")
})
