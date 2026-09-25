// Loads a plugin .js file the way QML does: its `.import "X.js" as X` lines
// become the other module, loaded the same way. node cannot parse `.import`
// or `.pragma`, so those lines are dropped and the names passed in.
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const ROOT = path.join(__dirname, "..")
const cache = {}

function load(file) {
  if (cache[file]) return cache[file]
  const lines = fs.readFileSync(path.join(ROOT, file), "utf8").split("\n")
  const imports = {}
  const body = lines.map(l => {
    const m = /^\.import\s+"([^"]+)"\s+as\s+(\w+)\s*$/.exec(l)
    if (m) { imports[m[2]] = load(m[1]); return "" }
    return /^\.pragma\b/.test(l) ? "" : l
  }).join("\n")
  // Same realm as the tests, so deepEqual sees plain objects and arrays.
  const module = { exports: {} }
  const names = Object.keys(imports)
  const fn = vm.runInThisContext("(function(module, " + names.join(", ") + ") {\n" + body + "\n})",
    { filename: file, lineOffset: -1 })
  fn(module, ...names.map(n => imports[n]))
  return (cache[file] = module.exports)
}

module.exports = { load }
