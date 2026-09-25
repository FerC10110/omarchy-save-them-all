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
    "Front": "Frente",
    "Back": "Reverso",
    "Showing": "Visible",
    "Row": "Fila",
    "Column": "Columna",
    "＋ drop here": "＋ soltá acá",
    "Edit card": "Editar tarjeta",
    "New card": "Nueva tarjeta",
    "Workspace %1 · %2 windows": "Escritorio %1 · %2 ventanas",
    "Windows": "Ventanas",
    "Special workspaces": "Escritorios especiales",
    "These windows will move to workspace %1: %2": "Estas ventanas van a pasar al escritorio %1: %2",
    "Drag a window onto a side, or pick it with j/k and press f (Front) or r (Back). x takes it out; e picks on screen.": "Arrastrá una ventana a una cara, o elegila con j/k y apretá f (Frente) o r (Reverso). x la saca; e elige en pantalla.",
    "Pick on screen": "Elegir en pantalla",
    "Could not open pick on screen.": "No se pudo abrir Elegir en pantalla.",
    "Adding to: %1": "Sumando a: %1",
    "%1 picked": "%1 elegidas",
    "Click a window to add or take it out · Tab switches side · Enter goes back with them · Esc goes back without changes": "Clic en una ventana para sumarla o sacarla · Tab cambia de cara · Enter vuelve con lo elegido · Esc vuelve sin cambios",
    "Card name (optional)": "Nombre de la tarjeta (opcional)",
    "Cancel": "Cancelar",
    "Put at least one window on each side.": "Poné al menos una ventana en cada cara.",
    "Hyprflip is busy; try again in a moment.": "Hyprflip está ocupado; probá de nuevo en un momento.",
    "The card could not be made.": "No se pudo armar la tarjeta.",
    "%1 closed and left the card.": "%1 se cerró y salió de la tarjeta.",
    "Changes saved.": "Cambios guardados.",
    "Card created.": "Tarjeta creada.",
    "Cards": "Tarjetas",
    "Unfolded": "Desplegada",
    "Floating": "Flotante",
    "Tiled": "Mosaico",
    "Front: %1": "Frente: %1",
    "Back: %1": "Reverso: %1",
    "Cards need Hyprflip": "Las tarjetas necesitan Hyprflip",
    "Check again": "Revisar de nuevo",
    "Working…": "Trabajando…",
    "No cards yet. Press n to make one.": "Todavía no hay tarjetas. Apretá n para armar una.",
    "Flip": "Voltear",
    "Edit": "Editar",
    "Dismantle": "Desarmar",
    "Creating and editing cards needs the updated Hyprflip helper.": "Crear y editar tarjetas necesita el asistente de Hyprflip actualizado.",
    "Dismantling needs the updated Hyprflip helper.": "Desarmar necesita el asistente de Hyprflip actualizado.",
    "v flip · e edit · d dismantle · u unfold · t float · n new": "v voltear · e editar · d desarmar · u desplegar · t flotar · n nueva",
    "Card taken apart; its windows stay open.": "Tarjeta desarmada; sus ventanas siguen abiertas.",
    "Settings": "Ajustes",
    "Turns sideways": "Gira de costado",
    "Vertical": "Vertical",
    "Turns top to bottom": "Gira de arriba abajo",
    "Slide": "Deslizar",
    "The sides slide across": "Las caras se deslizan de costado",
    "Fade": "Fundido",
    "The sides fade into each other": "Las caras se funden suavemente",
    "Dissolve": "Disolver",
    "Experimental · Reveals in soft fragments": "Experimental · Aparece en fragmentos suaves",
    "Portal": "Portal",
    "Experimental · Reveals from the center": "Experimental · Aparece desde el centro",
    "Instant": "Instantánea",
    "Switches without animation": "Cambia sin animación",
    "Fast": "Rápida",
    "Normal": "Normal",
    "Slow": "Pausada",
    "Classic tabs": "Pestañas clásicas",
    "Tab bars over tiled cards": "Barras de pestañas sobre las tarjetas en mosaico",
    "Card frame": "Marco de tarjeta",
    "A shared outline and a small Flip control · Experimental": "Un contorno compartido y un pequeño control Voltear · Experimental",
    "Desktop spacing": "Espaciado de escritorio",
    "The same gaps as other tiled windows": "Los mismos huecos que las demás ventanas en mosaico",
    "Compact spacing": "Espaciado compacto",
    "12 px between the apps of a card": "12 px entre las apps de una tarjeta",
    "Automatic": "Automático",
    "English": "English",
    "Español": "Español",
    "Flip the card": "Voltear la tarjeta",
    "Create a card": "Crear una tarjeta",
    "Edit the card": "Editar la tarjeta",
    "Card library": "Biblioteca de tarjetas",
    "Find an app": "Buscar una app",
    "Peek at the other side": "Espiar la otra cara",
    "Take the card apart": "Desarmar la tarjeta",
    "Mark an app": "Marcar una app",
    "Pair with the marked app": "Emparejar con la app marcada",
    "Attach side by side": "Unir lado a lado",
    "Attach stacked": "Unir apiladas",
    "Release an app": "Soltar una app",
    "Space": "Espacio",
    "Include Super, Ctrl or Alt.": "Incluí Super, Ctrl o Alt.",
    "Use a letter, a number, a function key or a navigation key.": "Usá una letra, un número, una tecla de función o de navegación.",
    "A physical-key shortcut uses these modifiers. Choose other modifiers.": "Un atajo de tecla física usa estos modificadores. Elegí otros.",
    "Used by %1. Choose another shortcut.": "Lo usa %1. Elegí otro atajo.",
    "Language": "Idioma",
    "Card appearance": "Apariencia de la tarjeta",
    "Space between apps": "Espacio entre apps",
    "Animation": "Animación",
    "Speed": "Velocidad",
    "%1 ms": "%1 ms",
    "Shortcuts": "Atajos",
    "Keyboard shortcuts": "Atajos de teclado",
    "Change a shortcut or bring back the default": "Cambiá un atajo o volvé al predeterminado",
    "Hyprflip %1 on Hyprland %2": "Hyprflip %1 sobre Hyprland %2",
    "Hyprflip is not available": "Hyprflip no está disponible",
    "Everything is in order. Press Enter to check again.": "Todo en orden. Apretá Enter para revisar de nuevo.",
    "To add an app to a card, drag its window onto the card's “Drop to add” area. Esc cancels.": "Para sumar una app a una tarjeta, arrastrá su ventana a la zona “Suelta para añadir” de la tarjeta. Esc cancela.",
    "Not assigned": "Sin asignar",
    "Not editable here": "No se edita acá",
    "Pick an action to change its shortcut.": "Elegí una acción para cambiar su atajo.",
    "Update Hyprflip's guided setup to edit shortcuts.": "Actualizá la configuración guiada de Hyprflip para editar atajos.",
    "Press the new shortcut. Esc cancels.": "Apretá el atajo nuevo. Esc cancela.",
    "Listening…": "Escuchando…",
    "Record shortcut": "Grabar atajo",
    "Use default": "Usar el predeterminado",
    "Save shortcut": "Guardar atajo",
    "Enter saves this shortcut · d for the default · Esc cancels.": "Enter guarda este atajo · d para el predeterminado · Esc cancela.",
    "Enter records a new shortcut · d for the default · Esc cancels.": "Enter graba un atajo nuevo · d para el predeterminado · Esc cancela.",
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
