.import "Labels.js" as Labels

// The Hyprflip helper (control.py) speaks Spanish only. In English, the
// panel shows its known messages in English: what its panel actions (flip,
// unfold, float, create, take apart, and the preferences) answer when they
// end, and the refusals they are likely to meet on the way. Anything not
// listed here, and any message whose shape changed, passes through as the
// helper wrote it. No QML in here, so node can test it.

var EXACT = {
  // What an action says when it ends.
  "Tarjeta creada.": "Card created.",
  "Tarjeta editada.": "Card edited.",
  "Tarjeta desarmada. Sus apps siguen abiertas.": "Card taken apart. Its apps stay open.",
  "Animación actualizada para todas las tarjetas.": "Animation updated for every card.",
  "Apariencia actualizada para todas las tarjetas.": "Appearance updated for every card.",
  "Espaciado entre apps actualizado para todas las tarjetas.": "Space between apps updated for every card.",
  "Cancelado. Las apps ya abiertas no se cierran.": "Cancelled. Apps that are already open stay open.",
  // Go to the workspace; the card or the focus changed underneath.
  "Ve al espacio de trabajo de esta tarjeta antes de editarla.": "Go to this card's workspace before changing it.",
  "La tarjeta cambió. Actualiza Tarjetas antes de editarla.": "The card changed. Refresh the list before changing it.",
  "La tarjeta cambió mientras giraba. Vuelve a abrir Tarjetas.": "The card changed while it turned. Try again.",
  "El espacio de trabajo cambió. Abre Tarjetas en el espacio de trabajo que quieras.": "The workspace changed. Try again on the workspace you want.",
  "El foco cambió. Abre Tarjetas para la app que quieras.": "The focus changed. Try again.",
  "Hyprland se reinició. Vuelve a abrir Tarjetas.": "Hyprland restarted. Try again.",
  "La app original se cerró o se movió. Vuelve a abrir Tarjetas.": "The app that was in focus closed or moved. Try again.",
  "Vuelve a abrir Tarjetas para elegir un destino.": "Try again to choose where.",
  "Elige primero una tarjeta.": "Choose a card first.",
  // Busy or animating.
  "Espera a que termine el giro e inténtalo de nuevo.": "Wait for the flip to finish and try again.",
  "El giro no ha terminado. Vuelve a la tarjeta.": "The flip has not finished. Go back to the card.",
  "No se pudo mostrar la otra cara. Vuelve a abrir Tarjetas.": "The other side could not be shown. Try again.",
  // Not available.
  "Hyprflip no está disponible. Carga el plugin de contenedores e inténtalo de nuevo.": "Hyprflip is not available. Load the containers plugin and try again.",
  "Las tarjetas no están disponibles. Carga primero el plugin de Hyprflip.": "Cards are not available. Load the Hyprflip plugin first.",
  "La acción de la tarjeta no está disponible.": "That card action is not available.",
  "Elige una acción de tarjeta disponible.": "Choose a card action that is available.",
  "Crea una tarjeta con varias apps con O para usar estos controles.": "This only works on a card made of several apps.",
  "Esta versión de Hyprflip no tiene tarjetas flotantes. Actualiza Hyprflip.": "This Hyprflip has no floating cards. Update Hyprflip.",
  "OmaCards y el asistente de Hyprflip necesitan versiones de protocolo coincidentes.": "Save Them All and the Hyprflip helper need the same protocol version.",
  "El editor de tarjetas cambió. Actualiza OmaCards y el asistente de Hyprflip a la vez.": "The card editor changed. Update Save Them All and the Hyprflip helper together.",
  "Hyprland no responde.": "Hyprland is not answering.",
  // A window cannot be used.
  "La ventana seleccionada ya no está disponible.": "The chosen window is gone.",
  "La ventana no pudo recibir el foco. Cierra cualquier superposición a pantalla completa e inténtalo de nuevo.": "The window could not take the focus. Close any fullscreen overlay and try again.",
  "Una de las apps elegidas se cerró. Vuelve a elegir las apps.": "One of the chosen apps closed. Choose the apps again.",
  "Una app no puede estar dos veces en la tarjeta.": "An app cannot be twice in the card.",
  "Una ventana seleccionada se cerró, se movió o se unió a un grupo. Vuelve a abrir la configuración.": "A chosen window closed, moved or joined a group. Try again.",
  "El espacio de trabajo cambió. Vuelve a la ventana del frente y abre de nuevo la configuración.": "The workspace changed. Go back to the front window and try again.",
  "Cierra la superposición a pantalla completa de este espacio de trabajo y vuelve a abrir la configuración.": "Close the fullscreen overlay on this workspace and try again.",
  "La disposición de la tarjeta cambió. Vuelve a abrir la configuración en un espacio de trabajo compatible.": "The card's layout changed. Try again on a workspace that supports cards.",
  "No se pudo crear la tarjeta. Vuelve a abrir la configuración.": "The card could not be made. Try again.",
  "La app no pudo moverse al espacio de trabajo de la tarjeta. Abre el selector e inténtalo de nuevo.": "The app could not move to the card's workspace. Try again.",
  "La app no pudo permanecer dentro de la disposición de la tarjeta. Revisa su regla de ventana flotante e inténtalo de nuevo.": "The app could not stay inside the card's layout. Check its floating window rule and try again.",
  // Preferences.
  "Elige una transición disponible.": "Choose a transition that is available.",
  "Elige una transición del menú.": "Choose a transition from the list.",
  "No se pudo aplicar la preferencia de transición.": "The transition could not be applied.",
  "Elige una duración entre 0 y 2000 milisegundos.": "Choose a duration between 0 and 2000 milliseconds.",
  "No se pudo leer la duración actual.": "The current duration could not be read.",
  "No se pudo aplicar la duración.": "The duration could not be applied.",
  "Elige Pestañas clásicas o Marco de tarjeta.": "Choose Classic tabs or Card frame.",
  "Actualiza Hyprflip para cambiar aquí la apariencia de las tarjetas.": "Update Hyprflip to change the card appearance here.",
  "No se pudo aplicar la apariencia de la tarjeta.": "The card appearance could not be applied.",
  "Elige el espaciado del escritorio o un hueco entre 0 y 128 píxeles.": "Choose the desktop spacing or a gap between 0 and 128 pixels.",
  "Actualiza Hyprflip para cambiar el espaciado entre apps.": "Update Hyprflip to change the space between apps.",
  "No se pudo aplicar el espaciado entre apps.": "The space between apps could not be applied.",
  // Shortcuts.
  "Elige una acción de Hyprflip.": "Choose a Hyprflip action.",
  "Actualiza la configuración guiada para poder editar atajos.": "Update Hyprflip's guided setup to edit shortcuts.",
  "Un atajo de tecla física usa estos modificadores. Elige otros modificadores o edita antes ese atajo.": "A physical-key shortcut uses these modifiers. Choose other modifiers or change that shortcut first.",
  "No se pudo aplicar el atajo. Vuelve a abrir Ajustes e inténtalo de nuevo.": "The shortcut could not be applied. Try again.",
  "El atajo no se registró. Se restauró su configuración anterior.": "The shortcut did not register. The previous one is back.",
  "Incluye Super, Ctrl o Alt en el atajo.": "Include Super, Ctrl or Alt.",
  "Pulsa una letra, un número, una tecla de función o de navegación.": "Use a letter, a number, a function key or a navigation key.",
  "Elige una tecla junto con sus modificadores.": "Choose a key along with its modifiers.",
  "El archivo de atajos guardados no es válido. Restáuralo desde una copia de seguridad.": "The saved shortcuts file is not valid. Restore it from a backup.",
  // The exchange with the panel itself.
  "El panel envió una respuesta no válida. Vuelve a abrir Tarjetas.": "The panel sent an answer the helper could not read. Try again.",
  "La respuesta del panel era demasiado grande. Vuelve a abrir Tarjetas.": "The panel's answer was too large. Try again.",
  "Demasiadas respuestas del panel. Vuelve a abrir Tarjetas.": "Too many answers from the panel. Try again.",
  "Esa elección del panel caducó. Vuelve a abrir Tarjetas.": "That choice expired. Try again.",
  "La selección de tarjeta caducó. Vuelve a abrir Tarjetas.": "The card choice expired. Try again.",
  "La solicitud de tarjeta era demasiado grande.": "The card request was too large.",
  // Binding labels the helper makes up.
  "Otra acción del escritorio": "Another desktop action"
}

