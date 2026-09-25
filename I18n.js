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
    "Workspace": "Escritorio",
    "Workspace %1": "Escritorio %1",
    "No workspace": "Sin escritorio",
    "1 window": "1 ventana",
    "%1 windows": "%1 ventanas",
    "1 card": "1 tarjeta",
    "%1 cards": "%1 tarjetas",
    "earlier": "antes",
    "saved %1": "guardado %1",
    "Saving…": "Guardando…",
    "Restoring…": "Restaurando…",
    "Nothing saved for this workspace yet.": "Todavía no hay nada guardado para este escritorio.",
    "Something went wrong. Check the notification.": "Algo salió mal. Mirá la notificación.",
    "Cards paused": "Tarjetas en pausa",
    "Show both faces": "Mostrar las dos caras",
    "Take this workspace's windows out of their groups so none stays hidden": "Sacar las ventanas de este escritorio de sus grupos para que ninguna quede escondida",
    "Save them all": "Guardar todas",
    "Save every window on this workspace (s)": "Guardar todas las ventanas de este escritorio (s)",
    "Restore them all": "Restaurar todas",
    "Reopen the saved layout (r)": "Volver a abrir lo guardado (r)",
    "Restore at login": "Restaurar al iniciar",
    "this workspace": "este escritorio",
    "Leaving the session": "Al salir de la sesión",
    "Close the browser cleanly": "Cerrar el navegador limpio",
    "Your Omarchy menu already changes %1, so this stays off.": "Tu menú de Omarchy ya cambia %1, así que esto queda apagado.",
    "Before Logout, Reboot and Shutdown, so it brings its tabs back. Edits the Omarchy menu.": "Antes de Cerrar sesión, Reiniciar y Apagar, para que recupere sus pestañas. Edita el menú de Omarchy.",
    "Already in a card": "Ya está en una tarjeta",
    "Fullscreen": "Pantalla completa",
    "On a special workspace": "En un escritorio especial",
    "This panel": "Este panel",
    "In a window group": "En un grupo de ventanas",
    "Pinned": "Fijada",
    "Floating; Hyprflip needs it tiled": "Flotante; Hyprflip la necesita en mosaico",
    "A side holds up to %1 windows.": "Una cara admite hasta %1 ventanas.",
    "left": "izquierda",
    "right": "derecha",
    "center": "centro",
    "top": "arriba",
    "bottom": "abajo",
    "middle": "medio",
    "Save changes": "Guardar cambios",
    "Create card": "Crear tarjeta",
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
