// Run with: node --test tests/
const test = require("node:test")
const assert = require("node:assert/strict")
const path = require("node:path")
const { load } = require("./load.js")
const { readEntries } = require("./desktop.js")
const AppNames = load("AppNames.js")

const entries = readEntries(path.join(__dirname, "fixtures", "applications"))

test("urlClass names a webapp the way Chromium does", () => {
  assert.equal(AppNames.urlClass("https://youtube.com/"), "chrome-youtube.com__-Default")
  assert.equal(AppNames.urlClass("https://app.example.com/a/b?x=1#y"), "chrome-app.example.com__a_b-Default")
  assert.equal(AppNames.urlClass("https://example.com"), "chrome-example.com__-Default")
})

test("webappUrl reads an omarchy-launch-webapp Exec line", () => {
  assert.equal(AppNames.webappUrl("omarchy-launch-webapp https://youtube.com/"), "https://youtube.com/")
  assert.equal(AppNames.webappUrl('omarchy-launch-webapp "https://a.com/100%%"'), "https://a.com/100%")
  assert.equal(AppNames.webappUrl("kitty"), "")
})

test("a webapp gets its desktop entry's name and icon", () => {
  const r = AppNames.resolve({ class: "chrome-youtube.com__-Default" }, entries)
  assert.deepEqual(r, { name: "YouTube", icon: "/home/test/.local/share/applications/icons/YouTube.png", source: "webapp" })
})

test("a saved webapp is found by its URL even if the class was never seen", () => {
  const r = AppNames.resolve({ class: "chrome-other__-Default", launch: { kind: "webapp", url: "https://youtube.com/" } }, entries)
  assert.equal(r.name, "YouTube")
})

test("an unknown webapp is named after its host", () => {
  assert.deepEqual(AppNames.resolve({ class: "chrome-www.tradingview.com__chart_-Default" }, entries),
    { name: "www.tradingview.com", icon: "", source: "class" })
})

test("an app is found by StartupWMClass, ignoring case", () => {
  assert.deepEqual(AppNames.resolve({ class: "org.gnome.calculator" }, entries),
    { name: "Calculator", icon: "org.gnome.Calculator", source: "entry" })
})

test("an app is found by an entry id equal to its class", () => {
  assert.deepEqual(AppNames.resolve({ class: "obsidian" }, entries), { name: "Obsidian", icon: "obsidian", source: "entry" })
})

test("a reverse-DNS class with no entry keeps its last part", () => {
  assert.deepEqual(AppNames.resolve({ class: "org.omarchy.btop" }, entries), { name: "btop", icon: "", source: "class" })
})

test("anything else is the class itself", () => {
  assert.deepEqual(AppNames.resolve({ class: "weird" }, entries), { name: "weird", icon: "", source: "raw" })
  assert.deepEqual(AppNames.resolve({}, []), { name: "", icon: "", source: "raw" })
})
