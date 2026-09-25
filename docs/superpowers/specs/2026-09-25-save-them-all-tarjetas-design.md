# Save Them All 2.0: tarjetas de flip — diseño

Fecha: 2026-09-25. Estado: borrador para revisión del usuario.
Maquetas aprobadas: https://claude.ai/artifact/2YoWweEcb2GgECMCYD1Xe7 (constructor opción B, panel opción B).

## 1. Objetivo

Save Them All guarda y restaura el layout de cada workspace. Esta versión suma las **tarjetas de flip** de OmaCards (ventanas agrupadas en dos caras, Frente y Reverso, que se voltean en el mismo lugar) con una interfaz más intuitiva y gráfica, y hace que **guardar un workspace también guarde sus tarjetas** y restaurarlo las vuelva a armar.

Pedido del usuario: "mejorar omacards y unirlo a Save Them All", "más intuitivo y más gráfico a la hora de seleccionar ventanas para que se unan", "también quiero que guarde la configuración de flip".

Criterios de éxito:
- Crear una tarjeta de 3 apps en una sola pantalla, sin depender de qué ventana tiene el foco (hoy son 12–15 pasos en 3 contextos).
- Cada ventana se reconoce por miniatura en vivo, nombre legible e ícono; dos ventanas gemelas se distinguen.
- Guardar → cerrar sesión → iniciar sesión devuelve las ventanas **y** las tarjetas (caras, orden, eje, proporciones, cara visible, flotante).
- Sin Hyprflip, Save Them All funciona como la 1.3.0 y ninguna ventana queda escondida.

## 2. Decisiones (del usuario)

| Tema | Decisión |
|---|---|
| Relación con Hyprflip | **Opcional.** Sin Hyprflip todo funciona como hoy; las tarjetas aparecen si está cargado. |
| Qué se conserva de OmaCards | **Todo:** crear/editar/desarmar, voltear, flotantes, desplegar, peek, apariencia, animación, espaciado, atajos con detección de conflictos. |
| Cómo se eligen ventanas | **Constructor con miniaturas** + botón **Elegir en pantalla**. |
| Idioma | **Inglés y español**, con ajuste en el panel: Automático (idioma del sistema, por defecto) / English / Español. |
| Dónde se guardan las tarjetas | **Solo con el workspace** (`workspace-N.json`). Sin biblioteca aparte; el `cards.json` de Hyprflip no se usa. |
| Arquitectura | **Enfoque 1:** Save Them All habla con Hyprflip por sus vías públicas (`hyprctl hyprflip status` y el helper `control.py`), más una acción nueva `create` en el fork de Hyprflip. |
| Constructor | **Opción B:** la tarjeta grande a la izquierda (Frente arriba, Reverso abajo, con la proporción real del lugar), las ventanas en una columna a la derecha. |
| Panel | **Opción B:** pestañas **Workspace · Tarjetas · Ajustes**. |
| Sin Hyprflip al restaurar | Cada tarjeta se arma como **grupo nativo de Hyprland con pestañas** en su lugar, con la cara que estaba visible al frente. |

## 3. Arquitectura

```
Panel.qml (pestañas) ─┬─ WorkspaceTab.qml   guardar / restaurar / restaurar al iniciar / aviso de Hyprflip
                      ├─ CardsTab.qml       tarjetas de todos los workspaces: voltear, editar, desarmar, nueva
                      ├─ SettingsTab.qml    apariencia, espaciado, animación, sumar arrastrando, idioma,
                      │                     cerrar el navegador, estado de Hyprflip, link a atajos
                      ├─ ShortcutsPage.qml  atajos de Hyprflip con detección de conflictos
                      ├─ CardBuilder.qml    constructor (opción B) — crear y editar
                      └─ PickOverlay.qml    "Elegir en pantalla" (overlay a pantalla completa)
Hyprflip.qml   conexión con el helper (snapshot / run, handoff, cancelar, refresco por eventos) — basado en
               Service.qml de OmaCards (MIT, crédito en NOTICE)
AppNames.js    nombre legible + ícono de una ventana
I18n.js        textos en/es y resolución del idioma
bin/save-them-all      + llama `bin/cards capture` si Hyprflip está cargado
bin/restore-them-all   + llama `bin/cards rebuild` (o `fallback`) al final
bin/cards (Python 3)   capture / rebuild / fallback
```

