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
    "Hyprland is not answering, so cards are paused.": "Hyprland no responde, así que las tarjetas están en pausa.",
    "Hyprflip is not loaded. Install it with: %1": "Hyprflip no está cargado. Instalalo con: %1",
    "Hyprflip did not load: Hyprland is %1 and Hyprflip was built for %2. Rebuild it with: %3": "Hyprflip no cargó: Hyprland es %1 y Hyprflip se compiló para %2. Recompilalo con: %3",
    "The Hyprflip helper is not installed. Install it with: %1": "El asistente de Hyprflip no está instalado. Instalalo con: %1",
    "The Hyprflip helper speaks another protocol. Update it with: %1": "El asistente de Hyprflip habla otro protocolo. Actualizalo con: %1",
    "The Hyprflip helper reports: %1": "El asistente de Hyprflip dice: %1",
    "Checking Hyprflip…": "Revisando Hyprflip…",
    "The Hyprflip helper sent an unreadable answer.": "El asistente de Hyprflip mandó una respuesta ilegible.",
    "Could not switch to workspace %1.": "No se pudo pasar al escritorio %1.",
    "That card changed; look at it again.": "Esa tarjeta cambió; volvé a mirarla.",
    "Hyprflip asked something this panel cannot answer; the action was cancelled.": "Hyprflip preguntó algo que este panel no sabe responder; se canceló la acción.",
    "The Hyprflip helper stopped. Try again.": "El asistente de Hyprflip se detuvo. Probá de nuevo.",
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
