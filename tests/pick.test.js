// Run with: node --test tests/
const test = require("node:test")
const assert = require("node:assert/strict")
const { load } = require("./load.js")
const Pick = load("Pick.js")
const Builder = load("Builder.js")

const t = (s, a) => s.replace(/%(\d+)/g, (m, n) => (a && a[n - 1] !== undefined ? String(a[n - 1]) : m))
const win = (address, ws, at, size, extra) => Object.assign({ address, class: "a", at, size, workspace: { id: ws },
  floating: false, hidden: false, mapped: true, focusHistoryID: 5 }, extra || {})

test("rects: the shown windows of the workspace, relative to the monitor, floating on top", () => {
  const clients = [win("0x1", 3, [1920, 0], [960, 1080], { focusHistoryID: 2 }),
                   win("0x2", 3, [2200, 100], [400, 300], { floating: true, focusHistoryID: 3 }),
                   win("0x3", 3, [2880, 0], [960, 1080], { hidden: true }),
                   win("0x4", 4, [1920, 0], [960, 1080])]
  assert.deepEqual(Pick.rects(clients, 3, { x: 1920, y: 0 }).map(r => [r.address, r.x, r.y, r.w, r.h]),
    [["0x2", 280, 100, 400, 300], ["0x1", 0, 0, 960, 1080]])
})

test("hit finds the topmost window under the pointer", () => {
  const rects = [{ address: "0x2", x: 280, y: 100, w: 400, h: 300 }, { address: "0x1", x: 0, y: 0, w: 960, h: 1080 }]
  assert.equal(Pick.hit(rects, 300, 200), "0x2")
  assert.equal(Pick.hit(rects, 10, 10), "0x1")
  assert.equal(Pick.hit(rects, 2000, 10), "")
})

test("toggle adds to the active side and takes a picked window out", () => {
  let r = Pick.toggle(Builder.newDraft(3), "0x1", 1, t)
  assert.deepEqual(r.draft.faces, [[], ["0x1"]])
  assert.equal(Pick.faceOfPick(r.draft, "0x1"), 1)
  r = Pick.toggle(r.draft, "0x1", 0, t)
  assert.deepEqual(r.draft.faces, [[], []])
  assert.equal(Pick.faceOfPick(r.draft, "0x1"), -1)
})

test("pinChanged: true once the pinned monitor's workspace has moved on", () => {
  const pin = { name: "DP-1", x: 0, y: 0, workspace: 3 }
  assert.equal(Pick.pinChanged(pin, 3), false)
  assert.equal(Pick.pinChanged(pin, 5), true)
  // -1: no reading of the pinned monitor yet, never a change.
  assert.equal(Pick.pinChanged(pin, -1), false)
  assert.equal(Pick.pinChanged(null, 5), false)
})