// Hyprflip's Spanish names of its shortcut actions (shortcuts.py), by id.
var SHORTCUT_IDS = {
  "Voltear tarjeta": "flip",
  "Crear, desplegar o plegar": "create",
  "Editar tarjeta": "edit",
  "Abrir tarjetas guardadas": "library",
  "Buscar una app en las tarjetas": "find",
  "Mantener para vistazo": "peek",
  "Desagrupar tarjeta": "unpair",
  "Marcar primera app": "mark",
  "Emparejar con la app marcada": "pair",
  "Añadir app al lado": "attach_h",
  "Añadir app debajo": "attach_v",
  "Quitar app enfocada": "release",
  "Cancelar emparejamiento": "cancel"
}

// A chord as the helper writes it (shortcuts.label): only Space is Spanish.
function chord(text) {
  return String(text).replace(/(^|\+)Espacio$/, "$1Space")
}

var PATTERNS = [
  // A failed rebuild wraps the first error.
  [/^(.+) Tampoco se pudo volver a armar la tarjeta anterior; sus apps siguen abiertas\.$/, function(m) {
    return english(m[1]) + " The previous card could not be put back either; its apps stay open."
  }],
  [/^Cada cara necesita entre (\d+) y (\d+) apps\.$/, function(m) {
    return "Each side needs between " + m[1] + " and " + m[2] + " apps."
  }],
  [/^(.+) no se puede usar: está en otra tarjeta o grupo, en pantalla completa, flotando o en un espacio de trabajo especial\.$/, function(m) {
    return m[1] + " cannot be used: it is in another card or group, fullscreen, floating or on a special workspace."
  }],
  [/^(\S+) ya lo usa (.+)\. Elige otro atajo\.$/, function(m) {
    return chord(m[1]) + " is already used by " + (EXACT[m[2]] || m[2]) + ". Choose another shortcut."
  }],
  [/^No se puede comprobar con “(.+)”: Hyprland no informó de su tecla\. Elige otros modificadores\.$/, function(m) {
    return "Cannot check against “" + (EXACT[m[1]] || m[1]) + "”: Hyprland did not report its key. Choose other modifiers."
  }],
  // A saved shortcut: "<action>: <chord>".
  [/^(.+): ((?:(?:Super|Ctrl|Alt|Shift)\+)+\S+)$/, function(m) {
    var id = SHORTCUT_IDS[m[1]]
    return id ? Labels.shortcutLabel(id, m[1]) + ": " + chord(m[2]) : null
  }]
]

// message: what the helper wrote. -> the same in English when it is known,
// else unchanged.
function english(message) {
  var text = String(message === undefined || message === null ? "" : message)
  if (Object.prototype.hasOwnProperty.call(EXACT, text)) return EXACT[text]
  for (var i = 0; i < PATTERNS.length; i++) {
    var m = PATTERNS[i][0].exec(text)
    if (!m) continue
    var out = PATTERNS[i][1](m)
    if (out !== null) return out
  }
  return text
}

// What the panel shows of a helper message in its language.
function forLang(message, lang) {
  return lang === "en" ? english(message) : String(message === undefined || message === null ? "" : message)
}

if (typeof module !== "undefined") {
  module.exports = { EXACT: EXACT, english: english, forLang: forLang }
}
