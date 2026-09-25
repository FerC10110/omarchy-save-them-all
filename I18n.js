// The text the Save Them All panel shows, in English and Spanish. The key is
// the English string, so English costs nothing: a text with no translation
// comes back as it went in. `%1`, `%2`… take the values in `args`, and a
// translation can put them in a different order.
//
// The scripts in bin/ translate their own messages (bin/messages.es.json);
// this table only covers what the QML and JS write.
//
// No QML in here, so node can test it; QML ignores the module.exports block.

var STRINGS = {
  es: {
  }
}

// text: the English string. lang: "en" or "es"; anything else is English.
// args: the values for %1, %2, … in order.
function t(text, lang, args) {
  var table = STRINGS[lang]
  // hasOwnProperty, not `table[text] || text`: a text like "constructor"
  // would otherwise find Object.prototype.
  var out = (table && Object.prototype.hasOwnProperty.call(table, text)) ? table[text] : text
  // Single pass: a value that contains %2 is not substituted again, and %10
  // is not mangled while filling %1. %0 and out-of-range markers stay.
  return String(out).replace(/%(\d+)/g, function(match, digits) {
    var n = Number(digits)
    if (n === 0 || !args || n > args.length) return match
    return String(args[n - 1])
  })
}

// setting: "auto" | "en" | "es" (settings.json). system: LC_ALL, LC_MESSAGES
// or LANG, the first one set. The scripts resolve it the same way.
function resolveLang(setting, system) {
  if (setting === "en" || setting === "es") return setting
  return String(system || "").indexOf("es") === 0 ? "es" : "en"
}

if (typeof module !== "undefined") {
  module.exports = { STRINGS: STRINGS, t: t, resolveLang: resolveLang }
}
