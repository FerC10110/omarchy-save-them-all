// Run with: node --test tests/
// The Hyprflip helper speaks Spanish only; in English, the panel shows its
// known messages in English and passes anything else through untouched.
const test = require("node:test")
const assert = require("node:assert/strict")
const { load } = require("./load.js")
const HelperText = load("HelperText.js")

test("the helper's done messages come back in English", () => {
  assert.equal(HelperText.english("Tarjeta creada."), "Card created.")
  assert.equal(HelperText.english("Tarjeta editada."), "Card edited.")
  assert.equal(HelperText.english("Tarjeta desarmada. Sus apps siguen abiertas."), "Card taken apart. Its apps stay open.")
  assert.equal(HelperText.english("Animación actualizada para todas las tarjetas."), "Animation updated for every card.")
  assert.equal(HelperText.english("Cancelado. Las apps ya abiertas no se cierran."), "Cancelled. Apps that are already open stay open.")
})

test("the common refusals come back in English", () => {
  assert.equal(HelperText.english("Ve al espacio de trabajo de esta tarjeta antes de editarla."),
    "Go to this card's workspace before changing it.")
  assert.equal(HelperText.english("La tarjeta cambió. Actualiza Tarjetas antes de editarla."),
    "The card changed. Refresh the list before changing it.")
  assert.equal(HelperText.english("Espera a que termine el giro e inténtalo de nuevo."),
    "Wait for the flip to finish and try again.")
  assert.equal(HelperText.english("Hyprflip no está disponible. Carga el plugin de contenedores e inténtalo de nuevo."),
    "Hyprflip is not available. Load the containers plugin and try again.")
  assert.equal(HelperText.english("Crea una tarjeta con varias apps con O para usar estos controles."),
    "This only works on a card made of several apps.")
})

test("a stale action and the partial successes come back in English", () => {
  assert.equal(HelperText.english("Esa acción ya no está disponible. Vuelve a abrir Tarjetas."),
    "That action is no longer available. Try again.")
  assert.equal(HelperText.english("Tarjeta creada, pero no se pudo colocar donde estaba. Muévela a mano."),
    "Card created, but it could not go back where it was. Move it by hand.")
  assert.equal(HelperText.english("Tarjeta editada, pero no se pudo colocar donde estaba. Muévela a mano."),
    "Card edited, but it could not go back where it was. Move it by hand.")
  assert.equal(HelperText.english("Tarjeta desarmada. Sus apps siguen abiertas, pero no se pudieron colocar donde estaban."),
    "Card taken apart. Its apps stay open, but they could not go back where they were.")
})

test("unplaced tells a partial success from a plain one, in either language", () => {
  for (const m of ["Tarjeta creada, pero no se pudo colocar donde estaba. Muévela a mano.",
                   "Tarjeta desarmada. Sus apps siguen abiertas, pero no se pudieron colocar donde estaban."]) {
    assert.equal(HelperText.unplaced(m), true)
    assert.equal(HelperText.unplaced(HelperText.english(m)), true)
  }
  assert.equal(HelperText.unplaced("Tarjeta creada."), false)
  assert.equal(HelperText.unplaced("Card taken apart. Its apps stay open."), false)
  assert.equal(HelperText.unplaced(undefined), false)
})

test("messages with values keep them", () => {
  assert.equal(HelperText.english("Cada cara necesita entre 1 y 5 apps."), "Each side needs between 1 and 5 apps.")
  assert.equal(HelperText.english("kitty no se puede usar: está en otra tarjeta o grupo, en pantalla completa, flotando o en un espacio de trabajo especial."),
    "kitty cannot be used: it is in another card or group, fullscreen, floating or on a special workspace.")
  // A failed rebuild wraps the first error: both halves in English.
  assert.equal(HelperText.english("No se pudo crear la tarjeta. Vuelve a abrir la configuración. Tampoco se pudo volver a armar la tarjeta anterior; sus apps siguen abiertas."),
    "The card could not be made. Try again. The previous card could not be put back either; its apps stay open.")
  assert.equal(HelperText.english("Super+Ctrl+Espacio ya lo usa Otra acción del escritorio. Elige otro atajo."),
    "Super+Ctrl+Space is already used by Another desktop action. Choose another shortcut.")
  // A saved shortcut: Hyprflip's Spanish name of the action, then the chord.
  assert.equal(HelperText.english("Voltear tarjeta: Super+Ctrl+Alt+F"), "Flip the card: Super+Ctrl+Alt+F")
  assert.equal(HelperText.english("Mantener para vistazo: Super+Espacio"), "Peek at the other side: Super+Space")
})

test("anything unknown passes through unchanged", () => {
  for (const m of ["", "Algo que el asistente dice ahora.", "error: bad dispatcher", "Voltear algo: Super+F"])
    assert.equal(HelperText.english(m), m)
})

test("every mapped message is English on the way out", () => {
  // No Spanish-only letters left in a translation (a copy-paste slip).
  for (const [es, en] of Object.entries(HelperText.EXACT)) {
    assert.notEqual(es, en)
    assert.doesNotMatch(en, /[áéíóúñ¿¡]/, en)
  }
})
