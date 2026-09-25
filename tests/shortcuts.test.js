// Run with: node --test tests/
const test = require("node:test")
const assert = require("node:assert/strict")
const { load } = require("./load.js")
const Shortcuts = load("Shortcuts.js")
const Labels = load("Labels.js")

const t = (s, a) => s.replace(/%(\d+)/g, (m, n) => (a && a[n - 1] !== undefined ? String(a[n - 1]) : m))
const META = 0x10000000, CTRL = 0x04000000, ALT = 0x08000000, SHIFT = 0x02000000

test("chord names the modifiers in Hyprland's order", () => {
  assert.equal(Shortcuts.chord(76, "F", t), "Super+Ctrl+Alt+F")
  assert.equal(Shortcuts.chord(65, "space", t), "Super+Shift+Space")
  assert.equal(Shortcuts.chord(4, "Escape", t), "Ctrl+Esc")
})

test("capture turns a key press into a mask and a key", () => {
  assert.deepEqual(Shortcuts.capture(0x46, META | CTRL | ALT, false, t), { mask: 76, key: "F" })
  assert.deepEqual(Shortcuts.capture(0x01000031, META, false, t), { mask: 64, key: "F2" })
  assert.deepEqual(Shortcuts.capture(0x01000012, CTRL | SHIFT, false, t), { mask: 5, key: "Left" })
  assert.deepEqual(Shortcuts.capture(0x01000021, CTRL, false, t), { ignore: true })
  assert.deepEqual(Shortcuts.capture(0x46, META, true, t), { ignore: true })
  assert.deepEqual(Shortcuts.capture(0x01000000, 0, false, t), { cancel: true })
  assert.deepEqual(Shortcuts.capture(0x46, SHIFT, false, t), { error: "Include Super, Ctrl or Alt." })
  assert.deepEqual(Shortcuts.capture(0xe9, META, false, t), { error: "Use a letter, a number, a function key or a navigation key." })
})

test("conflict finds who already uses a chord", () => {
  const occupied = [
    { id: "flip", mask: 76, key: "F", keycode: 0, submap: "", universal: false, label: "Voltear tarjeta" },
    { id: null, mask: 64, key: "RETURN", keycode: 0, submap: "", universal: false, label: "Terminal" },
    { id: null, mask: 12, key: "", keycode: 36, submap: "", universal: false, label: "Physical" },
    { id: null, mask: 64, key: "Q", keycode: 0, submap: "resize", universal: false, label: "In a submap" },
  ]
  const labelOf = b => b.label
  assert.equal(Shortcuts.conflict(occupied, "peek", 64, "return", t, labelOf), "Used by Terminal. Choose another shortcut.")
  assert.equal(Shortcuts.conflict(occupied, "flip", 76, "F", t, labelOf), "")
  assert.equal(Shortcuts.conflict(occupied, "peek", 12, "P", t, labelOf), "A physical-key shortcut uses these modifiers. Choose other modifiers.")
  assert.equal(Shortcuts.conflict(occupied, "peek", 64, "Q", t, labelOf), "")
})

test("every Hyprflip shortcut and transition has our own label", () => {
  for (const id of ["flip", "create", "edit", "library", "find", "peek", "unpair", "mark", "pair", "attach_h", "attach_v", "release", "cancel"])
    assert.notEqual(Labels.shortcutLabel(id, ""), "", id)
  assert.equal(Labels.shortcutLabel("something-new", "Algo nuevo"), "Algo nuevo")
  const modes = ["flip", "vertical", "slide", "fade", "dissolve", "portal", "instant"]
  assert.deepEqual(Labels.transitions(modes).map(x => x.value), modes)
  assert.deepEqual(Labels.transitions(["instant", "flip", "warp"]).map(x => x.value), ["flip", "instant"])
})
