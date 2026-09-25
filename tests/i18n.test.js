// Run with: node --test tests/
const test = require("node:test")
const assert = require("node:assert/strict")
const { load } = require("./load.js")
const I18n = load("I18n.js")

test("English is the key and comes back as it went in", () => {
  assert.equal(I18n.t("No such text anywhere", "en"), "No such text anywhere")
  assert.equal(I18n.t("No such text anywhere", "es"), "No such text anywhere")
})

test("%N takes its value in one pass", () => {
  assert.equal(I18n.t("%1 and %2", "en", ["%2", "b"]), "%2 and b")
  assert.equal(I18n.t("%1 %0 %3", "en", ["a"]), "a %0 %3")
  assert.equal(I18n.t("%10", "en", ["x"]), "%10")
})

test("a key named like an Object property is not a translation", () => {
  assert.equal(I18n.t("constructor", "es"), "constructor")
})

test("resolveLang: an explicit choice wins, auto follows the system", () => {
  assert.equal(I18n.resolveLang("es", "en_US.UTF-8"), "es")
  assert.equal(I18n.resolveLang("en", "es_AR.UTF-8"), "en")
  assert.equal(I18n.resolveLang("auto", "es_AR.UTF-8"), "es")
  assert.equal(I18n.resolveLang("auto", "C.UTF-8"), "en")
  assert.equal(I18n.resolveLang("", ""), "en")
})
