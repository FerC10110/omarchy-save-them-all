// Every plugin file with one of the given extensions, as { name, text }:
// what the coverage test scans. tests/ and docs/ are not part of the plugin.
const fs = require("node:fs")
const path = require("node:path")

const ROOT = path.join(__dirname, "..")
const SKIP = new Set(["tests", "docs", "node_modules", ".git", ".superpowers"])

function sources(exts) {
  const out = []
  const walk = dir => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      if (SKIP.has(e.name)) continue
      const p = path.join(dir, e.name)
      if (e.isDirectory()) walk(p)
      else if (exts.some(x => e.name.endsWith(x))) out.push({ name: path.relative(ROOT, p), text: fs.readFileSync(p, "utf8") })
    }
  }
  walk(ROOT)
  return out
}

module.exports = { sources }
