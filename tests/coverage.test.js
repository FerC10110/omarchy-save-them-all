// Run with: node --test tests/
// Every text the QML and JS show goes through t("…"), whose key is the
// English text. These tests keep STRINGS.es in step with the code: nothing
// shown untranslated, nothing translated that is no longer shown, and the
// same %N placeholders on both sides.
const test = require("node:test")
const assert = require("node:assert/strict")
const { load } = require("./load.js")
const { sources } = require("./sources.js")
const I18n = load("I18n.js")

const CALL = /\bt\(\s*"((?:[^"\\]|\\.)*)"/g
// Labels.js holds tables whose entries are translated as t(entry.label).
const LABEL = /\b(?:label|detail):\s*"((?:[^"\\]|\\.)*)"/g

function used() {
  const found = new Map()
  for (const f of sources([".qml", ".js"])) {
    if (f.name === "I18n.js") continue
    let m
    while ((m = CALL.exec(f.text))) found.set(JSON.parse('"' + m[1] + '"'), f.name)
    if (f.name === "Labels.js")
      while ((m = LABEL.exec(f.text))) found.set(JSON.parse('"' + m[1] + '"'), f.name)
  }
  return found
}

test("every text passed to t() has a Spanish translation", () => {
  const es = I18n.STRINGS.es
  const missing = [...used()].filter(([s]) => !Object.prototype.hasOwnProperty.call(es, s))
  assert.deepEqual(missing.map(([s, f]) => `${f}: ${s}`), [])
})

test("every Spanish translation is used by some t() call", () => {
  const u = used()
  assert.deepEqual(Object.keys(I18n.STRINGS.es).filter(k => !u.has(k)), [])
})

test("every translation keeps the %N placeholders of its key", () => {
  const marks = s => [...new Set(s.match(/%\d+/g) || [])].sort()
  for (const [k, v] of Object.entries(I18n.STRINGS.es))
    assert.deepEqual(marks(v), marks(k), `placeholders differ in "${k}"`)
})
