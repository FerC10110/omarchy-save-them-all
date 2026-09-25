// Reads the .desktop files of a directory into the shape AppNames.resolve
// takes, the same fields QML gets from DesktopEntries.
const fs = require("node:fs")
const path = require("node:path")

function readEntries(dir) {
  return fs.readdirSync(dir).filter(f => f.endsWith(".desktop")).sort().map(f => {
    const fields = {}
    let section = ""
    for (const raw of fs.readFileSync(path.join(dir, f), "utf8").split("\n")) {
      const line = raw.trim()
      if (line.startsWith("[")) section = line
      else if (section === "[Desktop Entry]" && line.includes("=")) {
        const i = line.indexOf("=")
        const key = line.slice(0, i).trim()
        if (!(key in fields)) fields[key] = line.slice(i + 1).trim()
      }
    }
    return { id: f, name: fields.Name || "", icon: fields.Icon || "",
             startupClass: fields.StartupWMClass || "", exec: fields.Exec || "" }
  })
}

module.exports = { readEntries }