El motor de las tarjetas vivas sigue siendo Hyprflip (plugin C++ de Hyprland + helper Python). Save Them All solo crea, edita, desarma y guarda tarjetas; voltear, desplegar, peek y los atajos son acciones de Hyprflip.

### 3.1 Detección de Hyprflip

Hyprflip está **disponible** si `hyprctl plugin list` incluye `hyprflip` y el helper responde `snapshot` con `protocol: 1`. Si no:
- la pestaña Tarjetas y los ajustes de tarjetas muestran el motivo (plugin no cargado, versión de Hyprland distinta de la del build, helper ausente o de otro protocolo) y el comando que lo arregla;
- la pestaña Workspace muestra el aviso "Tarjetas en pausa" solo si el workspace tiene tarjetas guardadas;
- guardar y restaurar ventanas funciona igual que en 1.3.0.

## 4. Guardar y restaurar

### 4.1 Formato

`~/.local/state/save-them-all/workspace-N.json` suma un bloque opcional `cards`:

```json
{
  "workspace": 1, "monitor": "HDMI-A-1", "saved_at": "…", "autostart": false,
  "windows": [ … como hoy, cada una con índice implícito por posición … ],
  "cards": [
    {
      "name": "Trading",
      "faces": [
        {"windows": [0, 2], "axis": "row", "ratios": [0.5, 0.5]},
        {"windows": [4],    "axis": "row", "ratios": [1.0]}
      ],
      "visible": 0,
      "floating": null
    }
  ]
}
```

- `faces[i].windows` son **índices en `windows`** del mismo archivo; así la tarjeta no depende de direcciones de Hyprland (cambian cada sesión).
- `floating`: `null` en mosaico, o `{"at": [x, y], "size": [w, h]}`.
- Un archivo sin `cards` se lee como hoy; la 1.3.0 ignora el bloque (no lo lee).
- Al guardar, el `workspace-N.json` se escribe entero de forma atómica, como hoy.

### 4.2 Guardar

`save-them-all` guarda las ventanas como hoy. Si Hyprflip está disponible, llama `bin/cards capture <ws>` con la lista de ventanas guardadas (dirección → índice) y pone lo que devuelve en `cards`. `capture` lee `hyprctl hyprflip status` y, por cada tarjeta del workspace: sus caras con las direcciones en orden, eje, proporciones, cara visible y si flota. Una tarjeta con una ventana que no está en `windows` (excluida o sin forma de reabrirse) se guarda sin esa ventana; si una cara queda vacía, la tarjeta no se guarda y el aviso de guardado lo dice.

Si Hyprflip no está disponible al guardar y el archivo anterior tenía `cards`, se **conservan** las tarjetas anteriores cuyas ventanas sigan en el nuevo `windows` (por clase + cómo reabrirla); las demás se descartan y el aviso lo dice.

### 4.3 Restaurar

`restore-them-all` rearma las ventanas como hoy y **después**:
- con Hyprflip disponible: `bin/cards rebuild <archivo>` arma cada tarjeta con la acción `create` del helper (§5), usando las direcciones de las ventanas recién ubicadas; aplica eje, proporciones, flotante y la cara visible;
- sin Hyprflip: `bin/cards fallback <archivo>` arma cada tarjeta como **grupo nativo de Hyprland** (`hl.dsp` de grupos) en el lugar de la tarjeta, con las ventanas de las dos caras como pestañas y la cara visible al frente.

Reglas comunes:
- Si falta una ventana de la tarjeta (no se pudo abrir), se arma con las que hay. Si una cara queda vacía, la tarjeta no se arma y la notificación final lo dice.
- Una ventana que ya está en una tarjeta o grupo no se toca.
- Restaurar dos veces seguidas no duplica tarjetas: una tarjeta cuyas ventanas ya forman esa tarjeta se deja como está.
- La restauración al iniciar sesión hace lo mismo, una vez por sesión como hoy.

