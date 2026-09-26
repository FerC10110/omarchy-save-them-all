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
  assert.deepEqual(d.card, { kind: "container", id: 1, faces: [["0x2"], ["0x3", "0x4"]], axes: ["row", "column"],
    ratios: [null, null] })
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

test("place: reordering forward within the same side lands right after the drop target", () => {
  // [A,B,C], drop A on B's right half (FaceBox computes index 2 against
  // the pre-removal array of 3): should read [B,A,C], not [B,C,A].
  let d = Builder.newDraft(3)
  for (const a of ["0xA", "0xB", "0xC"]) d = Builder.place(d, a, 0, -1, t).draft
  assert.deepEqual(d.faces[0], ["0xA", "0xB", "0xC"])
  const r = Builder.place(d, "0xA", 0, 2, t)
  assert.deepEqual(r.draft.faces[0], ["0xB", "0xA", "0xC"])
})

test("place: reordering backward within the same side needs no adjustment", () => {
  let d = Builder.newDraft(3)
  for (const a of ["0xA", "0xB", "0xC"]) d = Builder.place(d, a, 0, -1, t).draft
  const r = Builder.place(d, "0xC", 0, 0, t)
  assert.deepEqual(r.draft.faces[0], ["0xC", "0xA", "0xB"])
})

test("place: an index across faces is not shifted by the source face's removal", () => {
  let d = Builder.newDraft(3)
  d = Builder.place(d, "0x1", 0, -1, t).draft
  d = Builder.place(d, "0x2", 1, -1, t).draft
  const r = Builder.place(d, "0x1", 1, 0, t)
  assert.deepEqual(r.draft.faces, [[], ["0x1", "0x2"]])
})