### 4.4 Hyprflip se rompe con tarjetas armadas

Si Hyprflip deja de estar disponible con tarjetas vivas (por ejemplo, tras actualizar Hyprland), sus ventanas siguen en grupos nativos. El aviso de la pestaña Workspace ofrece **Mostrar las dos caras**: saca las ventanas de los grupos y las deja en mosaico, para que nada quede escondido.

## 5. Cambio en Hyprflip (fork del usuario)

Repositorio: `~/.local/src/hyprflip-omacards`. Se agrega a `control.py` la acción `create` con las caras completas:

```json
{"action": "create", "faces": [["address:0x…", "address:0x…"], ["address:0x…"]],
 "axes": ["row", "row"], "ratios": [[0.5, 0.5], [1.0]], "visible": 0, "floating": null}
```

Valida y arma todo de una vez, con el mismo mecanismo transaccional del flujo actual (revierte si algo falla) y responde `done` o un error legible. Lleva su test en el estilo de los tests del helper. Se propone upstream; mientras tanto el fork queda fijado al mismo commit base que usa OmaCards.

## 6. Interfaz

### 6.1 Pestañas

- **Workspace** (la de hoy): nombre y estado del workspace ("8 ventanas · 1 tarjeta · guardado 11:59"), aviso de Hyprflip si corresponde, Save them all, Restore them all, Restaurar al iniciar (un switch por workspace, ahora con la cantidad de tarjetas).
- **Tarjetas**: las tarjetas vivas de todos los workspaces, agrupadas por workspace. Cada una muestra su nombre, modo (mosaico/flotante) y sus dos caras con los nombres de las apps; la cara visible resaltada. Sobre la tarjeta elegida: `v` voltear, `e` editar (abre el constructor con la tarjeta cargada), `d` desarmar (las ventanas vuelven al mosaico). Al pie: **＋ Nueva tarjeta**.
- **Ajustes**: apariencia (pestañas clásicas / marco de tarjeta), espaciado entre apps (como el escritorio / compacto), animación (transición, velocidad, instantánea), cómo sumar arrastrando, **idioma**, cerrar el navegador limpio (el switch de hoy), estado de Hyprflip (versión cargada, versión de Hyprland, qué hacer si no coincide) y link a **Atajos**.
- **Atajos**: los de Hyprflip (voltear, peek, desplegar, …), editables, con detección de conflictos como en OmaCards.

La barra no cambia: el botón sigue atenuado hasta que el workspace tenga layout guardado; clic del medio guarda.

### 6.2 Constructor (crear y editar)

Panel grande. Izquierda: la **tarjeta** dibujada con la proporción real del lugar que va a ocupar (el tile de la ventana elegida primero, o el del lugar de la tarjeta al editar): **Frente** arriba, **Reverso** abajo; cada cara con sus ventanas como miniaturas, un selector fila/columna y un lugar "＋ soltá acá". Derecha: una columna con las **ventanas elegibles** agrupadas por workspace (el actual primero, los demás plegados).

Cada ventana se muestra con:
- **miniatura en vivo** (`ScreencopyView` de Quickshell con el `HyprlandToplevel` de la ventana; en vivo solo la que está bajo el mouse o elegida, las demás con una captura cada pocos segundos; si no hay captura, el ícono);
- **nombre legible e ícono** (§6.4);
- la posición en pantalla cuando hay ventanas con el mismo nombre ("izquierda arriba", "derecha").

Gestos: arrastrar una ventana a una cara; o elegirla y apretar `f` (Frente) o `r` (Reverso); arrastrar dentro de una cara reordena; soltar fuera la saca; `e` abre **Elegir en pantalla**. Hasta 5 ventanas por cara. Abajo: nombre de la tarjeta, **Crear tarjeta** (o **Guardar cambios** al editar) y Cancelar. Crear arma la tarjeta con una sola llamada a `create`; la tarjeta queda en el lugar de la primera ventana del Frente.

Ventanas **no elegibles** aparecen atenuadas con el motivo: ya en otra tarjeta, pantalla completa, workspace especial, o el panel mismo. Si una ventana elegida se cierra mientras el constructor está abierto, desaparece de su cara con un aviso; lo demás se conserva.