test("facesKey/faceKey: equal for the same content across separate clones, and touch only the changed side", () => {
  const base = Builder.newDraft(3)
  const withFront = Builder.place(base, "0x1", 0, -1, t).draft
  const clonedAgain = Builder.place(base, "0x1", 0, -1, t).draft
  // Two independent clones with the same content compare equal…
  assert.equal(Builder.facesKey(withFront), Builder.facesKey(clonedAgain))
  assert.equal(Builder.faceKey(withFront, 0), Builder.faceKey(clonedAgain, 0))
  // …but differ from the draft before the change.
  assert.notEqual(Builder.facesKey(base), Builder.facesKey(withFront))
  assert.notEqual(Builder.faceKey(base, 0), Builder.faceKey(withFront, 0))
  // Placing on the front clones the back's array too, but its key (content)
  // stays the same: FaceBox must not rebuild the back's tiles for this.
  const withBack = Builder.place(withFront, "0x2", 1, -1, t).draft
  const withFrontAgain = Builder.place(withBack, "0x3", 0, -1, t).draft
  assert.equal(Builder.faceKey(withBack, 1), Builder.faceKey(withFrontAgain, 1))
  assert.notEqual(Builder.faceKey(withBack, 0), Builder.faceKey(withFrontAgain, 0))
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

// A native pair as the Hyprflip helper's snapshot lists it: kind "pair", one
// window a side, no layouts (so both axes read "horizontal"), both windows in
// one native group, the back shown.
const PAIR = { id: 5, kind: "pair", key: "pair:5", token: "p", workspace: 3, active: 1, floating: false,
  current: "0x7", unfolded: false,
  faces: [{ index: 0, axis: "horizontal", panes: [{ address: "0x6" }] },
          { index: 1, axis: "horizontal", panes: [{ address: "0x7" }] }] }

test("editDraft loads a native pair as a one-and-one draft that replaces it", () => {
  const d = Builder.editDraft(PAIR, "", null)
  assert.equal(d.mode, "edit")
  assert.deepEqual(d.card, { kind: "pair", id: 5, faces: [["0x6"], ["0x7"]], axes: ["row", "row"], ratios: [null, null] })
  assert.deepEqual(d.faces, [["0x6"], ["0x7"]])
  assert.deepEqual(d.axes, ["row", "row"])
  assert.equal(d.visible, 1)
  assert.equal(d.floating, null)
  assert.ok(Builder.ready(d))
  assert.deepEqual(Builder.request(d), { faces: [["address:0x6"], ["address:0x7"]], axes: ["row", "row"],
    ratios: null, visible: 1, floating: null })
  // Its own windows sit in a native group, and still may stay in the card.
  const ctx = Builder.context([CARD, PAIR], d, {})
  assert.equal(Builder.reason(win("0x7", "b", 3, { grouped: ["0x6", "0x7"], hidden: true }), ctx, t), "")
  assert.equal(Builder.reason(win("0x2", "a", 3), ctx, t), "Already in a card")
})

test("contextKey changes when the cards (or floating support) change, not on a rebuilt copy", () => {
  const d = Builder.newDraft(3)
  const a = Builder.contextKey(Builder.context([CARD], d, {}))
  assert.equal(a, Builder.contextKey(Builder.context(JSON.parse(JSON.stringify([CARD])), d, {})))
  // The card was taken apart: its windows are free, so the list must say so.
  assert.notEqual(a, Builder.contextKey(Builder.context([], d, {})))
  assert.notEqual(a, Builder.contextKey(Builder.context([CARD], d, { floating_members: true })))
})

// A snapshot card whose faces carry their layout's ratios (a helper that
// lists them): an edit keeps them where a side did not change.
const RATIOS = Object.assign({}, CARD, {
  faces: [{ axis: "horizontal", ratios: [1], panes: [{ address: "0x2" }] },
          { axis: "vertical", ratios: [0.7, 0.3], panes: [{ address: "0x3" }, { address: "0x4" }] }] })

test("request keeps a side's ratios while its windows and their order stay", () => {
  let d = Builder.editDraft(RATIOS, "", null)
  assert.deepEqual(Builder.request(d).ratios, [[1], [0.7, 0.3]])
  // Turning a side's axis keeps its proportions.
  assert.deepEqual(Builder.request(Builder.setAxis(d, 1, "row")).ratios, [[1], [0.7, 0.3]])
  // The back's order changed: that side starts equal, the front keeps its own.
  d = Builder.place(d, "0x4", 1, 0, t).draft
  assert.deepEqual(Builder.request(d).ratios, [[1], [0.5, 0.5]])
  // Nothing kept at all: null, the helper's "start equal".
  d = Builder.place(d, "0x9", 0, -1, t).draft
  assert.equal(Builder.request(d).ratios, null)
  // A snapshot without ratios (a helper before e0b985f), or with bad ones: null.
  assert.equal(Builder.request(Builder.editDraft(CARD, "", null)).ratios, null)
  const bad = Object.assign({}, RATIOS, { faces: [Object.assign({}, RATIOS.faces[0], { ratios: [0] }),
                                                   Object.assign({}, RATIOS.faces[1], { ratios: [1] })] })
  assert.equal(Builder.request(Builder.editDraft(bad, "", null)).ratios, null)
  assert.equal(Builder.request(Builder.place(Builder.newDraft(3), "0x1", 0, -1, t).draft).ratios, null)
})

test("nameOnly: an edit that changed nothing but the name", () => {
  const d = Builder.editDraft(CARD, "Notes", null)
  assert.equal(Builder.nameOnly(d), true)
  assert.equal(Builder.nameOnly(Object.assign({}, d, { name: "Work" })), true)
  assert.equal(Builder.nameOnly(Builder.setAxis(d, 0, "column")), false)
  assert.equal(Builder.nameOnly(Builder.place(d, "0x4", 1, 0, t).draft), false)
  assert.equal(Builder.nameOnly(Builder.remove(d, "0x4")), false)
  assert.equal(Builder.nameOnly(Builder.newDraft(3)), false)
  assert.equal(Builder.nameOnly(null), false)
})