Ventanas de otro workspace: elegirlas las mueve al workspace de la tarjeta al crear, y el constructor lo avisa antes de crear.

Editar la cara oculta no exige voltear: el constructor usa la última captura de esas ventanas.

### 6.3 Elegir en pantalla

Overlay a pantalla completa sobre el monitor actual (`kinds: ["overlay"]`). Velo semitransparente; la ventana bajo el mouse se resalta con su nombre; clic la suma a la **cara activa** (indicada en una barra abajo); `Tab` cambia de cara; `Enter` vuelve al constructor con lo elegido; `Esc` vuelve sin cambios. Las ventanas no elegibles no se resaltan y muestran el motivo al pasar. Solo cubre lo visible.

### 6.4 Nombres e íconos

`AppNames.js` resuelve, en orden:
1. webapp de Omarchy: clase `chrome-<host>__<path>-Default` (o la URL que ya guarda Save Them All en `launch.url`) → el `.desktop` cuyo `Exec=omarchy-launch-webapp <url>` coincide → su `Name` e `Icon`;
2. `.desktop` por `StartupWMClass` o por id igual a la clase;
3. clase en DNS inverso → su última parte (`org.omarchy.btop` → "btop");
4. la clase tal cual.

El mismo resolvedor se usa en la pestaña Tarjetas y en las notificaciones.

## 7. Idioma

`I18n.js` con los textos en inglés y español (el inglés es la clave). El ajuste **Idioma** (Automático / English / Español) se guarda en `~/.local/state/save-them-all/settings.json`; Automático usa el idioma del sistema (`LANG`). Los scripts (`bin/*`) reciben el idioma resuelto en `SAVE_THEM_ALL_LANG` para sus notificaciones. Un test verifica que cada texto usado tenga traducción y que no haya traducciones sin uso.

## 8. Errores

- Todo mensaje dice qué pasó y qué hacer ("Hyprflip no cargó: Hyprland es 0.57 y Hyprflip se compiló para 0.56.2. Recompilalo con `…`").
- Una falla del helper durante crear/editar no cierra el constructor: muestra el error y conserva lo elegido.
- `bin/cards` nunca aborta la restauración de ventanas: sus errores van a la notificación final y a `~/.local/state/save-them-all/restore.log`.

## 9. Pruebas

- **`bin/cards`** (pytest o unittest, sin Hyprland real): `capture` con estados de ejemplo de `hyprctl hyprflip status` (mosaico, flotante, 1–5 ventanas por cara, ventana no guardada); `rebuild` con un helper falso (arma, faltantes, cara vacía, idempotencia); `fallback` con un `hyprctl` falso (grupos y cara visible); archivos viejos sin `cards`; conservar tarjetas al guardar sin Hyprflip.
- **Scripts de bash**: pruebas de las partes nuevas con `hyprctl` falso en el `PATH`.
- **Acción `create` en Hyprflip**: test en el estilo del helper.
- **QML**: tests de render sin escritorio (como `tests/render.py` de OmaCards) para las pestañas, el constructor y el overlay en inglés y español; test de cobertura de `I18n.js`; tests de `AppNames.js` con `.desktop` de ejemplo.
- **Prueba en vivo** al final, solo con ventanas descartables en un workspace vacío: crear una tarjeta con el constructor y con Elegir en pantalla, guardar, desarmar, restaurar, y restaurar con Hyprflip deshabilitado (grupo con pestañas).

## 10. Fuera de alcance

- Biblioteca de tarjetas independiente del workspace.
- Reescribir o reemplazar Hyprflip; rejillas 2×2 o más de 2 caras (el modelo de Hyprflip no las tiene).
- Tarjetas que abarquen varios workspaces.

## 11. Entrega

- Save Them All **2.0.0**: README (inglés) con la sección de tarjetas y la dependencia opcional de Hyprflip, CHANGELOG, `NOTICE` con el crédito a OmaCards (MIT, nocstah), maquetas nuevas en `preview.png`.
- OmaCards se deshabilita solo cuando el usuario lo decida.
- Sin push, tag ni publicación sin OK del usuario.
