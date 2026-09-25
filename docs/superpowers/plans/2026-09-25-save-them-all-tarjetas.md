# Save Them All 2.0: tarjetas de flip — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Save Them All suma las tarjetas de flip de Hyprflip: las crea, edita, voltea y desarma desde un panel con pestañas (Workspace · Tarjetas · Ajustes · Atajos). Tiene un constructor gráfico con miniaturas en vivo y un "Elegir en pantalla". Guardar un workspace guarda también sus tarjetas, y restaurarlo las vuelve a armar (con Hyprflip, o como grupo nativo de Hyprland si Hyprflip no está). Todo en inglés y español.

**Architecture:** los scripts de bash siguen haciendo el trabajo de ventanas. Un script Python nuevo, `bin/cards`, habla con Hyprflip por sus vías públicas (`hyprctl hyprflip status` y el helper `control.py`) y con Hyprland (`hyprctl`), y es lo único que sabe de tarjetas. `save-them-all` y `restore-them-all` lo llaman. El shell carga un servicio (`Service.qml`) que es dueño de la conexión con Hyprflip (`Hyprflip.qml`, basado en el `Service.qml` de OmaCards), del idioma y del borrador del constructor. El panel de la barra muestra las pestañas y el constructor, y un overlay (`PickOverlay.qml`) hace "Elegir en pantalla". Toda la lógica pura vive en JS (`AppNames.js`, `I18n.js`, `Protocol.js`, `CardsModel.js`, `Shortcuts.js`, `Labels.js`, `Builder.js`, `Pick.js`) con tests de node. En el fork de Hyprflip se suman dos acciones al helper: `create` con las caras completas y `unpair`.

**Tech Stack:** bash + jq, Python 3.14 (solo biblioteca estándar, `unittest`), QML/Quickshell 0.3.1 (shell de Omarchy), JS de QML con `node:test` (node 26), Hyprland 0.56.2 (despachos Lua `hl.dsp.*`), Hyprflip 0.3.0 (fork `~/.local/src/hyprflip-omacards`).

**Spec:** `docs/superpowers/specs/2026-09-25-save-them-all-tarjetas-design.md`.

Todo el plan corre en el repo de Save Them All: `R=~/.config/omarchy/plugins/io.github.ferc10110.save-them-all`, rama `tarjetas` (ya creada). Las rutas son relativas a `$R`, salvo la Task 6, que corre en el fork de Hyprflip: `H=~/.local/src/hyprflip-omacards`, en una rama nueva `save-them-all-create` que sale de `es`.

## Global Constraints

- **Hyprflip es opcional.** Sin Hyprflip (no cargado, compilado para otra versión de Hyprland, sin helper o con otro protocolo), guardar y restaurar ventanas funcionan como en 1.3.0 y ninguna ventana queda escondida.
- **Idioma:** inglés y español. El ajuste (Automático / English / Español) se guarda en `$SAVE_THEM_ALL_STATE/settings.json` (`{"language": "auto"|"en"|"es"}`). Automático usa `LC_ALL`, `LC_MESSAGES` o `LANG`: si empieza con `es`, español. El panel pasa `SAVE_THEM_ALL_LANG` a los scripts. Si no lo reciben, los scripts leen `settings.json` y después el sistema. El inglés es la clave: `I18n.js` (`STRINGS.es`) para QML/JS y `bin/messages.es.json` para bash y Python. Los tests fallan si un texto usado no tiene traducción, si sobra una traducción o si cambian los `%N`. El `--help` de los scripts y `close-browser-at-logout` quedan en inglés: sus errores son de configuración y el panel no los muestra, salvo en ese switch.
- **Formato:** las tarjetas se guardan **solo** en `workspace-N.json`, en un bloque `cards` de índices de `windows` (spec §4.1). Ese bloque se escribe solo si hay al menos una tarjeta. Un archivo sin `cards` se lee como hoy. Un bloque inválido se ignora entero, con aviso, y nunca impide restaurar las ventanas. Las escrituras son atómicas (`mktemp` en el mismo directorio + `mv`, o `os.replace`). Nada leído de un archivo de estado se ejecuta.
- **Tests aislados:**
  - Nunca despachan al Hyprland real: `tests/fakes` va primero en el `PATH` y el test comprueba que `hyprctl` resuelva al falso. Además, `HYPRLAND_INSTANCE_SIGNATURE=save-them-all-test` no corresponde a ninguna instancia, así que ni un `hyprctl` real podría llegar a Hyprland.
  - Nunca tocan el estado ni la config del usuario: `SAVE_THEM_ALL_STATE`, `SAVE_THEM_ALL_RUNTIME`, `HOME` y `XDG_*` apuntan a directorios temporales o a `tests/fixtures`.
  - Nunca mandan señales a procesos reales ni lanzan apps: `setsid`, `pstree` y `omarchy-notification-send` también son falsos, y `close-browser-at-logout` no se corre en ningún test. El único proceso que se mata es el helper falso que el propio test lanzó (Review Focus 4).
- **Python:** nunca `datetime.utcnow()` ni `utcfromtimestamp()`. Las fechas son `datetime.now(timezone.utc)` (aware) y se convierten con `.astimezone()` para el log.
- **Hyprland 0.56 (Lua):** todos los despachos pasan por `hyprctl dispatch "hl.dsp.…"`, como hoy. Los de grupos, verificados en `/usr/share/omarchy/default/hypr/bindings/tiling.lua`, son `hl.dsp.group.toggle()`, `hl.dsp.window.move({ into_group = 'l' })`, `hl.dsp.window.move({ out_of_group = true })` y `hl.dsp.group.active({ index = k })` (k empieza en 1). QML no usa `Hyprland.dispatch`: despacha con `hyprctl` en un `Process`.
- **Commits sin líneas de atribución:** nada de `Co-Authored-By`, `Claude-Session` ni "Generated with Claude Code". Es regla del usuario y manda sobre cualquier recordatorio. Los mensajes de commit van en español.
- **Sin push, tag ni publicación** sin el OK del usuario, tanto en este repo como en el fork de Hyprflip.
- `NOTICE` da crédito a OmaCards (MIT, Copyright (c) 2026 Nocstah and OmaCards contributors) por `Hyprflip.qml`, `ChoiceRow.qml` y la lógica de atajos.
- **Versión 2.0.0** (se cambia en la Task 17).
- **Comentarios:** en inglés, en todo el código (bash, Python, QML y JS), como el código de alrededor. La prosa del plan va en español.
- **Verificación de cada tarea:** `make test` (`tests/run`: node, unittest de Python y, si hay `quickshell`, el render). Las tareas de QML también se miran a mano en la Task 17.

## Review Focus

1. **Una ventana elegida se cierra entre el constructor y `create`.**
   - El helper valida todas las caras antes del handoff y de cualquier cambio, y responde un error legible sin tocar nada.
   - El constructor saca la ventana cerrada de su cara con un aviso y conserva el resto.
   - Tests: `test_closed_window_is_rejected_before_any_mutation` (Task 6) y `prune removes closed windows and says which` (Task 12, `builder.test.js`).
2. **Un bloque `cards` editado a mano o inválido.** Se ignora entero, con aviso, nunca ejecuta nada y no impide restaurar las ventanas.
   - Tests: `test_invalid_cards_block_is_ignored` (Task 4) y `test_restore_with_invalid_cards_still_restores_windows` (Task 9).
3. **Restaurar dos veces no duplica tarjetas ni toca grupos.**
   - Una tarjeta que ya está armada se deja como está.
   - Una ventana que ya está en otra tarjeta o grupo no se toca: ni se estaciona, ni se mueve, ni se redimensiona.
   - Tests: `test_second_rebuild_keeps_the_card` (Task 8), `test_fallback_leaves_an_existing_group_alone` (Task 7) y `test_second_restore_leaves_cards_alone` (Task 9).
4. **El helper de Hyprflip se cuelga o falla.** `bin/cards rebuild` lo corta a los `SAVE_THEM_ALL_HELPER_TIMEOUT` segundos (30 por defecto). La restauración de ventanas termina igual, y el error va a la notificación y a `restore.log`.
   - Tests: `test_hung_helper_is_killed_and_noted` (Task 8) y `test_restore_survives_failing_cards` (Task 9).
5. **Sin Hyprflip, ninguna ventana queda escondida.**
   - Las ventanas ocultas de una tarjeta se guardan igual.
   - El fallback las muestra como pestañas de un grupo nativo.
   - "Mostrar las dos caras" libera todos los grupos del workspace.
   - Tests: `test_hidden_members_saved_without_hyprflip` (Task 5), `test_fallback_groups_every_member` (Task 7) y `test_ungroup_releases_every_group` (Task 7).

---

### Task 1: Infraestructura de tests y caracterización de la 1.3

**Files:**
- Create: `tests/fakes/hyprctl`, `tests/fakes/omarchy-notification-send`, `tests/fakes/setsid`, `tests/fakes/pstree`
- Create: `tests/scripttest.py`, `tests/test_legacy.py`
- Create: `tests/fixtures/applications/org.gnome.Calculator.desktop`
- Create: `tests/run`, `Makefile`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: `bin/save-them-all`, `bin/restore-them-all`, `bin/restore-them-all-at-login` tal como están en 1.3.0.
- Produces:
  - `tests/fakes/hyprctl`: un `hyprctl` que lee y escribe `$FAKE_HYPR_STATE`, un JSON con estas claves:
    - `clients`, `active_workspace`, `active`, `monitor`;
    - `plugins` (lista de nombres), `hyprflip` (lo que responde `hyprflip status`), `version`, `configerrors`;
    - `dispatches` (todo lo despachado, en orden), `left_of`, `anchor`;
    - `fail` (subcadenas que hacen fallar un despacho).
  - `tests/scripttest.py`:
    - `ROOT`, `BIN`, `FAKES`, `FIXTURES`;
    - `client(address, cls, at=(0, 0), size=(800, 600), ws=3, **extra)`;
    - `saved_window(cls, at, size, launch, floating=False)`;
    - la clase `ScriptTest`, con `self.env`, `self.state_dir`, `self.runtime`, `hypr_state(**kw)`, `hypr()`, `dispatches()`, `notifications()`, `launches()`, `helper_requests()`, `write_saved(ws, windows, cards=None, autostart=False)`, `saved(ws)`, `run_script(name, *args, env=None)` y `helper_config(**kw)`.
  - `make test` corre `tests/run`.

- [ ] **Step 1: El `hyprctl` falso**

`tests/fakes/hyprctl` (ejecutable):

```python
#!/usr/bin/env python3
"""A stand-in for hyprctl that reads and writes a JSON file instead of talking
to Hyprland. Tests put tests/fakes first in PATH and point FAKE_HYPR_STATE at
their own copy. It answers the queries Save Them All makes and applies the
dispatches it sends, closely enough for the scripts to see their effect; any
other dispatch is recorded and answered "ok"."""
import json
import os
import re
import sys

path = os.environ.get('FAKE_HYPR_STATE')
if not path:
    print('fake hyprctl: FAKE_HYPR_STATE is not set', file=sys.stderr)
    sys.exit(1)
with open(path) as f:
    state = json.load(f)
clients = {c['address']: c for c in state.setdefault('clients', [])}
ADDR = r"address:(0x[0-9a-f]+)"


def save():
    tmp = path + '.tmp'
    with open(tmp, 'w') as f:
        json.dump(state, f)
    os.replace(tmp, path)


def answer(value):
    print(json.dumps(value))
    sys.exit(0)


def regroup(members, current):
    """A native group: every member lists the group; only the current one shows."""
    for a in members:
        clients[a]['grouped'] = list(members)
        clients[a]['hidden'] = a != current


def dissolve(members):
    for a in members:
        clients[a]['grouped'] = []
        clients[a]['hidden'] = False


def apply(expr):
    active = state.get('active')
    if m := re.fullmatch(r"hl\.dsp\.focus\(\{ workspace = '(-?\d+)' \}\)", expr):
        state['active_workspace'] = int(m[1])
    elif m := re.fullmatch(r"hl\.dsp\.focus\(\{ window = '" + ADDR + r"' \}\)", expr):
        state['active'] = m[1]
    elif re.fullmatch(r"hl\.dsp\.layout\('preselect [rdlu]'\)", expr):
        state['anchor'] = active
    elif m := re.fullmatch(r"hl\.dsp\.window\.move\(\{ window = '" + ADDR + r"', workspace = '([^']+)', follow = false \}\)", expr):
        target = m[2]
        wid = -98 if target.startswith('special:') else int(target)
        clients[m[1]]['workspace'] = {'id': wid, 'name': target}
        if wid > 0 and state.get('anchor'):
            state.setdefault('left_of', {})[m[1]] = state['anchor']
        state['anchor'] = None
    elif m := re.fullmatch(r"hl\.dsp\.window\.resize\(\{ window = '" + ADDR + r"', x = (-?\d+), y = (-?\d+), relative = true \}\)", expr):
        size = clients[m[1]]['size']
        clients[m[1]]['size'] = [size[0] + int(m[2]), size[1] + int(m[3])]
    elif m := re.fullmatch(r"hl\.dsp\.window\.resize\(\{ window = '" + ADDR + r"', x = (-?\d+), y = (-?\d+), exact = true \}\)", expr):
        clients[m[1]]['size'] = [int(m[2]), int(m[3])]
    elif m := re.fullmatch(r"hl\.dsp\.window\.move\(\{ window = '" + ADDR + r"', x = (-?\d+), y = (-?\d+), exact = true \}\)", expr):
        clients[m[1]]['at'] = [int(m[2]), int(m[3])]
    elif m := re.fullmatch(r"hl\.dsp\.window\.float\(\{ window = '" + ADDR + r"', state = 'on' \}\)", expr):
        clients[m[1]]['floating'] = True
    elif expr == 'hl.dsp.group.toggle()' and active in clients:
        if clients[active].get('grouped'):
            dissolve(clients[active]['grouped'])
        else:
            regroup([active], active)
    elif re.fullmatch(r"hl\.dsp\.window\.move\(\{ into_group = ['\"]l['\"] \}\)", expr) and active in clients:
        target = state.get('left_of', {}).get(active)
        group = clients[target].get('grouped') if target in clients else None
        if group and active not in group:
            regroup(group + [active], active)
    elif expr == 'hl.dsp.window.move({ out_of_group = true })' and active in clients:
        group = clients[active].get('grouped') or []
        rest = [a for a in group if a != active]
        dissolve([active])
        if rest:
            regroup(rest, rest[0])
    elif (m := re.fullmatch(r"hl\.dsp\.group\.active\(\{ index = (\d+) \}\)", expr)) and active in clients:
        group = clients[active].get('grouped') or []
        k = int(m[1])
        if 1 <= k <= len(group):
            regroup(group, group[k - 1])
            state['active'] = group[k - 1]


args = sys.argv[1:]
if args[:1] == ['-j']:
    args = args[1:]
command = ' '.join(args)
ws = state.get('active_workspace', 1)

if command == 'clients':
    answer(state['clients'])
if command == 'activeworkspace':
    answer({'id': ws, 'name': str(ws), 'monitor': state.get('monitor', 'DP-1')})
if command == 'activewindow':
    answer(clients.get(state.get('active'), {}))
if command == 'workspaces':
    ids = sorted({c['workspace']['id'] for c in state['clients']} | {ws})
    answer([{'id': i, 'name': str(i), 'tiledLayout': 'dwindle'} for i in ids])
if command == 'plugin list':
    answer([{'name': n, 'version': '0.3.0', 'description': ''} for n in state.get('plugins', [])])
if command == 'version':
    v = state.get('version', '0.56.2')
    answer({'tag': 'v' + v, 'version': v})
if command == 'configerrors':
    print(state.get('configerrors', ''))
    sys.exit(0)
if command == 'hyprflip status':
    if 'hyprflip' not in state.get('plugins', []) or state.get('hyprflip') is None:
        print('unknown request')
        sys.exit(0)
    answer(state['hyprflip'])
if args[:1] == ['hyprflip']:
    state.setdefault('dispatches', []).append('hyprflip ' + ' '.join(args[1:]))
    save()
    print('ok')
    sys.exit(0)
if args[:1] == ['dispatch'] and len(args) == 2:
    expr = args[1]
    state.setdefault('dispatches', []).append(expr)
    if any(f in expr for f in state.get('fail', [])):
        save()
        print('error: fake failure')
        sys.exit(1)
    apply(expr)
    save()
    print('ok')
    sys.exit(0)
print(f'fake hyprctl: unsupported command: {command}', file=sys.stderr)
sys.exit(2)
```

- [ ] **Step 2: Notificaciones, lanzadores y `pstree` falsos**

`tests/fakes/omarchy-notification-send` (ejecutable):

```python
#!/usr/bin/env python3
"""Record a notification instead of showing it: {"notify": [title, body]}."""
import json
import os
import sys

args = sys.argv[1:]
if args[:1] == ['-g']:
    args = args[2:]
with open(os.environ['FAKE_LOG'], 'a') as f:
    f.write(json.dumps({'notify': args}) + '\n')
```

`tests/fakes/setsid` (ejecutable). Restaurar lanza cada app con `setsid -f …`, y el falso solo lo anota:

```python
#!/usr/bin/env python3
"""Record a launch instead of starting anything: {"launch": [argv…]}."""
import json
import os
import sys

args = [a for a in sys.argv[1:] if a != '-f']
with open(os.environ['FAKE_LOG'], 'a') as f:
    f.write(json.dumps({'launch': args}) + '\n')
```

`tests/fakes/pstree` (ejecutable). Guardar lee el árbol de procesos de las terminales, y el falso no muestra nada:

```bash
#!/bin/bash
# The fake windows have no real processes: an empty tree.
exit 0
```

```bash
chmod +x tests/fakes/hyprctl tests/fakes/omarchy-notification-send tests/fakes/setsid tests/fakes/pstree
```

- [ ] **Step 3: La base de los tests de scripts**

`tests/fixtures/applications/org.gnome.Calculator.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Calculator
Icon=org.gnome.Calculator
Exec=gnome-calculator
StartupWMClass=org.gnome.Calculator
```

`tests/scripttest.py`:

```python
"""Shared ground for the script tests: every test gets its own state, runtime
and home directories, a fake Hyprland, fake notifications and a fake launcher.
Nothing here can reach the real desktop: hyprctl resolves to tests/fakes (the
setUp checks it), and HYPRLAND_INSTANCE_SIGNATURE names no real instance."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BIN = ROOT / 'bin'
FAKES = ROOT / 'tests' / 'fakes'
FIXTURES = ROOT / 'tests' / 'fixtures'


def client(address, cls, at=(0, 0), size=(800, 600), ws=3, **extra):
    """One entry of `hyprctl -j clients`."""
    base = {'address': address, 'class': cls, 'initialClass': cls, 'title': cls,
            'pid': 900000000 + int(address, 16), 'at': list(at), 'size': list(size),
            'floating': False, 'workspace': {'id': ws, 'name': str(ws)}, 'mapped': True,
            'hidden': False, 'grouped': [], 'fullscreen': 0, 'pinned': False,
            'focusHistoryID': 0, 'monitor': 0, 'tags': []}
    base.update(extra)
    return base


def saved_window(cls, at, size, launch, floating=False):
    """One entry of a workspace file's windows."""
    return {'class': cls, 'title': cls, 'launch': launch, 'at': list(at),
            'size': list(size), 'floating': floating}


class ScriptTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix='save-them-all-test-'))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.state_dir = self.tmp / 'state'
        self.runtime = self.tmp / 'runtime'
        home = self.tmp / 'home'
        for d in (self.state_dir, self.runtime, home):
            d.mkdir()
        self.hypr_path = self.tmp / 'hypr.json'
        self.log_path = self.tmp / 'calls.log'
        self.log_path.touch()
        self.helper_path = self.tmp / 'helper.json'
        self.env = {
            'PATH': f'{FAKES}:{os.environ["PATH"]}',
            'HOME': str(home),
            'LANG': 'C.UTF-8',
            'SAVE_THEM_ALL_STATE': str(self.state_dir),
            'SAVE_THEM_ALL_RUNTIME': str(self.runtime),
            'SAVE_THEM_ALL_TIMEOUT': '2',
            'SAVE_THEM_ALL_LOGIN_DELAY': '0',
            'SAVE_THEM_ALL_LANG': 'en',
            'SAVE_THEM_ALL_PAUSE': '0',
            'SAVE_THEM_ALL_HELPER_TIMEOUT': '5',
            'SAVE_THEM_ALL_HYPRFLIP_HELPER': str(FAKES / 'control.py'),
            'SAVE_THEM_ALL_HYPRFLIP_SRC': str(self.tmp / 'src'),
            'FAKE_HYPR_STATE': str(self.hypr_path),
            'FAKE_LOG': str(self.log_path),
            'FAKE_HELPER_STATE': str(self.helper_path),
            'XDG_DATA_HOME': str(FIXTURES),
            'XDG_DATA_DIRS': str(FIXTURES),
            'XDG_RUNTIME_DIR': str(self.runtime),
            # No Hyprland instance has this name: even a real hyprctl would reach nothing.
            'HYPRLAND_INSTANCE_SIGNATURE': 'save-them-all-test',
            'PYTHONDONTWRITEBYTECODE': '1',
        }
        found = shutil.which('hyprctl', path=self.env['PATH'])
        self.assertEqual(Path(found), FAKES / 'hyprctl', 'the fake hyprctl must come first in PATH')
        self.hypr_state()

    # -- the fake Hyprland ------------------------------------------------
    def hypr_state(self, **kw):
        state = {'clients': [], 'active_workspace': 3, 'active': None, 'monitor': 'DP-1',
                 'plugins': [], 'hyprflip': None, 'version': '0.56.2', 'configerrors': '',
                 'dispatches': [], 'left_of': {}, 'anchor': None, 'fail': []}
        state.update(kw)
        self.hypr_path.write_text(json.dumps(state))

    def hypr(self):
        return json.loads(self.hypr_path.read_text())

    def dispatches(self):
        return self.hypr()['dispatches']

    def clients_by_address(self):
        return {c['address']: c for c in self.hypr()['clients']}

    # -- what the scripts did ---------------------------------------------
    def _log(self, key):
        lines = self.log_path.read_text().splitlines()
        return [json.loads(l)[key] for l in lines if l.strip() and key in json.loads(l)]

    def notifications(self):
        return self._log('notify')

    def launches(self):
        return self._log('launch')

    def helper_requests(self):
        return self._log('helper')

    def helper_config(self, **kw):
        self.helper_path.write_text(json.dumps(kw))

    # -- state files -------------------------------------------------------
    def write_saved(self, ws, windows, cards=None, autostart=False):
        data = {'workspace': ws, 'monitor': 'DP-1', 'saved_at': '2026-09-25T10:00:00-03:00',
                'autostart': autostart, 'windows': windows}
        if cards is not None:
            data['cards'] = cards
        path = self.state_dir / f'workspace-{ws}.json'
        path.write_text(json.dumps(data))
        return path

    def saved(self, ws):
        return json.loads((self.state_dir / f'workspace-{ws}.json').read_text())

    def run_script(self, name, *args, env=None):
        return subprocess.run([str(BIN / name), *args], env={**self.env, **(env or {})},
                              capture_output=True, text=True, timeout=120)
```

- [ ] **Step 4: Caracterizar la 1.3**

`tests/test_legacy.py`:

```python
"""What 1.3.0 already does, pinned down before 2.0 changes the scripts. With no
cards anywhere, all of this must stay exactly the same."""
import json

from scripttest import ScriptTest, client, saved_window

TERMINAL = {'kind': 'terminal'}
CALC = {'kind': 'app', 'desktop': 'org.gnome.Calculator.desktop'}


class LegacySaveTest(ScriptTest):
    def test_save_writes_windows_in_screen_order(self):
        self.hypr_state(clients=[
            client('0x2', 'org.gnome.Calculator', at=(960, 0), size=(960, 1080)),
            client('0x1', 'kitty', at=(0, 0), size=(960, 1080), tags=['terminal']),
        ])
        r = self.run_script('save-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        saved = self.saved(3)
        self.assertEqual([w['class'] for w in saved['windows']], ['kitty', 'org.gnome.Calculator'])
        self.assertEqual(saved['windows'][0]['launch'], TERMINAL)
        self.assertEqual(saved['windows'][1]['launch'], CALC)
        self.assertEqual(saved['windows'][1]['at'], [960, 0])
        self.assertNotIn('cards', saved)
        self.assertFalse(saved['autostart'])
        self.assertEqual(self.notifications()[-1][0], 'Saved 2 windows from workspace 3')

    def test_saving_again_keeps_autostart(self):
        self.write_saved(3, [saved_window('kitty', (0, 0), (10, 10), TERMINAL)], autostart=True)
        self.hypr_state(clients=[client('0x1', 'kitty', tags=['terminal'])])
        self.assertEqual(self.run_script('save-them-all', '--quiet').returncode, 0)
        self.assertTrue(self.saved(3)['autostart'])
        self.assertEqual(self.notifications(), [])

    def test_hidden_windows_are_not_saved(self):
        self.hypr_state(clients=[client('0x1', 'kitty', tags=['terminal']),
                                 client('0x2', 'org.gnome.Calculator', hidden=True)])
        self.assertEqual(self.run_script('save-them-all').returncode, 0)
        self.assertEqual([w['class'] for w in self.saved(3)['windows']], ['kitty'])

    def test_nothing_to_save(self):
        r = self.run_script('save-them-all')
        self.assertEqual(r.returncode, 1)
        self.assertEqual(self.notifications()[-1], ['Nothing to save', 'No windows on workspace 3'])


class LegacyRestoreTest(ScriptTest):
    def two_windows(self):
        self.write_saved(3, [saved_window('kitty', (0, 0), (960, 1080), TERMINAL),
                             saved_window('org.gnome.Calculator', (960, 0), (960, 1080), CALC)])
        self.hypr_state(clients=[client('0x1', 'kitty', at=(0, 0), size=(500, 500)),
                                 client('0x2', 'org.gnome.Calculator', at=(500, 0), size=(500, 500))])

    def test_restore_rebuilds_the_tree_and_the_sizes(self):
        self.two_windows()
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        d = self.dispatches()
        park = "hl.dsp.window.move({ window = 'address:%s', workspace = 'special:savethemall', follow = false })"
        self.assertIn(park % '0x1', d)
        self.assertIn(park % '0x2', d)
        self.assertIn("hl.dsp.layout('preselect r')", d)
        sizes = {a: c['size'] for a, c in self.clients_by_address().items()}
        self.assertEqual(sizes, {'0x1': [960, 1080], '0x2': [960, 1080]})
        self.assertEqual(self.notifications()[-1], ['Windows restored on workspace 3', '0 opened, 2 already there'])
        self.assertEqual(self.launches(), [])

    def test_a_window_without_launcher_is_reported_missing(self):
        self.write_saved(3, [saved_window('kitty', (0, 0), (960, 1080), TERMINAL),
                             saved_window('ghostapp', (960, 0), (960, 1080), None)])
        self.hypr_state(clients=[client('0x1', 'kitty')])
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 1)
        self.assertEqual(self.notifications()[-1], ['Windows: 1 missing', 'ghostapp (no launcher)'])
        self.assertEqual(self.launches(), [])

    def test_a_missing_app_is_launched_through_setsid(self):
        self.write_saved(3, [saved_window('org.gnome.Calculator', (0, 0), (960, 1080), CALC)])
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 1)   # the fake launcher opens nothing, so it never appears
        self.assertEqual(self.launches(), [['uwsm-app', '--', 'org.gnome.Calculator.desktop']])

    def test_a_file_from_1_2_with_cmd_still_restores(self):
        path = self.state_dir / 'workspace-3.json'
        path.write_text(json.dumps({'workspace': 3, 'windows': [
            {'class': 'kitty', 'cmd': 'omarchy-launch-terminal', 'at': [0, 0], 'size': [960, 1080]}]}))
        self.hypr_state(clients=[client('0x1', 'kitty', size=(500, 500))])
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_nothing_saved(self):
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 1)
        self.assertEqual(self.notifications()[-1], ['Nothing saved for workspace 3', "Run 'Save them all' first"])


class LegacyLoginTest(ScriptTest):
    def test_list_reports_every_saved_workspace(self):
        self.write_saved(3, [saved_window('kitty', (0, 0), (10, 10), TERMINAL)], autostart=True)
        self.write_saved(1, [saved_window('kitty', (0, 0), (10, 10), TERMINAL)] * 2)
        r = self.run_script('restore-them-all-at-login', '--list')
        rows = json.loads(r.stdout)
        self.assertEqual([(x['workspace'], x['windows'], x['autostart']) for x in rows], [(1, 2, False), (3, 1, True)])
```

- [ ] **Step 5: El corredor y el Makefile**

`tests/run` (ejecutable):

```bash
#!/bin/bash
# Every test of the plugin: node for the QML's JS, unittest for the scripts,
# bin/cards and the offscreen render. Nothing here touches the real desktop.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
export PYTHONDONTWRITEBYTECODE=1
if compgen -G 'tests/*.test.js' >/dev/null; then
  node --test tests/
fi
python3 -m unittest discover -s tests -p 'test_*.py' "$@"
```

`Makefile`:

```make
.PHONY: test
test:
	tests/run
```

`.gitignore`: agregar al final:

```
__pycache__/
```

```bash
chmod +x tests/run
```

- [ ] **Step 6: Correr**

Run: `make test`
Expected: los 10 tests de `test_legacy.py` en verde. Si alguno falla, el que está mal es el falso, no el script: la 1.3.0 es la referencia.

- [ ] **Step 7: Commit**

```bash
git add tests Makefile .gitignore
git commit -m "test: hyprctl falso y caracterización de guardar y restaurar 1.3"
```

---

### Task 2: Nombres e íconos de ventanas (`AppNames.js`)

**Files:**
- Create: `AppNames.js`
- Create: `tests/load.js`, `tests/desktop.js`, `tests/appnames.test.js`
- Create: `tests/fixtures/applications/YouTube.desktop`, `tests/fixtures/applications/kitty.desktop`, `tests/fixtures/applications/obsidian.desktop`

**Interfaces:**
- Produces:
  - `AppNames.urlClass(url) -> string`: la clase que Chromium le da a una webapp, igual que `url_class` de `save-them-all`.
  - `AppNames.webappUrl(exec) -> string`: la URL de un `Exec=omarchy-launch-webapp …`, o `""`.
  - `AppNames.resolve(win, entries) -> { name, icon, source }`:
    - `win` es `{ class, launch? }`;
    - `entries` es `[{ id, name, icon, startupClass, exec }]`;
    - `source` es `"webapp" | "entry" | "class" | "raw"`.
  - `tests/load.js`: `load(file)` carga un `.js` de QML en node y resuelve sus `.import`.
  - `tests/desktop.js`: `readEntries(dir)` lee los `.desktop` de un directorio con la forma de `entries`.

- [ ] **Step 1: Fixtures**

`tests/fixtures/applications/YouTube.desktop`:

```ini
[Desktop Entry]
Version=1.0
Name=YouTube
Comment=YouTube
Exec=omarchy-launch-webapp https://youtube.com/
Terminal=false
Type=Application
Icon=/home/test/.local/share/applications/icons/YouTube.png
StartupNotify=true
```

`tests/fixtures/applications/kitty.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=kitty
Icon=kitty
Exec=kitty
StartupWMClass=kitty
```

`tests/fixtures/applications/obsidian.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Obsidian
Icon=obsidian
Exec=obsidian %u
```

- [ ] **Step 2: Los cargadores de los tests**

`tests/load.js`:

```js
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
```

`tests/desktop.js`:

```js
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
```

- [ ] **Step 3: Write the failing test**

`tests/appnames.test.js`:

```js
// Run with: node --test tests/
const test = require("node:test")
const assert = require("node:assert/strict")
const path = require("node:path")
const { load } = require("./load.js")
const { readEntries } = require("./desktop.js")
const AppNames = load("AppNames.js")

const entries = readEntries(path.join(__dirname, "fixtures", "applications"))

test("urlClass names a webapp the way Chromium does", () => {
  assert.equal(AppNames.urlClass("https://youtube.com/"), "chrome-youtube.com__-Default")
  assert.equal(AppNames.urlClass("https://app.example.com/a/b?x=1#y"), "chrome-app.example.com__a_b-Default")
  assert.equal(AppNames.urlClass("https://example.com"), "chrome-example.com__-Default")
})

test("webappUrl reads an omarchy-launch-webapp Exec line", () => {
  assert.equal(AppNames.webappUrl("omarchy-launch-webapp https://youtube.com/"), "https://youtube.com/")
  assert.equal(AppNames.webappUrl('omarchy-launch-webapp "https://a.com/100%%"'), "https://a.com/100%")
  assert.equal(AppNames.webappUrl("kitty"), "")
})

test("a webapp gets its desktop entry's name and icon", () => {
  const r = AppNames.resolve({ class: "chrome-youtube.com__-Default" }, entries)
  assert.deepEqual(r, { name: "YouTube", icon: "/home/test/.local/share/applications/icons/YouTube.png", source: "webapp" })
})

test("a saved webapp is found by its URL even if the class was never seen", () => {
  const r = AppNames.resolve({ class: "chrome-other__-Default", launch: { kind: "webapp", url: "https://youtube.com/" } }, entries)
  assert.equal(r.name, "YouTube")
})

test("an unknown webapp is named after its host", () => {
  assert.deepEqual(AppNames.resolve({ class: "chrome-www.tradingview.com__chart_-Default" }, entries),
    { name: "www.tradingview.com", icon: "", source: "class" })
})

test("an app is found by StartupWMClass, ignoring case", () => {
  assert.deepEqual(AppNames.resolve({ class: "org.gnome.calculator" }, entries),
    { name: "Calculator", icon: "org.gnome.Calculator", source: "entry" })
})

test("an app is found by an entry id equal to its class", () => {
  assert.deepEqual(AppNames.resolve({ class: "obsidian" }, entries), { name: "Obsidian", icon: "obsidian", source: "entry" })
})

test("a reverse-DNS class with no entry keeps its last part", () => {
  assert.deepEqual(AppNames.resolve({ class: "org.omarchy.btop" }, entries), { name: "btop", icon: "", source: "class" })
})

test("anything else is the class itself", () => {
  assert.deepEqual(AppNames.resolve({ class: "weird" }, entries), { name: "weird", icon: "", source: "raw" })
  assert.deepEqual(AppNames.resolve({}, []), { name: "", icon: "", source: "raw" })
})
```

- [ ] **Step 4: Run test to verify it fails**

Run: `node --test tests/`
Expected: FAIL (`ENOENT … AppNames.js`).

- [ ] **Step 5: Write the implementation**

`AppNames.js`:

```js
// A readable name and an icon for a window. Hyprland knows a window by its
// class, which is an address, not a name: a webapp is
// chrome-host__path-Default and a GNOME app is org.gnome.Calculator. The
// desktop entries hold the real names. In order:
//   1. an Omarchy webapp: the entry whose Exec=omarchy-launch-webapp URL makes
//      that class (or the URL Save Them All saved in launch.url);
//   2. an entry whose StartupWMClass, or whose id, is the class;
//   3. an unknown webapp: its host; a reverse-DNS class: its last part;
//   4. the class itself.
//
// entries: [{ id, name, icon, startupClass, exec }], from Quickshell's
// DesktopEntries in QML or from tests/fixtures in node. No QML in here.

// https://host/a/b?x -> chrome-host__a_b-Default, as Chromium names a webapp
// (the same rule as url_class in bin/save-them-all).
function urlClass(url) {
  var u = String(url || "").replace(/^[^:\/]*:\/\//, "")
  u = u.split("?")[0].split("#")[0]
  var slash = u.indexOf("/")
  var host = slash < 0 ? u : u.substring(0, slash)
  var path = slash < 0 ? "" : u.substring(slash + 1)
  return "chrome-" + host + "__" + path.split("/").join("_") + "-Default"
}

// The URL an Exec line opens as a webapp, or "". An Exec line writes a
// literal % as %%.
function webappUrl(exec) {
  var m = /^omarchy-launch-webapp\s+"?([^"\s]+)"?/.exec(String(exec || ""))
  return m ? m[1].replace(/%%/g, "%") : ""
}

function found(entry, source) {
  return { name: String(entry.name || ""), icon: String(entry.icon || ""), source: source }
}

function resolve(win, entries) {
  var cls = String((win && win["class"]) || "")
  var launch = win && win.launch
  var list = entries || []
  var web = launch && launch.kind === "webapp" && launch.url ? urlClass(launch.url) : cls
  if (/^chrome-.+-Default$/.test(web)) {
    for (var i = 0; i < list.length; i++) {
      var url = webappUrl(list[i].exec)
      if (url !== "" && urlClass(url) === web) return found(list[i], "webapp")
    }
  }
  var lower = cls.toLowerCase()
  if (lower !== "") {
    for (var j = 0; j < list.length; j++)
      if (String(list[j].startupClass || "").toLowerCase() === lower) return found(list[j], "entry")
    for (var k = 0; k < list.length; k++)
      if (String(list[k].id || "").replace(/\.desktop$/, "").toLowerCase() === lower) return found(list[k], "entry")
  }
  var host = /^chrome-([^_]+)__.*-Default$/.exec(web)
  if (host) return { name: host[1], icon: "", source: "class" }
  var parts = cls.split(".")
  if (parts.length >= 3 && parts[parts.length - 1] !== "")
    return { name: parts[parts.length - 1], icon: "", source: "class" }
  return { name: cls, icon: "", source: "raw" }
}

if (typeof module !== "undefined") {
  module.exports = { urlClass: urlClass, webappUrl: webappUrl, resolve: resolve }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `make test`
Expected: PASS (9 tests de node y los 10 de la Task 1).

- [ ] **Step 7: Commit**

```bash
git add AppNames.js tests
git commit -m "feat: AppNames.js, nombre legible e ícono de cada ventana"
```

---

### Task 3: Idioma: `I18n.js`, los mensajes de los scripts y los tests de cobertura

**Files:**
- Create: `I18n.js`, `bin/lib/i18n.sh`, `bin/messages.es.json`
- Create: `tests/sources.js`, `tests/i18n.test.js`, `tests/coverage.test.js`, `tests/test_messages.py`
- Modify: `bin/save-them-all`, `bin/restore-them-all`, `bin/restore-them-all-at-login` (mensajes con `msg`)

**Interfaces:**
- Produces:
  - `I18n.STRINGS.es`: un objeto, vacío por ahora. Cada tarea de QML le agrega sus textos.
  - `I18n.t(text, lang, args) -> string`.
  - `I18n.resolveLang(setting, system) -> "en" | "es"`.
  - En bash: `source "$BIN_DIR/lib/i18n.sh"` define `MSG_LANG` y `msg FORMAT ARGS…`, que traduce y rellena `%1…%N` en una pasada.
  - `bin/messages.es.json`: las traducciones de los scripts. `bin/cards` (Python) usa la misma tabla desde la Task 4.
  - `tests/sources.js`: `sources(exts)` lista los archivos del plugin (`{name, text}`), sin `tests/` ni `docs/`.

- [ ] **Step 1: Write the failing tests**

`tests/sources.js`:

```js
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
```

`tests/i18n.test.js`:

```js
// Run with: node --test tests/
const test = require("node:test")
const assert = require("node:assert/strict")
const { load } = require("./load.js")
const I18n = load("I18n.js")

test("English is the key and comes back as it went in", () => {
  assert.equal(I18n.t("No such text anywhere", "en"), "No such text anywhere")
  assert.equal(I18n.t("No such text anywhere", "es"), "No such text anywhere")
})

test("%N takes its value in one pass", () => {
  assert.equal(I18n.t("%1 and %2", "en", ["%2", "b"]), "%2 and b")
  assert.equal(I18n.t("%1 %0 %3", "en", ["a"]), "a %0 %3")
  assert.equal(I18n.t("%10", "en", ["x"]), "%10")
})

test("a key named like an Object property is not a translation", () => {
  assert.equal(I18n.t("constructor", "es"), "constructor")
})

test("resolveLang: an explicit choice wins, auto follows the system", () => {
  assert.equal(I18n.resolveLang("es", "en_US.UTF-8"), "es")
  assert.equal(I18n.resolveLang("en", "es_AR.UTF-8"), "en")
  assert.equal(I18n.resolveLang("auto", "es_AR.UTF-8"), "es")
  assert.equal(I18n.resolveLang("auto", "C.UTF-8"), "en")
  assert.equal(I18n.resolveLang("", ""), "en")
})
```

`tests/coverage.test.js`:

```js
// Run with: node --test tests/
// Every text the QML and JS show goes through t("…"), whose key is the
// English text. These tests keep STRINGS.es in step with the code: nothing
// shown untranslated, nothing translated that is no longer shown, and the
// same %N placeholders on both sides.
const test = require("node:test")
const assert = require("node:assert/strict")
const { load } = require("./load.js")
const { sources } = require("./sources.js")
const I18n = load("I18n.js")

const CALL = /\bt\(\s*"((?:[^"\\]|\\.)*)"/g
// Labels.js holds tables whose entries are translated as t(entry.label).
const LABEL = /\b(?:label|detail):\s*"((?:[^"\\]|\\.)*)"/g

function used() {
  const found = new Map()
  for (const f of sources([".qml", ".js"])) {
    if (f.name === "I18n.js") continue
    let m
    while ((m = CALL.exec(f.text))) found.set(JSON.parse('"' + m[1] + '"'), f.name)
    if (f.name === "Labels.js")
      while ((m = LABEL.exec(f.text))) found.set(JSON.parse('"' + m[1] + '"'), f.name)
  }
  return found
}

test("every text passed to t() has a Spanish translation", () => {
  const es = I18n.STRINGS.es
  const missing = [...used()].filter(([s]) => !Object.prototype.hasOwnProperty.call(es, s))
  assert.deepEqual(missing.map(([s, f]) => `${f}: ${s}`), [])
})

test("every Spanish translation is used by some t() call", () => {
  const u = used()
  assert.deepEqual(Object.keys(I18n.STRINGS.es).filter(k => !u.has(k)), [])
})

test("every translation keeps the %N placeholders of its key", () => {
  const marks = s => [...new Set(s.match(/%\d+/g) || [])].sort()
  for (const [k, v] of Object.entries(I18n.STRINGS.es))
    assert.deepEqual(marks(v), marks(k), `placeholders differ in "${k}"`)
})
```

`tests/test_messages.py`:

```python
"""The scripts' messages: every msg in bin/ has its Spanish in
bin/messages.es.json, none is left over, the %N match, and msg picks the
language the way the panel does."""
import json
from pathlib import Path
import re
import subprocess

from scripttest import BIN, ScriptTest

TABLE = BIN / 'messages.es.json'
BASH = re.compile(r'\bmsg\s+"((?:[^"\\$]|\\.)*)"')
PYTHON = re.compile(r"\bmsg\(\s*'((?:[^'\\]|\\.)*)'")


def used():
    keys = {}
    for path in sorted(BIN.rglob('*')):
        if not path.is_file() or path.suffix == '.json':
            continue
        text = path.read_text(errors='replace')
        for m in BASH.finditer(text):
            keys[m[1].replace('\\"', '"')] = path.name
        for m in PYTHON.finditer(text):
            keys[m[1].replace("\\'", "'")] = path.name
    return keys


def marks(text):
    return sorted(set(re.findall(r'%\d+', text)))


class MessagesTest(ScriptTest):
    def test_every_message_has_a_translation(self):
        table = json.loads(TABLE.read_text())
        missing = [f'{f}: {k}' for k, f in used().items() if k not in table]
        self.assertEqual(missing, [])

    def test_every_translation_is_used(self):
        keys = used()
        self.assertEqual([k for k in json.loads(TABLE.read_text()) if k not in keys], [])

    def test_translations_keep_their_placeholders(self):
        for key, value in json.loads(TABLE.read_text()).items():
            self.assertEqual(marks(value), marks(key), key)

    def msg(self, *args, **env):
        script = f'source "{BIN}/lib/i18n.sh"; msg "$@"'
        run_env = {**self.env, **env}
        for k in [k for k, v in env.items() if v is None]:
            run_env.pop(k)
        return subprocess.run(['bash', '-c', script, 'msg', *args], env=run_env,
                              capture_output=True, text=True, check=True).stdout.rstrip('\n')

    def test_msg_translates_and_fills_in_one_pass(self):
        self.assertEqual(self.msg('Saved %1 windows from workspace %2', '3', '1', SAVE_THEM_ALL_LANG='es'),
                         'Se guardaron 3 ventanas del escritorio 1')
        self.assertEqual(self.msg('Saved %1 windows from workspace %2', '3', '1'),
                         'Saved 3 windows from workspace 1')
        self.assertEqual(self.msg('%1 opened, %2 already there', '%2', 'x'), '%2 opened, x already there')

    def test_language_comes_from_the_setting_then_the_system(self):
        (self.state_dir / 'settings.json').write_text('{"language": "es"}')
        self.assertEqual(self.msg('Nothing to save', SAVE_THEM_ALL_LANG=None), 'Nada para guardar')
        (self.state_dir / 'settings.json').write_text('{"language": "auto"}')
        self.assertEqual(self.msg('Nothing to save', SAVE_THEM_ALL_LANG=None, LANG='es_AR.UTF-8'), 'Nada para guardar')
        self.assertEqual(self.msg('Nothing to save', SAVE_THEM_ALL_LANG=None, LANG='en_US.UTF-8'), 'Nothing to save')
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL (falta `I18n.js`; `test_messages` no encuentra `bin/messages.es.json`).

- [ ] **Step 3: `I18n.js`**

```js
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
```

- [ ] **Step 4: `bin/lib/i18n.sh` y `bin/messages.es.json`**

`bin/lib/i18n.sh`:

```bash
# shellcheck shell=bash
# Messages for the scripts in bin/, in English or Spanish. The English text is
# the key: bin/messages.es.json holds its Spanish, and %1, %2… take the
# arguments in one pass (a value holding %2 is not filled again). The language
# is SAVE_THEM_ALL_LANG (the panel passes the one it shows), else the choice
# in settings.json, else the system's.

I18N_TABLE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../messages.es.json"

msg_lang() {
  local chosen sys
  case ${SAVE_THEM_ALL_LANG:-} in en | es) echo "$SAVE_THEM_ALL_LANG"; return ;; esac
  chosen=$(jq -r '.language // "auto"' "${SAVE_THEM_ALL_STATE:-$HOME/.local/state/save-them-all}/settings.json" 2>/dev/null || true)
  case $chosen in en | es) echo "$chosen"; return ;; esac
  sys=${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}
  if [[ $sys == es* ]]; then echo es; else echo en; fi
}
MSG_LANG=$(msg_lang)

msg() { # $1 English text with %1, %2…; the rest fill them in
  local text=$1
  shift
  jq -rn --arg t "$text" --arg lang "$MSG_LANG" --slurpfile es "$I18N_TABLE" '
    (if $lang == "es" then ($es[0][$t] // $t) else $t end)
    | gsub("%(?<n>[0-9]+)"; (.n | tonumber) as $i
        | if $i > 0 and $i <= ($ARGS.positional | length) then $ARGS.positional[$i - 1] else "%" + .n end)
  ' --args "$@" 2>/dev/null || printf '%s\n' "$text"
}
```

`bin/messages.es.json`:

```json
{
  "Nothing to save": "Nada para guardar",
  "No windows on workspace %1": "No hay ventanas en el escritorio %1",
  "Saved %1 windows from workspace %2": "Se guardaron %1 ventanas del escritorio %2",
  "Could not switch to workspace %1": "No se pudo pasar al escritorio %1",
  "Nothing saved for workspace %1": "No hay nada guardado para el escritorio %1",
  "Run 'Save them all' first": "Primero usá 'Guardar todas'",
  "No such file: %1": "No existe el archivo: %1",
  "Cannot restore workspace %1": "No se puede restaurar el escritorio %1",
  "(no launcher)": "(sin forma de abrirla)",
  "(not installed)": "(no instalada)",
  "(closed itself)": "(se cerró sola)",
  "%1 opened, %2 already there": "%1 abiertas, %2 ya estaban",
  "Windows: %1 missing": "Ventanas: faltan %1",
  "%1; missing: %2": "%1; faltan: %2",
  "Windows restored on workspace %1": "Ventanas restauradas en el escritorio %1",
  "Restored at login, with gaps": "Restaurado al iniciar, con faltantes",
  "Check workspace %1": "Revisá el escritorio %1",
  "Windows restored at login": "Ventanas restauradas al iniciar",
  "Workspace %1": "Escritorio %1"
}
```

- [ ] **Step 5: Los scripts usan `msg`**

En los tres scripts, debajo de `set -euo pipefail`, poner esto. Si el script ya tiene `BIN_DIR`, como `restore-them-all-at-login`, la línea de `BIN_DIR` va en vez de la suya:

```bash
BIN_DIR=$(dirname "$(readlink -f "$0")")
# shellcheck source=lib/i18n.sh
source "$BIN_DIR/lib/i18n.sh"
```

`bin/save-them-all`:
- `notify "Nothing to save" "No windows on workspace $ws"` → `notify "$(msg "Nothing to save")" "$(msg "No windows on workspace %1" "$ws")"`
- `echo "No windows on workspace $ws" >&2` → `msg "No windows on workspace %1" "$ws" >&2`
- `((QUIET)) || notify "Saved $n windows from workspace $ws" "…"` → `((QUIET)) || notify "$(msg "Saved %1 windows from workspace %2" "$n" "$ws")" "…"` (el segundo argumento no cambia).

`bin/restore-them-all`:
- `echo "Could not switch to workspace $TARGET_WS" >&2` → `msg "Could not switch to workspace %1" "$TARGET_WS" >&2`
- `notify "Nothing saved for workspace $ws" "Run 'Save them all' first"` → `notify "$(msg "Nothing saved for workspace %1" "$ws")" "$(msg "Run 'Save them all' first")"`
- `echo "No such file: $file" >&2` → `msg "No such file: %1" "$file" >&2`
- `notify "Cannot restore workspace $ws" "$(basename "$file"): $problem"` → `notify "$(msg "Cannot restore workspace %1" "$ws")" "$(basename "$file"): $problem"`
- `missing+=("$cls (no launcher)")` → `missing+=("$cls $(msg "(no launcher)")")`; lo mismo con `(not installed)` y `(closed itself)`.
- `summary="$opened opened, $skipped already there"` → `summary=$(msg "%1 opened, %2 already there" "$opened" "$skipped")`
- `notify "Windows: ${#missing[@]} missing" …` → `notify "$(msg "Windows: %1 missing" "${#missing[@]}")" …`
- `echo "$summary; missing: ${missing[*]}" >&2` → `msg "%1; missing: %2" "$summary" "${missing[*]}" >&2`
- `((QUIET)) || notify "Windows restored on workspace $ws" "$summary"` → `((QUIET)) || notify "$(msg "Windows restored on workspace %1" "$ws")" "$summary"`

`bin/restore-them-all-at-login`:
- en `set_autostart`: `echo "Nothing saved for workspace $1" >&2` → `msg "Nothing saved for workspace %1" "$1" >&2`
- `notify "Restored at login, with gaps" "Check workspace $(…)"` → `notify "$(msg "Restored at login, with gaps")" "$(msg "Check workspace %1" "$(printf '%s, ' "${failed[@]}" | sed 's/, $//')")"`
- `notify "Windows restored at login" "Workspace $(…)"` → `notify "$(msg "Windows restored at login")" "$(msg "Workspace %1" "$(printf '%s, ' "${restored[@]}" | sed 's/, $//')")"`

- [ ] **Step 6: Run tests to verify they pass**

Run: `make test`
Expected: PASS. Los tests de la Task 1 siguen en verde (corren con `SAVE_THEM_ALL_LANG=en`), y `test_messages.py` pasa con sus 5 tests.

- [ ] **Step 7: Commit**

```bash
git add I18n.js bin tests
git commit -m "feat: idioma inglés/español para el panel y los scripts"
```

---

### Task 4: `bin/cards`: estado de Hyprflip, ventanas ocultas, capturar y nombres

**Files:**
- Create: `bin/cards`
- Create: `tests/fakes/control.py`, `tests/test_cards_capture.py`
- Modify: `tests/scripttest.py` (`container`, `flip` y `ScriptTest.cards`/`cards_json`)
- Modify: `tests/fakes/hyprctl` (`down`: Hyprland no responde)
- Modify: `bin/messages.es.json`

**Interfaces:**
- Consumes: `bin/messages.es.json` (Task 3), `tests/scripttest.py` (Task 1).
- Produces (todos imprimen un JSON en stdout; ante un error, `cards: <mensaje>` en stderr y salida 1):
  - `bin/cards status` → `{available, reason, hyprland, built_for, hyprflip, create_faces, detail, fix}`. `reason` es uno de `ok | no-hyprland | no-plugin | mismatch | no-helper | protocol | helper`.
  - `bin/cards members --workspace N [--previous FILE]` → `[address…]`: las ventanas de las tarjetas del workspace, que también se guardan aunque estén ocultas.
  - `bin/cards capture --workspace N --addresses JSON` → `{cards, notes}`.
  - `bin/cards name --id N --name TEXT` → `{"ok": true}`.
  - En Python, para las tareas siguientes:
    - las funciones `msg`, `log`, `note`, `hyprctl`, `hypr_json`, `clients`, `active_workspace`, `dispatch`, `plugin_names`, `flip_status`, `helper_snapshot`, `read_file`, `present`, `saved_title`, `app_name`, `set_name`, `read_names`, `addresses_arg`, `workspace_arg` y `whole`;
    - las constantes `ADDRESS`, `AXES`, `MAX_PANES` y `STATE_DIR`;
    - el decorador `@command(name)`.
  - `tests/fakes/control.py`: un helper falso (snapshot y run). Su comportamiento se ajusta con `helper_config(...)`.

- [ ] **Step 1: El helper falso y lo que sigue de la base de tests**

`tests/fakes/control.py` (ejecutable):

```python
#!/usr/bin/env python3
"""A stand-in for Hyprflip's control.py helper (protocol 1).

FAKE_HELPER_STATE (JSON, optional) sets how it behaves:
  protocol (1), available (true), error (""), create_faces (true),
  outcome: "done" | "error" | "hang" | "garbage" (default "done"), message.
Every run request is appended to FAKE_LOG as {"helper": request}. A done
create adds the card to the fake Hyprland state, as Hyprflip would: one
container whose windows share one native group, the visible side's first
window shown."""
import json
import os
import sys
import time

AXES = {'row': 'horizontal', 'column': 'vertical'}


def config():
    try:
        with open(os.environ['FAKE_HELPER_STATE']) as f:
            return json.load(f)
    except (KeyError, OSError, ValueError):
        return {}


def load_hypr():
    with open(os.environ['FAKE_HYPR_STATE']) as f:
        return json.load(f)


def save_hypr(state):
    path = os.environ['FAKE_HYPR_STATE']
    with open(path + '.tmp', 'w') as f:
        json.dump(state, f)
    os.replace(path + '.tmp', path)


def send(kind, **payload):
    print(json.dumps({'type': kind, **payload}), flush=True)


def build(request):
    state = load_hypr()
    clients = {c['address']: c for c in state['clients']}
    faces = [[a.removeprefix('address:') for a in face] for face in request['faces']]
    members = [a for face in faces for a in face]
    if any(a not in clients for a in members):
        return 'Una de las apps elegidas se cerró.'
    flip = state['hyprflip']
    visible = request.get('visible', 0)
    current = faces[visible][0]
    floating = request.get('floating')
    flip['containers'].append({
        'id': max([c['id'] for c in flip['containers']], default=0) + 1,
        'faces': faces, 'current': current, 'active': visible, 'unfolded': False,
        'floating': floating is not None, 'native_group': True,
        'box': floating['at'] + floating['size'] if floating else [0, 0, 0, 0],
        'layouts': [{'axis': AXES[axis], 'focused': 0, 'ratios': ratios}
                    for axis, ratios in zip(request['axes'], request['ratios'])]})
    for a in members:
        clients[a]['grouped'] = list(members)
        clients[a]['hidden'] = a != current
    save_hypr(state)
    return ''


def main():
    cfg = config()
    if sys.argv[1] == 'snapshot':
        state = load_hypr()
        print(json.dumps({
            'protocol': cfg.get('protocol', 1), 'available': cfg.get('available', True),
            'error': cfg.get('error', ''),
            'context': {'instance': 'save-them-all-test', 'workspace': state.get('active_workspace'),
                        'anchor': None, 'anchor_label': None, 'anchor_token': None},
            'capabilities': {'create_faces': cfg.get('create_faces', True), 'unpair': True,
                             'containers': True, 'max_panes': 5},
            'cards': [], 'shortcuts': {'available': False, 'rows': [], 'occupied': []}}))
        return 0
    request = json.loads(sys.argv[sys.argv.index('--request') + 1])
    with open(os.environ['FAKE_LOG'], 'a') as f:
        f.write(json.dumps({'helper': request}) + '\n')
    send('handoff', id=1)
    line = sys.stdin.readline()
    if (json.loads(line) if line.strip() else {}).get('resume') != 1:
        send('cancelled', message='Cancelado.')
        return 0
    outcome = cfg.get('outcome', 'done')
    if outcome == 'hang':
        time.sleep(60)
    if outcome == 'garbage':
        print('this is not json', flush=True)
        return 3
    if outcome == 'error':
        send('error', message=cfg.get('message', 'Fake failure'))
        return 1
    problem = build(request) if request.get('action') == 'create' else ''
    if problem:
        send('error', message=problem)
        return 1
    send('done', message='')
    return 0


if __name__ == '__main__':
    sys.exit(main())
```

```bash
chmod +x tests/fakes/control.py
```

`tests/fakes/hyprctl`: justo después de `clients = {c['address']: c for c in state.setdefault('clients', [])}`, agregar:

```python
if state.get('down'):
    print('HYPRLAND_INSTANCE_SIGNATURE was set, but no socket found', file=sys.stderr)
    sys.exit(1)
```

`tests/scripttest.py`: agregar después de `saved_window`:

```python
def container(cid, faces, current=None, active=0, floating=False, box=(960, 0, 960, 1080), layouts=None):
    """One card of `hyprctl hyprflip status`."""
    return {'id': cid, 'faces': faces, 'current': current or faces[active][0], 'active': active,
            'unfolded': False, 'floating': floating, 'box': list(box), 'native_group': True,
            'layouts': layouts or [{'axis': 'horizontal', 'focused': 0, 'ratios': [1 / len(f)] * len(f)}
                                   for f in faces]}


def flip(containers=()):
    """`hyprctl hyprflip status` of Hyprflip 0.3.0."""
    return {'version': '0.3.0', 'native_cards': True, 'container_provider': 'native',
            'container_max_panes': 5, 'floating_cards': True, 'workspace_protection': True,
            'transition': 'flip', 'transition_modes': ['flip', 'instant'], 'card_frame': False,
            'card_gap': -1, 'pairs': [], 'containers': list(containers)}
```

y estos métodos al final de `ScriptTest`:

```python
    def cards(self, *args, env=None):
        return subprocess.run([str(BIN / 'cards'), *args], env={**self.env, **(env or {})},
                              capture_output=True, text=True, timeout=60)

    def cards_json(self, *args, env=None):
        r = self.cards(*args, env=env)
        self.assertEqual(r.returncode, 0, r.stderr)
        return json.loads(r.stdout)
```

- [ ] **Step 2: Write the failing test**

`tests/test_cards_capture.py`:

```python
"""bin/cards status, members, capture and name, with a fake Hyprland and a
fake Hyprflip helper."""
import json
from pathlib import Path
import subprocess

from scripttest import BIN, ROOT, ScriptTest, client, container, flip, saved_window

CALC = {'kind': 'app', 'desktop': 'org.gnome.Calculator.desktop'}
OBSIDIAN = {'kind': 'app', 'desktop': 'obsidian.desktop'}


class StatusTest(ScriptTest):
    def test_ok_when_the_plugin_and_the_helper_answer(self):
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip())
        s = self.cards_json('status')
        self.assertEqual((s['available'], s['reason'], s['hyprflip'], s['hyprland']), (True, 'ok', '0.3.0', '0.56.2'))
        self.assertTrue(s['create_faces'])

    def test_not_loaded_says_how_to_install_it(self):
        s = self.cards_json('status')
        self.assertEqual((s['available'], s['reason']), (False, 'no-plugin'))
        self.assertIn('make && python3 scripts/install.py', s['fix'])

    def test_built_for_another_hyprland(self):
        build = Path(self.env['SAVE_THEM_ALL_HYPRFLIP_SRC']) / 'build'
        build.mkdir(parents=True)
        (build / 'CMakeCache.txt').write_text('X:STRING=1\nHYPRLAND_VERSION:INTERNAL=0.56.2\n')
        self.hypr_state(version='0.57.0', configerrors='plugin hyprflip failed to load')
        s = self.cards_json('status')
        self.assertEqual((s['reason'], s['hyprland'], s['built_for']), ('mismatch', '0.57.0', '0.56.2'))
        self.assertIn('failed to load', s['detail'])

    def test_no_hyprland(self):
        self.hypr_state(down=True)
        self.assertEqual(self.cards_json('status')['reason'], 'no-hyprland')

    def test_helper_missing_old_or_failing(self):
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip())
        s = self.cards_json('status', env={'SAVE_THEM_ALL_HYPRFLIP_HELPER': str(self.tmp / 'none.py')})
        self.assertEqual(s['reason'], 'no-helper')
        self.helper_config(protocol=2)
        self.assertEqual(self.cards_json('status')['reason'], 'protocol')
        self.helper_config(available=False, error='boom')
        s = self.cards_json('status')
        self.assertEqual((s['reason'], s['detail']), ('helper', 'boom'))


class MembersTest(ScriptTest):
    def test_members_of_the_workspace_cards(self):
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip([
            container(1, [['0x2'], ['0x3']]), container(2, [['0x8'], ['0x9']])]),
            clients=[client('0x2', 'a'), client('0x3', 'b', hidden=True),
                     client('0x8', 'c', ws=4), client('0x9', 'd', ws=4, hidden=True)])
        self.assertEqual(self.cards_json('members', '--workspace', '3'), ['0x2', '0x3'])

    def test_without_hyprflip_hidden_windows_of_a_saved_card(self):
        previous = self.write_saved(3, [saved_window('kitty', (0, 0), (960, 1080), {'kind': 'terminal'}),
                                        saved_window('org.gnome.Calculator', (960, 0), (960, 1080), CALC),
                                        saved_window('obsidian', (960, 0), (960, 1080), OBSIDIAN)],
                                    cards=[{'faces': [{'windows': [1]}, {'windows': [2]}]}])
        self.hypr_state(clients=[
            client('0x1', 'kitty', hidden=True, grouped=['0x1', '0x4']),
            client('0x2', 'org.gnome.Calculator', grouped=['0x2', '0x3']),
            client('0x3', 'obsidian', hidden=True, grouped=['0x2', '0x3'])])
        self.assertEqual(self.cards_json('members', '--workspace', '3', '--previous', str(previous)), ['0x3'])


class CaptureTest(ScriptTest):
    def capture(self, containers, addresses, clients):
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip(containers), clients=clients)
        return self.cards_json('capture', '--workspace', '3', '--addresses', json.dumps(addresses))

    def test_a_tiled_card_as_indices(self):
        names = self.runtime / 'cards-save-them-all-test.json'
        names.write_text('{"7": "Trading"}')
        card = container(7, [['0x2'], ['0x3', '0x4']], layouts=[
            {'axis': 'horizontal', 'focused': 0, 'ratios': [1.0]},
            {'axis': 'vertical', 'focused': 0, 'ratios': [0.6, 0.3]}])
        out = self.capture([card], ['0x1', '0x2', '0x3', '0x4'],
                           [client(a, 'kitty') for a in ('0x1', '0x2', '0x3', '0x4')])
        self.assertEqual(out['cards'], [{
            'name': 'Trading',
            'faces': [{'windows': [1], 'axis': 'row', 'ratios': [1.0]},
                      {'windows': [2, 3], 'axis': 'column', 'ratios': [0.6667, 0.3333]}],
            'visible': 0, 'floating': None}])
        self.assertEqual(out['notes'], [])

    def test_a_floating_card_keeps_its_place_and_its_visible_side(self):
        card = container(1, [['0x2'], ['0x3']], active=1, floating=True, box=(100, 120, 800, 600))
        out = self.capture([card], ['0x2', '0x3'], [client('0x2', 'a'), client('0x3', 'b')])
        self.assertEqual((out['cards'][0]['visible'], out['cards'][0]['floating']),
                         (1, {'at': [100, 120], 'size': [800, 600]}))

    def test_five_windows_on_a_side(self):
        back = ['0x3', '0x4', '0x5', '0x6', '0x7']
        out = self.capture([container(1, [['0x2'], back])], ['0x2'] + back,
                           [client(a, 'kitty') for a in ['0x2'] + back])
        self.assertEqual(out['cards'][0]['faces'][1]['windows'], [1, 2, 3, 4, 5])

    def test_a_window_that_was_not_saved_leaves_the_card(self):
        out = self.capture([container(1, [['0x2'], ['0x3', '0x9']])], ['0x2', '0x3'],
                           [client('0x2', 'a'), client('0x3', 'b'), client('0x9', 'org.omarchy.screensaver')])
        self.assertEqual(out['cards'][0]['faces'][1]['windows'], [1])
        self.assertEqual(out['notes'], ['screensaver left card a ↔ b + screensaver: it is not among the saved windows'])

    def test_a_side_with_no_saved_window_drops_the_card(self):
        out = self.capture([container(1, [['0x2'], ['0x9']])], ['0x2'],
                           [client('0x2', 'a'), client('0x9', 'org.omarchy.screensaver')])
        self.assertEqual(out['cards'], [])
        self.assertEqual(out['notes'][-1], 'Card a ↔ screensaver was not saved: one of its sides has no saved window')

    def test_cards_of_other_workspaces_are_not_captured(self):
        out = self.capture([container(1, [['0x8'], ['0x9']])], [], [client('0x8', 'a', ws=4), client('0x9', 'b', ws=4)])
        self.assertEqual(out, {'cards': [], 'notes': []})


class ReadFileTest(ScriptTest):
    def test_invalid_cards_block_is_ignored(self):
        windows = [saved_window('a', (0, 0), (10, 10), None), saved_window('b', (10, 0), (10, 10), None)]
        bad = [
            'nope',
            {'faces': [{'windows': [0]}]},
            {'faces': [{'windows': [0]}, {'windows': []}]},
            {'faces': [{'windows': [0]}, {'windows': [7]}]},
            {'faces': [{'windows': [0]}, {'windows': [True]}]},
            {'faces': [{'windows': [0]}, {'windows': [0]}]},
            {'faces': [{'windows': [0], 'axis': 'diagonal'}, {'windows': [1]}]},
            {'faces': [{'windows': [0]}, {'windows': [1], 'ratios': [2]}]},
            {'faces': [{'windows': [0]}, {'windows': [1]}], 'visible': True},
            {'faces': [{'windows': [0]}, {'windows': [1]}], 'floating': {'at': [0, 0]}},
            {'faces': [{'windows': [0]}, {'windows': [1]}], 'name': 7},
        ]
        for card in bad:
            with self.subTest(card=card):
                path = self.write_saved(3, windows, cards=[card])
                out = self.cards_json('layout', '--file', str(path), '--addresses', '["0x1", "0x2"]') \
                    if (BIN / 'cards').read_text().count("@command('layout')") else None
                code = ("import importlib.machinery, importlib.util, json, sys\n"
                        "loader = importlib.machinery.SourceFileLoader('cards', sys.argv[1])\n"
                        "spec = importlib.util.spec_from_loader('cards', loader)\n"
                        "cards = importlib.util.module_from_spec(spec)\n"
                        "loader.exec_module(cards)\n"
                        "w, c, p = cards.read_file(__import__('pathlib').Path(sys.argv[2]))\n"
                        "print(json.dumps([len(w), c, p]))")
                n, cards, problem = json.loads(subprocess.run(
                    ['python3', '-c', code, str(BIN / 'cards'), str(path)], env=self.env,
                    capture_output=True, text=True, check=True).stdout)
                self.assertEqual((n, cards), (2, []))
                self.assertTrue(problem.startswith('card 1 '), problem)
                if out is not None:
                    self.assertEqual(out, {'hide': [], 'slots': []})

    def test_two_cards_sharing_a_window(self):
        windows = [saved_window(c, (0, 0), (10, 10), None) for c in 'abc']
        path = self.write_saved(3, windows, cards=[{'faces': [{'windows': [0]}, {'windows': [1]}]},
                                                   {'faces': [{'windows': [2]}, {'windows': [1]}]}])
        code = ("import importlib.machinery, importlib.util, json, sys\n"
                "loader = importlib.machinery.SourceFileLoader('cards', sys.argv[1])\n"
                "spec = importlib.util.spec_from_loader('cards', loader)\n"
                "cards = importlib.util.module_from_spec(spec)\n"
                "loader.exec_module(cards)\n"
                "print(json.dumps(cards.read_file(__import__('pathlib').Path(sys.argv[2]))[1:]))")
        cards, problem = json.loads(subprocess.run(['python3', '-c', code, str(BIN / 'cards'), str(path)],
                                                   env=self.env, capture_output=True, text=True, check=True).stdout)
        self.assertEqual((cards, problem), ([], 'a window is in two cards'))


class NamesTest(ScriptTest):
    def test_names_are_cleaned_and_an_empty_one_is_forgotten(self):
        self.cards_json('name', '--id', '7', '--name', '  Trading\x07 ')
        path = self.runtime / 'cards-save-them-all-test.json'
        self.assertEqual(json.loads(path.read_text()), {'7': 'Trading'})
        self.cards_json('name', '--id', '7', '--name', '')
        self.assertEqual(json.loads(path.read_text()), {})

    def test_names_match_appnames_js(self):
        classes = ['chrome-youtube.com__-Default', 'org.gnome.Calculator', 'obsidian',
                   'org.omarchy.btop', 'chrome-x.com__a-Default', 'weird', '']
        script = ("const {load} = require('./tests/load.js'); const {readEntries} = require('./tests/desktop.js');"
                  "const A = load('AppNames.js'); const e = readEntries('tests/fixtures/applications');"
                  "console.log(JSON.stringify(JSON.parse(process.argv[1]).map(c => A.resolve({class: c}, e).name)))")
        js = json.loads(subprocess.run(['node', '-e', script, json.dumps(classes)], cwd=ROOT,
                                       capture_output=True, text=True, check=True).stdout)
        code = ("import importlib.machinery, importlib.util, json, sys\n"
                "loader = importlib.machinery.SourceFileLoader('cards', sys.argv[1])\n"
                "spec = importlib.util.spec_from_loader('cards', loader)\n"
                "cards = importlib.util.module_from_spec(spec)\n"
                "loader.exec_module(cards)\n"
                "print(json.dumps([cards.app_name(c) for c in json.loads(sys.argv[2])]))")
        py = json.loads(subprocess.run(['python3', '-c', code, str(BIN / 'cards'), json.dumps(classes)],
                                       env=self.env, capture_output=True, text=True, check=True).stdout)
        self.assertEqual(py, js)
```

Nota: `test_invalid_cards_block_is_ignored` prueba `read_file` directamente. Cuando la Task 7 agregue `layout`, el mismo test comprueba además que `layout` no esconde nada con un bloque inválido: por eso el `if … count("@command('layout')")`.

- [ ] **Step 3: Run test to verify it fails**

Run: `make test`
Expected: FAIL (`bin/cards` no existe).

- [ ] **Step 4: `bin/cards`**

`bin/cards` (ejecutable):

```python
#!/usr/bin/env python3
"""cards: Save Them All's side of Hyprflip cards.

    cards status                                 can Hyprflip be used; if not, why and how to fix it
    cards members  --workspace N [--previous F]  hidden windows of the workspace's cards, to save too
    cards capture  --workspace N --addresses A   the workspace's cards, as indices into the saved windows
    cards name     --id N --name TEXT            remember a card's name for this Hyprland session

Every command prints one JSON value. A (--addresses) is a JSON list aligned
with the windows of a workspace file: each window's address, or null when it
is not open. A state file is data: nothing read from it is ever run.
"""
import argparse
from datetime import datetime, timezone
from functools import lru_cache
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import threading
import time

HOME = Path(os.environ.get('HOME') or Path.home())
STATE_DIR = Path(os.environ.get('SAVE_THEM_ALL_STATE') or HOME / '.local/state/save-them-all')
HELPER = Path(os.environ.get('SAVE_THEM_ALL_HYPRFLIP_HELPER') or HOME / '.local/lib/hyprflip/control.py')
SOURCE = Path(os.environ.get('SAVE_THEM_ALL_HYPRFLIP_SRC') or HOME / '.local/src/hyprflip-omacards')
MESSAGES = Path(__file__).resolve().parent / 'messages.es.json'
ADDRESS = re.compile(r'^0x[0-9a-f]{1,16}$')
AXES = {'horizontal': 'row', 'vertical': 'column'}
MAX_PANES = 5
COMMANDS = {}


class CardsError(RuntimeError):
    """Something to tell the user; the message is already in their language."""


class HyprError(CardsError):
    """hyprctl failed or answered something unreadable."""


def command(name):
    def register(fn):
        COMMANDS[name] = fn
        return fn
    return register


# -- language --------------------------------------------------------------

@lru_cache(maxsize=1)
def language():
    """SAVE_THEM_ALL_LANG, else settings.json, else the system: as bin/lib/i18n.sh."""
    chosen = os.environ.get('SAVE_THEM_ALL_LANG', '')
    if chosen in ('en', 'es'):
        return chosen
    try:
        chosen = json.loads((STATE_DIR / 'settings.json').read_text()).get('language')
    except (OSError, ValueError, AttributeError):
        chosen = None
    if chosen in ('en', 'es'):
        return chosen
    system = os.environ.get('LC_ALL') or os.environ.get('LC_MESSAGES') or os.environ.get('LANG') or ''
    return 'es' if system.startswith('es') else 'en'


@lru_cache(maxsize=1)
def spanish():
    try:
        return json.loads(MESSAGES.read_text())
    except (OSError, ValueError):
        return {}


def msg(text, *args):
    """The English text in the user's language, with %1, %2… filled in one pass."""
    if language() == 'es':
        text = spanish().get(text, text)

    def fill(m):
        n = int(m[1])
        return str(args[n - 1]) if 0 < n <= len(args) else m[0]
    return re.sub(r'%(\d+)', fill, text)


def log(line):
    stamp = datetime.now(timezone.utc).astimezone().isoformat(timespec='seconds')
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        with open(STATE_DIR / 'restore.log', 'a') as f:
            f.write(f'{stamp} {line}\n')
    except OSError:
        pass


def note(text):
    """A note for the final notification, also kept in restore.log."""
    log(text)
    return text


# -- Hyprland and Hyprflip ---------------------------------------------------

def hyprctl(*args):
    """hyprctl's answer as text, or HyprError."""
    try:
        done = subprocess.run(['hyprctl', *args], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise HyprError(str(error)) from error
    reply = done.stdout.strip()
    if done.returncode or reply.startswith('error') or 'Lua error' in reply:
        raise HyprError(reply or done.stderr.strip() or 'hyprctl ' + ' '.join(args))
    return reply


def hypr_json(*args):
    reply = hyprctl(*args)
    try:
        return json.loads(reply)
    except ValueError as error:
        raise HyprError(reply[:200]) from error


def clients():
    return {c['address']: c for c in hypr_json('-j', 'clients') if isinstance(c, dict) and 'address' in c}


def active_workspace():
    return hypr_json('-j', 'activeworkspace')['id']


def dispatch(expression):
    hyprctl('dispatch', expression)


def focus(address):
    return f"hl.dsp.focus({{ window = 'address:{address}' }})"


def move_to(address, workspace):
    return f"hl.dsp.window.move({{ window = 'address:{address}', workspace = '{workspace}', follow = false }})"


def plugin_names():
    try:
        plugins = json.loads(hyprctl('-j', 'plugin', 'list'))
    except (HyprError, ValueError):
        return []   # hyprctl says "no plugins loaded" in plain text
    return [p.get('name') for p in plugins if isinstance(p, dict)] if isinstance(plugins, list) else []


def flip_status():
    """`hyprctl hyprflip status`, or None when Hyprflip is not loaded."""
    if 'hyprflip' not in plugin_names():
        return None
    state = hypr_json('hyprflip', 'status')
    return state if isinstance(state, dict) else None


def helper_snapshot():
    try:
        done = subprocess.run(['python3', str(HELPER), 'snapshot'], capture_output=True, text=True, timeout=15)
        value = json.loads(done.stdout)
    except (OSError, subprocess.TimeoutExpired, ValueError) as error:
        raise CardsError(msg('The Hyprflip helper did not answer: %1', error)) from error
    if not isinstance(value, dict):
        raise CardsError(msg('The Hyprflip helper did not answer: %1', done.stdout[:200]))
    return value


def built_for():
    try:
        text = (SOURCE / 'build' / 'CMakeCache.txt').read_text(errors='replace')
    except OSError:
        return ''
    m = re.search(r'^HYPRLAND_VERSION:[A-Z]+=(.+)$', text, re.M)
    return m[1].strip() if m else ''


@command('status')
def status(args):
    report = {'available': False, 'reason': '', 'hyprland': '', 'built_for': built_for(),
              'hyprflip': '', 'create_faces': False, 'detail': '', 'fix': ''}
    rebuild = f'cd {SOURCE} && make && python3 scripts/install.py'
    try:
        report['hyprland'] = str(hypr_json('-j', 'version').get('version', ''))
    except HyprError as error:
        report.update(reason='no-hyprland', detail=str(error))
        return report
    loaded = 'hyprflip' in plugin_names()
    if not loaded:
        try:
            errors = hyprctl('configerrors')
        except HyprError:
            errors = ''
        mismatch = report['built_for'] and report['built_for'] != report['hyprland']
        report.update(reason='mismatch' if mismatch else 'no-plugin', detail=errors.strip()[:300], fix=rebuild)
        return report
    try:
        report['hyprflip'] = str((flip_status() or {}).get('version', ''))
    except HyprError as error:
        report.update(reason='no-plugin', detail=str(error), fix=rebuild)
        return report
    if not HELPER.is_file():
        report.update(reason='no-helper', fix=f'python3 {SOURCE}/scripts/install-setup.py --backend-only')
        return report
    try:
        snapshot = helper_snapshot()
    except CardsError as error:
        report.update(reason='protocol', detail=str(error), fix=f'python3 {SOURCE}/scripts/install-setup.py --backend-only')
        return report
    if snapshot.get('protocol') != 1:
        report.update(reason='protocol', fix=f'python3 {SOURCE}/scripts/install-setup.py --backend-only')
        return report
    if not snapshot.get('available'):
        report.update(reason='helper', detail=str(snapshot.get('error') or ''))
        return report
    report.update(available=True, reason='ok',
                  create_faces=bool((snapshot.get('capabilities') or {}).get('create_faces')))
    return report


# -- names -------------------------------------------------------------------

@lru_cache(maxsize=1)
def desktop_entries():
    dirs = [os.environ.get('XDG_DATA_HOME') or str(HOME / '.local/share')]
    dirs += (os.environ.get('XDG_DATA_DIRS') or '/usr/local/share:/usr/share').split(':')
    seen, entries = set(), []
    for d in dirs:
        if not d:
            continue
        folder = Path(d) / 'applications'
        try:
            listing = sorted(os.listdir(folder))
        except OSError:
            continue
        for name in listing:
            if not name.endswith('.desktop') or name in seen:
                continue
            seen.add(name)
            fields, section = {}, None
            try:
                for line in (folder / name).read_text(errors='replace').splitlines():
                    line = line.strip()
                    if line.startswith('['):
                        section = line
                    elif section == '[Desktop Entry]' and '=' in line:
                        key, value = line.split('=', 1)
                        fields.setdefault(key.strip(), value.strip())
            except OSError:
                continue
            entries.append({'id': name, 'name': fields.get('Name', ''),
                            'startupClass': fields.get('StartupWMClass', ''), 'exec': fields.get('Exec', '')})
    return entries


def url_class(url):
    u = re.sub(r'^[^:/]*://', '', str(url))
    u = u.split('?')[0].split('#')[0]
    host, _, path = u.partition('/')
    return f'chrome-{host}__{path.replace("/", "_")}-Default'


def webapp_url(exec_line):
    m = re.match(r'^omarchy-launch-webapp\s+"?([^"\s]+)"?', exec_line or '')
    return m[1].replace('%%', '%') if m else ''


def app_name(cls, launch=None):
    """A window's readable name: the same answer as AppNames.resolve in the panel."""
    cls = str(cls or '')
    entries = desktop_entries()
    web = cls
    if isinstance(launch, dict) and launch.get('kind') == 'webapp' and launch.get('url'):
        web = url_class(launch['url'])
    if re.match(r'^chrome-.+-Default$', web):
        for e in entries:
            url = webapp_url(e['exec'])
            if url and url_class(url) == web:
                return e['name']
    lower = cls.lower()
    if lower:
        for e in entries:
            if e['startupClass'].lower() == lower:
                return e['name']
        for e in entries:
            if e['id'].removesuffix('.desktop').lower() == lower:
                return e['name']
    host = re.match(r'^chrome-([^_]+)__.*-Default$', web)
    if host:
        return host[1]
    parts = cls.split('.')
    if len(parts) >= 3 and parts[-1]:
        return parts[-1]
    return cls


def clean_name(text):
    return re.sub(r'[\x00-\x1f\x7f]', '', str(text)).strip()[:60]


def names_path():
    runtime = os.environ.get('SAVE_THEM_ALL_RUNTIME') or (
        os.environ['XDG_RUNTIME_DIR'] + '/save-them-all' if os.environ.get('XDG_RUNTIME_DIR') else '')
    instance = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')
    if not runtime or not instance or '/' in instance:
        return None
    return Path(runtime) / f'cards-{instance}.json'


def read_names():
    """Card names of this Hyprland session, by Hyprflip container id."""
    path = names_path()
    try:
        data = json.loads(path.read_text()) if path else {}
    except (OSError, ValueError):
        return {}
    return {str(k): clean_name(v) for k, v in data.items() if isinstance(v, str)} if isinstance(data, dict) else {}


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix='.cards.')
    with os.fdopen(fd, 'w') as f:
        json.dump(value, f, ensure_ascii=False, indent=2)
        f.write('\n')
    os.replace(tmp, path)


def set_name(cid, name):
    path = names_path()
    if path is None:
        return
    names = read_names()
    name = clean_name(name)
    if name:
        names[str(cid)] = name
    else:
        names.pop(str(cid), None)
    write_json(path, names)


@command('name')
def name(args):
    if not re.fullmatch(r'\d{1,9}', args.id or ''):
        raise CardsError(msg('--id must be a card number'))
    set_name(int(args.id), args.name or '')
    return {'ok': True}


# -- workspace files -----------------------------------------------------------

def whole(v):
    return type(v) is int and -1_000_000 < v < 1_000_000


def ratios(values, n):
    if (not isinstance(values, list) or len(values) != n
            or any(type(r) not in (int, float) or r <= 0 for r in values)):
        values = [1] * n
    total = sum(values)
    return [round(r / total, 4) for r in values]


def card_problem(card, count):
    """Why a card read from a state file cannot be used, or ''."""
    if not isinstance(card, dict):
        return msg('is not an object')
    faces = card.get('faces')
    if not isinstance(faces, list) or len(faces) != 2 or not all(isinstance(f, dict) for f in faces):
        return msg('needs exactly two sides')
    seen = []
    for face in faces:
        windows = face.get('windows')
        if (not isinstance(windows, list) or not 1 <= len(windows) <= MAX_PANES
                or any(type(i) is not int or not 0 <= i < count for i in windows)):
            return msg('needs 1 to 5 window numbers on each side')
        seen += windows
        if face.get('axis', 'row') not in ('row', 'column'):
            return msg('axis must be row or column')
        values = face.get('ratios')
        if values is not None and (not isinstance(values, list) or len(values) != len(windows)
                                   or any(type(r) not in (int, float) or not 0 < r <= 1 for r in values)):
            return msg('ratios must be one number between 0 and 1 per window')
    if len(set(seen)) != len(seen):
        return msg('repeats a window')
    visible = card.get('visible', 0)
    if type(visible) is not int or visible not in (0, 1):
        return msg('visible must be 0 or 1')
    floating = card.get('floating')
    if floating is not None:
        def pair(v):
            return isinstance(v, list) and len(v) == 2 and all(whole(n) for n in v)
        if (not isinstance(floating, dict) or not pair(floating.get('at')) or not pair(floating.get('size'))
                or min(floating['size']) < 1):
            return msg('floating must be null or {at, size} with whole numbers')
    if not isinstance(card.get('name', ''), str):
        return msg('name must be text')
    return ''


def read_file(path):
    """(windows, cards, problem) of a workspace file. Anything wrong in the
    cards block drops the whole block, never the windows."""
    try:
        data = json.loads(Path(path).read_text())
    except (OSError, ValueError) as error:
        return [], [], str(error)
    windows = data.get('windows') if isinstance(data, dict) else None
    if not isinstance(windows, list):
        return [], [], msg('it has no windows list')
    raw = data.get('cards')
    if raw is None:
        return windows, [], ''
    if not isinstance(raw, list):
        return windows, [], msg('cards must be a list')
    cards = []
    for n, card in enumerate(raw, 1):
        problem = card_problem(card, len(windows))
        if problem:
            return windows, [], msg('card %1 %2', n, problem)
        cards.append({'name': clean_name(card.get('name', '')),
                      'faces': [{'windows': list(f['windows']), 'axis': f.get('axis', 'row'),
                                 'ratios': ratios(f.get('ratios'), len(f['windows']))} for f in card['faces']],
                      'visible': card.get('visible', 0), 'floating': card.get('floating')})
    seen = [i for c in cards for f in c['faces'] for i in f['windows']]
    if len(set(seen)) != len(seen):
        return windows, [], msg('a window is in two cards')
    return windows, cards, ''


def present(card, addresses):
    """The card's sides as the addresses of its windows that are open."""
    return [[addresses[i] for i in f['windows'] if i < len(addresses) and addresses[i]] for f in card['faces']]


def saved_title(card, windows):
    if card['name']:
        return card['name']

    def label(i):
        w = windows[i] if 0 <= i < len(windows) and isinstance(windows[i], dict) else {}
        return app_name(w.get('class'), w.get('launch'))
    return ' ↔ '.join(' + '.join(label(i) for i in f['windows']) for f in card['faces'])


def live_title(card, now, names):
    return names.get(str(card.get('id'))) or ' ↔ '.join(
        ' + '.join(app_name(now.get(a, {}).get('class')) for a in f) for f in card.get('faces', []))


def workspace_arg(args):
    if not re.fullmatch(r'\d{1,6}', args.workspace or '') or int(args.workspace) < 1:
        raise CardsError(msg('--workspace must be a workspace number'))
    return int(args.workspace)


def addresses_arg(args):
    try:
        value = json.loads(args.addresses or '')
    except ValueError:
        value = None
    if not isinstance(value, list) or any(
            a is not None and (not isinstance(a, str) or not ADDRESS.match(a)) for a in value):
        raise CardsError(msg('--addresses must be a JSON list of window addresses or null'))
    return value


# -- saving --------------------------------------------------------------------

def card_classes(path):
    """Classes of the windows of the cards saved in a file."""
    windows, cards, problem = read_file(path)
    if problem:
        return set()
    return {windows[i].get('class') for c in cards for f in c['faces'] for i in f['windows']
            if isinstance(windows[i], dict)}


@command('members')
def members(args):
    ws = workspace_arg(args)
    now = clients()
    try:
        state = flip_status()
    except HyprError:
        state = None
    if state:
        found = [a for card in state.get('containers', [])
                 if now.get(card.get('current'), {}).get('workspace', {}).get('id') == ws
                 for face in card.get('faces', []) for a in face if a in now]
    elif args.previous:
        classes = card_classes(Path(args.previous))
        found = [a for a, c in now.items() if c.get('workspace', {}).get('id') == ws
                 and c.get('hidden') and c.get('grouped') and c.get('class') in classes]
    else:
        found = []
    return sorted(set(found))


@command('capture')
def capture(args):
    ws = workspace_arg(args)
    index = {a: i for i, a in enumerate(addresses_arg(args)) if a}
    now = clients()
    state = flip_status() or {}
    names = read_names()
    cards, notes = [], []
    for card in state.get('containers', []):
        if now.get(card.get('current'), {}).get('workspace', {}).get('id') != ws:
            continue
        title = live_title(card, now, names)
        layouts = card.get('layouts') or []
        faces = []
        for n, face in enumerate(card.get('faces', [])[:2]):
            layout = layouts[n] if n < len(layouts) and isinstance(layouts[n], dict) else {}
            weights = ratios(layout.get('ratios'), len(face))
            kept = [(index[a], r) for a, r in zip(face, weights) if a in index]
            for a in face:
                if a not in index:
                    notes.append(msg('%1 left card %2: it is not among the saved windows',
                                     app_name(now.get(a, {}).get('class')), title))
            faces.append({'windows': [i for i, _ in kept], 'axis': AXES.get(layout.get('axis'), 'row'),
                          'ratios': ratios([r for _, r in kept], len(kept))})
        if len(faces) != 2 or not all(f['windows'] for f in faces):
            notes.append(msg('Card %1 was not saved: one of its sides has no saved window', title))
            continue
        floating = None
        if card.get('floating'):
            x, y, w, h = (int(round(v)) for v in (list(card.get('box') or []) + [0, 0, 0, 0])[:4])
            floating = {'at': [x, y], 'size': [max(1, w), max(1, h)]}
        cards.append({'name': names.get(str(card.get('id')), ''), 'faces': faces,
                      'visible': 1 if card.get('active') == 1 else 0, 'floating': floating})
    return {'cards': cards, 'notes': notes}


def main(argv=None):
    parser = argparse.ArgumentParser(prog='cards', description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('command', choices=sorted(COMMANDS))
    for option in ('--workspace', '--previous', '--addresses', '--windows', '--file', '--id', '--name'):
        parser.add_argument(option)
    args = parser.parse_args(argv)
    try:
        result = COMMANDS[args.command](args)
    except CardsError as error:
        print(f'cards: {error}', file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    sys.exit(main())
```

```bash
chmod +x bin/cards
```

Nota sobre `test_a_window_that_was_not_saved_leaves_the_card`: el título es el de la tarjeta viva, con todas sus ventanas (`a ↔ b + screensaver`). La que se va se nombra por su parte legible (`screensaver`, la última parte de `org.omarchy.screensaver`).

- [ ] **Step 5: Traducciones**

Agregar a `bin/messages.es.json`:

```json
  "The Hyprflip helper did not answer: %1": "El asistente de Hyprflip no respondió: %1",
  "--id must be a card number": "--id tiene que ser un número de tarjeta",
  "is not an object": "no es un objeto",
  "needs exactly two sides": "necesita exactamente dos caras",
  "needs 1 to 5 window numbers on each side": "necesita de 1 a 5 números de ventana en cada cara",
  "axis must be row or column": "axis tiene que ser row o column",
  "ratios must be one number between 0 and 1 per window": "ratios tiene que ser un número entre 0 y 1 por ventana",
  "repeats a window": "repite una ventana",
  "visible must be 0 or 1": "visible tiene que ser 0 o 1",
  "floating must be null or {at, size} with whole numbers": "floating tiene que ser null o {at, size} con números enteros",
  "name must be text": "name tiene que ser texto",
  "it has no windows list": "no tiene lista de ventanas",
  "cards must be a list": "cards tiene que ser una lista",
  "card %1 %2": "la tarjeta %1 %2",
  "a window is in two cards": "una ventana está en dos tarjetas",
  "--workspace must be a workspace number": "--workspace tiene que ser un número de escritorio",
  "--addresses must be a JSON list of window addresses or null": "--addresses tiene que ser una lista JSON de direcciones de ventana o null",
  "%1 left card %2: it is not among the saved windows": "%1 salió de la tarjeta %2: no está entre las ventanas guardadas",
  "Card %1 was not saved: one of its sides has no saved window": "La tarjeta %1 no se guardó: una de sus caras no tiene ninguna ventana guardada"
```

- [ ] **Step 6: Run test to verify it passes**

Run: `make test`
Expected: PASS (`test_cards_capture.py` completo; `test_messages.py` sigue en verde con las claves nuevas).

- [ ] **Step 7: Commit**

```bash
git add bin tests
git commit -m "feat: bin/cards: estado de Hyprflip, capturar tarjetas y nombres"
```

---

### Task 5: Guardar con tarjetas

**Files:**
- Modify: `bin/cards` (`preserve`)
- Modify: `bin/save-them-all` (ventanas ocultas de tarjetas, bloque `cards`, aviso)
- Modify: `bin/restore-them-all-at-login` (`--list` cuenta tarjetas)
- Modify: `bin/messages.es.json`
- Create: `tests/test_save.py`

**Interfaces:**
- Consumes: `bin/cards status|members|capture` (Task 4).
- Produces:
  - `bin/cards preserve --previous FILE --windows JSON` → `{cards, notes}`. Cada tarjeta del archivo anterior se remapea a los índices de las ventanas nuevas, emparejando clase y `launch` iguales en orden. Una tarjeta que pierde una ventana se descarta con una nota.
  - `workspace-N.json` lleva `cards` solo si hay tarjetas.
  - `restore-them-all-at-login --list` → cada fila suma `cards`.

- [ ] **Step 1: Write the failing test**

`tests/test_save.py`:

```python
"""Saving a workspace saves its cards: from Hyprflip when it is there, kept from
the previous save when it is not."""
import json

from scripttest import ScriptTest, client, container, flip, saved_window

TERMINAL = {'kind': 'terminal'}
CALC = {'kind': 'app', 'desktop': 'org.gnome.Calculator.desktop'}
OBSIDIAN = {'kind': 'app', 'desktop': 'obsidian.desktop'}


class SaveCardsTest(ScriptTest):
    def with_card(self, containers, extra_clients=()):
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip(containers), clients=[
            client('0x1', 'kitty', at=(0, 0), size=(960, 1080), tags=['terminal']),
            client('0x2', 'org.gnome.Calculator', at=(960, 0), size=(960, 1080), grouped=['0x2', '0x3', '0x4']),
            client('0x3', 'obsidian', at=(960, 0), size=(960, 1080), hidden=True, grouped=['0x2', '0x3', '0x4']),
            client('0x4', 'kitty', at=(960, 540), size=(960, 540), hidden=True, grouped=['0x2', '0x3', '0x4'],
                   tags=['terminal']),
            *extra_clients])

    def test_save_writes_the_cards_of_the_workspace(self):
        (self.runtime / 'cards-save-them-all-test.json').write_text('{"7": "Trading"}')
        self.with_card([container(7, [['0x2'], ['0x3', '0x4']], layouts=[
            {'axis': 'horizontal', 'focused': 0, 'ratios': [1.0]},
            {'axis': 'vertical', 'focused': 0, 'ratios': [0.5, 0.5]}])])
        r = self.run_script('save-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        saved = self.saved(3)
        self.assertEqual([w['class'] for w in saved['windows']], ['kitty', 'org.gnome.Calculator', 'obsidian', 'kitty'])
        self.assertEqual(saved['cards'], [{
            'name': 'Trading',
            'faces': [{'windows': [1], 'axis': 'row', 'ratios': [1.0]},
                      {'windows': [2, 3], 'axis': 'column', 'ratios': [0.5, 0.5]}],
            'visible': 0, 'floating': None}])
        self.assertEqual(self.notifications()[-1][0], 'Saved 4 windows and 1 card from workspace 3')

    def test_a_card_left_out_is_told_even_when_quiet(self):
        self.with_card([container(1, [['0x2'], ['0x9']])],
                       [client('0x9', 'org.omarchy.screensaver', at=(960, 0), hidden=True)])
        r = self.run_script('save-them-all', '--quiet')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn('cards', self.saved(3))
        title, body = self.notifications()[-1]
        self.assertEqual(title, 'Saved 2 windows from workspace 3')   # 0x3 and 0x4 are in no card now
        self.assertIn('was not saved: one of its sides has no saved window', body)

    def test_no_cards_block_without_cards(self):
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip(), clients=[client('0x1', 'kitty', tags=['terminal'])])
        self.assertEqual(self.run_script('save-them-all').returncode, 0)
        self.assertNotIn('cards', self.saved(3))

    def test_hidden_members_saved_without_hyprflip(self):
        windows = [saved_window('kitty', (0, 0), (960, 1080), TERMINAL),
                   saved_window('org.gnome.Calculator', (960, 0), (960, 1080), CALC),
                   saved_window('obsidian', (960, 0), (960, 1080), OBSIDIAN)]
        card = {'name': 'Notes', 'faces': [{'windows': [1], 'axis': 'row', 'ratios': [1.0]},
                                           {'windows': [2], 'axis': 'row', 'ratios': [1.0]}],
                'visible': 0, 'floating': None}
        self.write_saved(3, windows, cards=[card])
        self.hypr_state(clients=[   # Hyprflip is gone; its card is a native group now
            client('0x1', 'kitty', at=(0, 0), size=(960, 1080), tags=['terminal']),
            client('0x2', 'org.gnome.Calculator', at=(960, 0), size=(960, 1080), grouped=['0x2', '0x3']),
            client('0x3', 'obsidian', at=(960, 0), size=(960, 1080), hidden=True, grouped=['0x2', '0x3'])])
        r = self.run_script('save-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        saved = self.saved(3)
        self.assertEqual([w['class'] for w in saved['windows']], ['kitty', 'org.gnome.Calculator', 'obsidian'])
        self.assertEqual(saved['cards'], [card])

    def test_preserve_drops_cards_whose_windows_are_gone(self):
        windows = [saved_window('org.gnome.Calculator', (0, 0), (960, 1080), CALC),
                   saved_window('obsidian', (960, 0), (960, 1080), OBSIDIAN)]
        self.write_saved(3, windows, cards=[{'faces': [{'windows': [0]}, {'windows': [1]}]}])
        self.hypr_state(clients=[client('0x2', 'org.gnome.Calculator', at=(0, 0), size=(960, 1080))])
        r = self.run_script('save-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn('cards', self.saved(3))
        self.assertIn('Card Calculator ↔ Obsidian was not kept: some of its windows are no longer saved',
                      self.notifications()[-1][1])

    def test_login_list_counts_cards(self):
        card = {'faces': [{'windows': [0]}, {'windows': [1]}]}
        self.write_saved(3, [saved_window('a', (0, 0), (1, 1), None), saved_window('b', (1, 0), (1, 1), None)],
                         cards=[card])
        self.write_saved(4, [saved_window('a', (0, 0), (1, 1), None)])
        rows = json.loads(self.run_script('restore-them-all-at-login', '--list').stdout)
        self.assertEqual([(x['workspace'], x['cards']) for x in rows], [(3, 1), (4, 0)])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL (el archivo guardado no trae `cards` ni las ventanas ocultas; `--list` no trae `cards`).

- [ ] **Step 3: `preserve` en `bin/cards`**

Agregar antes de `def main`:

```python
@command('preserve')
def preserve(args):
    """The cards of the previous save, moved onto the windows saved now. A
    window matches one with the same class and the same launcher, in order;
    a card that lost a window is dropped, and the notes say so."""
    path = Path(args.previous or '')
    old, cards, problem = read_file(path)
    try:
        new = json.loads(args.windows or '')
    except ValueError:
        new = None
    if not isinstance(new, list):
        raise CardsError(msg('--windows must be a JSON list of saved windows'))
    if problem:
        return {'cards': [], 'notes': [msg('The cards saved before were ignored: %1', problem)] if path.is_file() else []}

    def key(w):
        return (w.get('class'), json.dumps(w.get('launch'), sort_keys=True)) if isinstance(w, dict) else None
    pools = {}
    for i, w in enumerate(new):
        pools.setdefault(key(w), []).append(i)
    mapping, taken = {}, {}
    for i, w in enumerate(old):
        k = key(w)
        n = taken.get(k, 0)
        if k is not None and n < len(pools.get(k, [])):
            mapping[i] = pools[k][n]
            taken[k] = n + 1
    kept, notes = [], []
    for card in cards:
        if all(i in mapping for f in card['faces'] for i in f['windows']):
            kept.append({**card, 'faces': [{**f, 'windows': [mapping[i] for i in f['windows']]}
                                           for f in card['faces']]})
        else:
            notes.append(msg('Card %1 was not kept: some of its windows are no longer saved', saved_title(card, old)))
    return {'cards': kept, 'notes': notes}
```

Y en el docstring del módulo, debajo de la línea de `capture`:

```
    cards preserve --previous F --windows W      the previous save's cards, moved onto the windows saved now
```

- [ ] **Step 4: `save-them-all` guarda tarjetas**

En `bin/save-them-all`, reemplazar desde `ws=$(hyprctl -j activeworkspace | jq -r '.id')` hasta el final del archivo por:

```bash
ws=$(hyprctl -j activeworkspace | jq -r '.id')
monitor=$(hyprctl -j activeworkspace | jq -r '.monitor')
out="$STATE_DIR/workspace-$ws.json"

# A card hides the windows of its other side, and those are saved too: with
# Hyprflip, the members of the workspace's cards; without it, the hidden
# windows of native groups whose class belonged to a card saved before.
flip=$("$BIN_DIR/cards" status 2>/dev/null | jq -r '.available == true' 2>/dev/null || echo false)
if [[ $flip == true ]]; then
  members=$("$BIN_DIR/cards" members --workspace "$ws" 2>/dev/null) || members='[]'
else
  members=$("$BIN_DIR/cards" members --workspace "$ws" --previous "$out" 2>/dev/null) || members='[]'
fi

# Order = left to right, top to bottom: this is what reproduces the dwindle tree.
clients=$(hyprctl -j clients | jq -c --argjson ws "$ws" --arg ex "$EXCLUDE_CLASSES" --argjson members "$members" '
  [.[] | select(.workspace.id == $ws and .mapped
                and (((.hidden // false) | not) or (.address as $a | $members | index($a) != null))
                and ((.class // "") | test($ex) | not))]
  | sort_by(.at[0], .at[1]) | .[]')

entries='[]'
addresses='[]'
lines=()
while IFS= read -r w; do
  [[ -n $w ]] || continue
  cls=$(jq -r .class <<<"$w")
  launch=$(launch_of "$w")
  [[ $launch != null ]] || echo "no desktop entry for $cls: restoring arranges it when open, but cannot reopen it" >&2
  entry=$(jq -c --argjson l "$launch" '{class, title: (.title // ""), launch: $l, at, size, floating}' <<<"$w")
  entries=$(jq -c --argjson e "$entry" '. + [$e]' <<<"$entries")
  addresses=$(jq -c --arg a "$(jq -r .address <<<"$w")" '. + [$a]' <<<"$addresses")
  lines+=("$(jq -r '"\(.size[0])x\(.size[1]) @\(.at[0]),\(.at[1])  \(.class)  ->  \(
    .launch | if . == null then "not reopened" else [.kind, (.session // .url // .desktop // empty)] | join(" ") end)"' <<<"$entry")")
done <<<"$clients"

n=$(jq length <<<"$entries")
if ((n == 0)); then
  notify "$(msg "Nothing to save")" "$(msg "No windows on workspace %1" "$ws")"
  msg "No windows on workspace %1" "$ws" >&2
  exit 1
fi

# The cards: asked to Hyprflip, or kept from the previous save when Hyprflip
# is not there to ask. bin/cards prints {cards, notes}.
none='{"cards":[],"notes":[]}'
result=$none
if [[ $flip == true ]]; then
  if ! result=$("$BIN_DIR/cards" capture --workspace "$ws" --addresses "$addresses" 2>/dev/null); then
    result=$("$BIN_DIR/cards" preserve --previous "$out" --windows "$entries" 2>/dev/null) || result=$none
    result=$(jq -c --arg n "$(msg "Hyprflip did not answer; the cards saved before were kept")" '.notes += [$n]' <<<"$result")
  fi
elif [[ -f $out ]]; then
  result=$("$BIN_DIR/cards" preserve --previous "$out" --windows "$entries" 2>/dev/null) || result=$none
fi
cards=$(jq -c '.cards' <<<"$result")
notes=$(jq -r '.notes[]' <<<"$result")
k=$(jq length <<<"$cards")

mkdir -p "$STATE_DIR"
# Saving again replaces the windows, not the choice to restore them at login.
autostart=$(jq -r 'if .autostart == true then "true" else "false" end' "$out" 2>/dev/null || echo false)
tmp=$(mktemp "$STATE_DIR/.save.XXXXXX")
jq -n --argjson ws "$ws" --arg monitor "$monitor" --arg saved_at "$(date -Is)" \
  --argjson autostart "$autostart" --argjson windows "$entries" --argjson cards "$cards" \
  '{workspace: $ws, monitor: $monitor, saved_at: $saved_at, autostart: $autostart, windows: $windows}
   + (if ($cards | length) > 0 then {cards: $cards} else {} end)' >"$tmp"
mv "$tmp" "$out"

printf '%s\n' "${lines[@]}"
echo "Saved: $out"
if ((k == 0)); then
  title=$(msg "Saved %1 windows from workspace %2" "$n" "$ws")
elif ((k == 1)); then
  title=$(msg "Saved %1 windows and 1 card from workspace %2" "$n" "$ws")
else
  title=$(msg "Saved %1 windows and %2 cards from workspace %3" "$n" "$k" "$ws")
fi
body=$(printf '%s\n' "${lines[@]}" | awk '{print $3}' | paste -sd ', ')
[[ -z $notes ]] || echo "$notes" >&2
# A card left out is news even when the panel asked for quiet.
if ((!QUIET)) || [[ -n $notes ]]; then
  notify "$title" "$body${notes:+$'\n'$notes}"
fi
```

- [ ] **Step 5: `--list` cuenta tarjetas**

En `bin/restore-them-all-at-login`, función `list`, cambiar la línea del objeto por:

```bash
          | {workspace, windows: (.windows | length), cards: (if (.cards | type) == "array" then (.cards | length) else 0 end),
             saved_at, autostart: (.autostart == true)}]
```

- [ ] **Step 6: Traducciones**

Agregar a `bin/messages.es.json`:

```json
  "--windows must be a JSON list of saved windows": "--windows tiene que ser una lista JSON de ventanas guardadas",
  "The cards saved before were ignored: %1": "Se ignoraron las tarjetas guardadas antes: %1",
  "Card %1 was not kept: some of its windows are no longer saved": "La tarjeta %1 no se conservó: algunas de sus ventanas ya no se guardan",
  "Hyprflip did not answer; the cards saved before were kept": "Hyprflip no respondió; se conservaron las tarjetas guardadas antes",
  "Saved %1 windows and 1 card from workspace %2": "Se guardaron %1 ventanas y 1 tarjeta del escritorio %2",
  "Saved %1 windows and %2 cards from workspace %3": "Se guardaron %1 ventanas y %2 tarjetas del escritorio %3"
```

- [ ] **Step 7: Run test to verify it passes**

Run: `make test`
Expected: PASS: `test_save.py` y también `test_legacy.py`, porque sin tarjetas el archivo y la notificación son los de 1.3.

- [ ] **Step 8: Commit**

```bash
git add bin tests
git commit -m "feat: guardar un workspace guarda sus tarjetas"
```

---

### Task 6: Hyprflip: acciones `create` con caras completas y `unpair`

Esta tarea corre en el fork de Hyprflip, no en `$R`.

**Files (en `$H`):**
- Modify: `scripts/control.py`
- Modify: `docs/PANEL_API.md`
- Create: `tests/create_faces_test.py`

**Interfaces:**
- Consumes: `workflow.Setup.eligible`, `workflow.Setup.reserve`, `workflow.Setup.apply_reserved(selected, arrangement, destination)`, `control.resolve_card`, `control.validate_context`, `PanelMenu.channel.handoff()`.
- Produces (protocolo 1, sin cambios para los clientes viejos):
  - `{"action": "create", "context": …, "faces": [["address:0x…", …], […]], "axes": ["row"|"column", …], "ratios": [[…], […]] | null, "visible": 0|1, "floating": null | {"at": [x, y], "size": [w, h]}, "replace": null | {kind, id, token}}` arma la tarjeta entera en una sola transacción y responde `done` con `"Tarjeta creada."` o `"Tarjeta editada."`.
  - Sin `faces`, `create` sigue siendo el flujo interactivo de siempre.
  - `{"action": "unpair", "target": {kind, id, token}}` desarma una tarjeta y sus apps siguen abiertas.
  - `snapshot().capabilities` suma `create_faces: true`, `unpair: true` y `floating_members` (si el plugin puede usar ventanas flotantes).

- [ ] **Step 1: Rama**

```bash
cd ~/.local/src/hyprflip-omacards
git status --short          # expected: nothing (the fork is clean)
git switch -c save-them-all-create es
```

- [ ] **Step 2: Write the failing test**

`tests/create_faces_test.py`:

```python
"""The full-card create and the unpair actions of the panel protocol."""
from contextlib import nullcontext
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from edit_test import CardIPC
from setup_test import setup, window

sys.modules['workflow'] = setup
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
spec = importlib.util.spec_from_file_location('hyprflip_create_faces', Path(__file__).resolve().parents[1] / 'scripts/control.py')
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)


class Request:
    def check(self): pass
    def exclusive(self): return nullcontext()


class Channel:
    def __init__(self): self.handoffs = 0
    def handoff(self): self.handoffs += 1


class FlipIPC(CardIPC):
    """CardIPC with two free apps, five panes a side, and an unpair that
    really removes the card."""
    def __init__(self):
        super().__init__(full=True)
        for address in ('0xe', '0xf'):
            self.clients[address] = window(address)
        self.snapshot.update(container_max_panes=5, floating_cards=True, workspace_protection=False)
        self.calls = []

    def data(self, *args):
        if 'getoption' in args: return {'int': 1}
        return super().data(*args)

    def action(self, action):
        super().action(action)
        if action == 'unpair':
            self.snapshot['containers'] = [c for c in self.snapshot['containers']
                                           if self.active not in [a for f in c['faces'] for a in f]]

    def call(self, *args):
        self.calls.append(args)
        return 'ok'


class CreateFacesTest(unittest.TestCase):
    def setUp(self):
        self.ipc = FlipIPC()
        self.ipc.env = {'HYPRLAND_INSTANCE_SIGNATURE': 'test-instance'}
        self.ctx = control.context(self.ipc)
        card = self.ipc.snapshot['containers'][0]
        self.target = dict(id=1, kind='container',
                           token=control.card_token(card, 'container', self.ipc.windows(), self.ctx['instance']))
        self.channel = Channel()
        apply = patch.object(setup.Setup, 'apply_reserved', autospec=True)
        self.apply = apply.start()
        self.addCleanup(apply.stop)

    def run_action(self, action='create', **extra):
        payload = dict(protocol=1, action=action, context=self.ctx, **extra)
        return control.run_operation(self.ipc, payload, control.PanelMenu(self.channel, Request()))

    def full(self, **overrides):
        request = dict(faces=[['address:0xd'], ['address:0xe', 'address:0xf']], axes=['row', 'column'],
                       ratios=[[1.0], [0.6, 0.4]], visible=1, floating=None)
        request.update(overrides)
        return request

    def test_builds_the_whole_card_in_one_call(self):
        self.assertEqual(self.run_action(**self.full()), 'Tarjeta creada.')
        self.assertEqual(self.channel.handoffs, 1)
        (_, selected, arrangement, destination), _ = self.apply.call_args
        self.assertEqual(list(selected), ['0xd', '0xe', '0xf'])
        self.assertEqual(arrangement, {'faces': [
            {'windows': ['0xd'], 'axis': 'horizontal', 'ratios': [1.0], 'focus': 0},
            {'windows': ['0xe', '0xf'], 'axis': 'vertical', 'ratios': [0.6, 0.4], 'focus': 0}],
            'active': 1, 'floating': False})
        self.assertEqual(destination, 2)

    def test_missing_ratios_are_equal(self):
        self.run_action(**self.full(ratios=None))
        (_, _, arrangement, _), _ = self.apply.call_args
        self.assertEqual(arrangement['faces'][1]['ratios'], [0.5, 0.5])

    def test_closed_window_is_rejected_before_any_mutation(self):
        six = ['address:0xe', 'address:0xf', 'address:0x10', 'address:0x11', 'address:0x12', 'address:0x13']
        for faces in ([['address:0xd'], ['address:0x99']],      # closed
                      [['address:0xd'], []],                    # empty side
                      [['address:0xd']],                        # one side
                      [['address:0xd'], ['address:0xd']],       # twice
                      [['address:0xa'], ['address:0xe']],       # already in a card
                      [['0xd'], ['address:0xe']],               # not an address
                      [['address:0xd'], six]):                  # six on a side
            with self.subTest(faces=faces):
                with self.assertRaises(setup.SetupError):
                    self.run_action(**self.full(faces=faces, axes=['row', 'row'], ratios=None))
        self.assertEqual(self.ipc.mutations, [])
        self.assertEqual(self.channel.handoffs, 0)
        self.apply.assert_not_called()

    def test_bad_axes_ratios_visible_or_floating_are_rejected(self):
        for overrides in ({'axes': ['row', 'diagonal']}, {'ratios': [[1.0], [0.5]]}, {'ratios': [[1.0], [0.5, 0]]},
                          {'visible': 2}, {'visible': True}, {'floating': {'at': [0, 0]}},
                          {'floating': {'at': [0, 0], 'size': [0, 10]}}):
            with self.subTest(overrides=overrides):
                with self.assertRaises(setup.SetupError):
                    self.run_action(**self.full(**overrides))
        self.assertEqual(self.ipc.mutations, [])
        self.apply.assert_not_called()

    def test_floating_card_is_placed_where_it_was(self):
        self.run_action(**self.full(floating={'at': [100, 120], 'size': [800, 600]}))
        (_, _, arrangement, _), _ = self.apply.call_args
        self.assertTrue(arrangement['floating'])
        self.assertEqual(len(self.ipc.calls), 1)
        self.assertIn('window="address:0xe",x=800,y=600', self.ipc.calls[0][1])
        self.assertIn('window="address:0xe",x=100,y=120', self.ipc.calls[0][1])

    def test_floating_needs_floating_cards(self):
        self.ipc.snapshot['floating_cards'] = False
        with self.assertRaises(setup.SetupError):
            self.run_action(**self.full(floating={'at': [0, 0], 'size': [10, 10]}))
        self.apply.assert_not_called()

    def test_replace_unpairs_the_old_card_first(self):
        message = self.run_action(**self.full(faces=[['address:0xb'], ['address:0xa', 'address:0xd']],
                                              ratios=None, replace=self.target))
        self.assertEqual(message, 'Tarjeta editada.')
        self.assertIn(('action', 'unpair'), self.ipc.mutations)
        self.assertEqual(self.ipc.mutations[self.ipc.mutations.index(('action', 'unpair')) - 1], ('focus', '0xb'))
        (_, selected, _, _), _ = self.apply.call_args
        self.assertEqual(list(selected), ['0xb', '0xa', '0xd'])

    def test_failed_replace_rebuilds_the_old_card(self):
        self.apply.side_effect = [setup.SetupError('boom'), None]
        with self.assertRaisesRegex(setup.SetupError, 'boom'):
            self.run_action(**self.full(faces=[['address:0xb'], ['address:0xd']], ratios=None, replace=self.target))
        self.assertEqual(self.apply.call_count, 2)
        (_, selected, arrangement, _), _ = self.apply.call_args
        self.assertEqual([f['windows'] for f in arrangement['faces']], [['0xa'], ['0xb', '0xc']])
        self.assertEqual(arrangement['active'], 1)
        self.assertEqual(list(selected), ['0xa', '0xb', '0xc'])

    def test_replace_of_a_changed_card_is_refused(self):
        with self.assertRaises(setup.SetupError):
            self.run_action(**self.full(replace=dict(self.target, token='stale')))
        self.assertEqual(self.ipc.mutations, [])

    def test_without_faces_create_is_the_old_interactive_flow(self):
        with patch.object(setup.Setup, 'prepare', autospec=True, return_value={'0xd': {}}) as prepare, \
                patch.object(setup.Setup, 'apply', autospec=True, return_value='') as apply:
            self.run_action()
        self.assertEqual(prepare.call_args.args[1], '0xb')
        apply.assert_called_once()

    def test_unpair_releases_the_card(self):
        message = self.run_action('unpair', target=self.target)
        self.assertEqual(message, 'Tarjeta desarmada. Sus apps siguen abiertas.')
        self.assertEqual(self.ipc.mutations[-2:], [('focus', '0xb'), ('action', 'unpair')])
        self.assertEqual(self.ipc.snapshot['containers'], [])

    def test_snapshot_advertises_the_new_actions(self):
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(control.shortcuts, 'snapshot', return_value={'available': False, 'rows': [], 'occupied': []}):
            self.ipc.env['XDG_STATE_HOME'] = directory
            caps = control.snapshot(self.ipc)['capabilities']
        self.assertEqual((caps['create_faces'], caps['unpair'], caps['floating_members']), (True, True, False))


if __name__ == '__main__':
    unittest.main()
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd ~/.local/src/hyprflip-omacards && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'create_faces_test.py'`
Expected: FAIL (`create` sin caras abre el flujo interactivo; `unpair` no es una acción).

- [ ] **Step 4: `control.py`**

Agregar después de la función `edit_prefix`:

```python
FACE_AXES = {'row': 'horizontal', 'column': 'vertical'}


def full_card(ipc, payload, replaced=None):
    """Check a create request that names every pane, before any handoff or
    change. The card being replaced is not in the way of its own windows."""
    windows, state = ipc.windows(), deepcopy(ipc.status())
    own = set()
    if replaced is not None:
        own = {a for face in replaced['faces'] for a in face}
        state['containers'] = [c for c in state.get('containers', []) if c['id'] != replaced['id']]
    limit = state.get('container_max_panes', 1)
    faces = payload.get('faces')
    if (not isinstance(faces, list) or len(faces) != 2
            or any(not isinstance(f, list) or not 1 <= len(f) <= limit for f in faces)):
        raise w.SetupError(f'Cada cara necesita entre 1 y {limit} apps.')
    if any(type(a) is not str or not a.startswith('address:') for f in faces for a in f):
        raise w.SetupError('Nombra cada app por su dirección (address:0x…).')
    faces = [[a.removeprefix('address:') for a in f] for f in faces]
    members = [a for f in faces for a in f]
    if len(set(members)) != len(members):
        raise w.SetupError('Una app no puede estar dos veces en la tarjeta.')
    eligible = set(w.Setup(ipc, None).eligible(windows, state)) | own
    for address in members:
        if address not in windows:
            raise w.SetupError('Una de las apps elegidas se cerró. Vuelve a elegir las apps.')
        if address not in eligible:
            raise w.SetupError(f'{w.app_name(windows[address])} no se puede usar: está en otra tarjeta o grupo, '
                               'en pantalla completa, flotando o en un espacio de trabajo especial.')
    axes = payload.get('axes', ['row', 'row'])
    if not isinstance(axes, list) or len(axes) != 2 or any(a not in FACE_AXES for a in axes):
        raise w.SetupError('El eje de cada cara es row o column.')
    ratios = payload.get('ratios')
    if ratios is None:
        ratios = [[1 / len(f)] * len(f) for f in faces]
    if (not isinstance(ratios, list) or len(ratios) != 2
            or any(not isinstance(r, list) or len(r) != len(f)
                   or any(type(x) not in (int, float) or not 0 < x <= 1 for x in r)
                   for r, f in zip(ratios, faces))):
        raise w.SetupError('Las proporciones de cada cara son números entre 0 y 1, uno por app.')
    ratios = [[x / sum(r) for x in r] for r in ratios]
    visible = payload.get('visible', 0)
    if type(visible) is not int or visible not in (0, 1):
        raise w.SetupError('La cara visible es 0 (Frente) o 1 (Reverso).')
    floating = payload.get('floating')
    if floating is not None:
        def pair(v):
            return isinstance(v, list) and len(v) == 2 and all(type(n) is int for n in v)
        if (not isinstance(floating, dict) or not pair(floating.get('at')) or not pair(floating.get('size'))
                or min(floating['size']) < 1):
            raise w.SetupError('Una tarjeta flotante necesita at [x, y] y size [ancho, alto] enteros.')
        if not state.get('floating_cards'):
            raise w.SetupError('Esta versión de Hyprflip no tiene tarjetas flotantes. Actualiza Hyprflip.')
    arrangement = {'faces': [{'windows': f, 'axis': FACE_AXES[a], 'ratios': r, 'focus': 0}
                             for f, a, r in zip(faces, axes, ratios)],
                   'active': visible, 'floating': floating is not None}
    return faces, arrangement, floating


def selection(ipc, faces):
    """The windows in apply_reserved's order: each side's first, then the rest."""
    windows = ipc.windows()
    order = [faces[0][0], faces[1][0]] + faces[0][1:] + faces[1][1:]
    return deepcopy({a: windows[a] for a in order})


def previous_arrangement(card):
    layouts = card.get('layouts') or [{}, {}]
    return {'faces': [{'windows': list(f), 'axis': layouts[i].get('axis', 'horizontal'),
                       'ratios': layouts[i].get('ratios') or [1 / len(f)] * len(f), 'focus': 0}
                      for i, f in enumerate(card['faces'])],
            'active': card.get('active', 0), 'floating': bool(card.get('floating'))}


def create_full(ipc, payload, menu, ctx):
    """Create, or replace, a whole card in one transaction."""
    request = menu.request
    replace = payload.get('replace')
    old = resolve_card(ipc, replace, ctx)[0] if replace is not None else None
    if old is not None and ipc.windows()[old['current']]['workspace']['id'] != ctx['workspace']:
        raise w.SetupError('Ve al espacio de trabajo de esta tarjeta antes de editarla.')
    full_card(ipc, payload, old)
    menu.channel.handoff()
    validate_context(ipc, ctx)
    if old is not None:
        old = resolve_card(ipc, replace, ctx)[0]
    faces, arrangement, floating = full_card(ipc, payload, old)
    flow = w.Setup(ipc, menu)
    with request.exclusive():
        request.check()
        previous = previous_arrangement(old) if old is not None else None
        if old is not None:
            ipc.focused((old['current'], 'unpair'))
        try:
            selected = selection(ipc, faces)
            with flow.reserve(selected, ipc.status(), ctx['workspace']):
                flow.apply_reserved(selected, arrangement, ctx['workspace'])
        except Exception as error:
            if previous is not None:
                try:
                    restored = selection(ipc, [f['windows'] for f in previous['faces']])
                    with flow.reserve(restored, ipc.status(), ctx['workspace']):
                        flow.apply_reserved(restored, previous, ctx['workspace'])
                except Exception:
                    raise w.SetupError(f'{error} Tampoco se pudo volver a armar la tarjeta anterior; '
                                       'sus apps siguen abiertas.') from error
            raise
        if floating:
            shown = arrangement['faces'][arrangement['active']]['windows'][0]
            x, y = floating['at']
            width, height = floating['size']
            ipc.call('eval', f'hl.dispatch(hl.dsp.window.resize({{window="address:{shown}",x={width},y={height}}})); '
                     f'hl.dispatch(hl.dsp.window.move({{window="address:{shown}",x={x},y={y}}}))')
    return 'Tarjeta editada.' if old is not None else 'Tarjeta creada.'


def unpair(ipc, payload, menu, ctx):
    """Take a card apart; its apps stay open as separate windows."""
    card, windows, state = resolve_card(ipc, payload.get('target'), ctx)
    if windows[card['current']]['workspace']['id'] != ctx['workspace']:
        raise w.SetupError('Ve al espacio de trabajo de esta tarjeta antes de editarla.')
    if state.get('animating'):
        raise w.SetupError('Espera a que termine el giro e inténtalo de nuevo.')
    menu.channel.handoff()
    validate_context(ipc, ctx)
    card = resolve_card(ipc, payload['target'], ctx)[0]
    with menu.request.exclusive():
        menu.request.check()
        ipc.focused((card['current'], 'unpair'))
    return 'Tarjeta desarmada. Sus apps siguen abiertas.'
```

En `run_operation`:
- en la tupla de acciones permitidas, agregar `'unpair'` después de `'spacing'`;
- debajo de `card = None`, agregar:

```python
    if action == 'create' and 'faces' in payload:
        return create_full(ipc, payload, menu, ctx)
    if action == 'unpair':
        return unpair(ipc, payload, menu, ctx)
```

En `snapshot`, debajo de `base['card_gap'] = state.get('card_gap')`:

```python
        base['capabilities']['create_faces'] = True
        base['capabilities']['unpair'] = True
        base['capabilities']['floating_members'] = bool(state.get('workspace_protection'))
```

- [ ] **Step 5: `docs/PANEL_API.md`**

En la tabla de acciones, reemplazar la fila de `create` por:

```markdown
| `create` | Without `faces`: uses the original focused app (interactive). With `faces`: `[[address…], [address…]]` (1 to `max_panes` `address:0x…` each), `axes` (`row`/`column` per side), optional `ratios` (one number per app), `visible` (0/1), `floating` (`null` or `{at: [x, y], size: [w, h]}`) and optional `replace` (a card `target` to rebuild in place); validated before any change, applied in one transaction. Gated by `capabilities.create_faces` |
| `unpair` | `target`; the apps stay open. Gated by `capabilities.unpair` |
```

- [ ] **Step 6: Run the whole helper suite**

Run: `cd ~/.local/src/hyprflip-omacards && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p '*_test.py'`
Expected: PASS: toda la suite de antes y los 12 tests nuevos.

- [ ] **Step 7: Commit (en el fork)**

```bash
cd ~/.local/src/hyprflip-omacards
git add scripts/control.py docs/PANEL_API.md tests/create_faces_test.py
git commit -m "Acciones create con caras completas y unpair en el protocolo del panel"
```

(El fork no se empuja ni se instala acá. El helper instalado en `~/.local/lib/hyprflip` se actualiza en la Task 17, con backup y con el OK del usuario.)

---

### Task 7: `bin/cards`: el lugar de cada tarjeta, el grupo nativo y "Mostrar las dos caras"

**Files:**
- Modify: `bin/cards` (`layout`, `fallback`, `ungroup`, `fallback_cards`, `build_group`)
- Modify: `bin/messages.es.json`
- Create: `tests/test_cards_fallback.py`

**Interfaces:**
- Consumes: `read_file`, `present`, `saved_title`, `clients`, `dispatch`, `focus`, `move_to`, `active_workspace`, `note`, `app_name` (Task 4).
- Produces:
  - `bin/cards layout --file F --addresses JSON` → `{hide: [i…], slots: [{i, at, size}]}`.
    - En el árbol, cada tarjeta ocupa un solo lugar, el de su "slot": la primera ventana abierta del Frente. El lugar es el rectángulo que cubre la cara que estaba visible.
    - Las demás ventanas de la tarjeta quedan fuera del árbol (`hide`). En una tarjeta flotante quedan fuera todas.
    - Una tarjeta con una cara sin ventanas abiertas no se arma, y sus ventanas quedan en el árbol como cualquier otra.
  - `bin/cards fallback --file F --addresses JSON` → `{built, kept, notes}`: cada tarjeta como grupo nativo, con la cara visible al frente.
  - `bin/cards ungroup --workspace N` → `{released}`.
  - En Python: `fallback_cards(filename, windows, cards, problem, addresses, notes=None)`, para la Task 8.

- [ ] **Step 1: Write the failing test**

`tests/test_cards_fallback.py`:

```python
"""Without Hyprflip, a saved card comes back as a native Hyprland group: every
window a tab, the visible side in front. And "Show both faces" lets go of
every group, so nothing stays hidden."""
import json

from scripttest import ScriptTest, client, saved_window

W = [saved_window('kitty', (0, 0), (960, 1080), None),
     saved_window('org.gnome.Calculator', (960, 0), (960, 540), None),
     saved_window('obsidian', (960, 540), (960, 540), None),
     saved_window('weird', (960, 0), (960, 1080), None)]


def card(front, back, visible=0, floating=None, name=''):
    return {'name': name, 'faces': [{'windows': front, 'axis': 'row', 'ratios': [1 / len(front)] * len(front)},
                                    {'windows': back, 'axis': 'row', 'ratios': [1 / len(back)] * len(back)}],
            'visible': visible, 'floating': floating}


class LayoutTest(ScriptTest):
    def layout(self, cards, addresses=('0x1', '0x2', '0x3', '0x4')):
        path = self.write_saved(3, W, cards=cards)
        return self.cards_json('layout', '--file', str(path), '--addresses', json.dumps(list(addresses)))

    def test_every_member_but_the_slot_waits_outside_the_tree(self):
        out = self.layout([card([3], [1, 2], visible=1)])
        self.assertEqual(out, {'hide': [1, 2], 'slots': [{'i': 3, 'at': [960, 0], 'size': [960, 1080]}]})

    def test_a_floating_card_keeps_all_its_windows_out(self):
        out = self.layout([card([1], [2], floating={'at': [10, 10], 'size': [500, 400]})])
        self.assertEqual(out, {'hide': [1, 2], 'slots': []})

    def test_a_card_with_an_empty_side_stays_in_the_tree(self):
        self.assertEqual(self.layout([card([1], [2])], ('0x1', '0x2', None, None)), {'hide': [], 'slots': []})


class FallbackTest(ScriptTest):
    def fallback(self, cards, addresses=('0x1', '0x2', '0x3', '0x4'), **state):
        path = self.write_saved(3, W, cards=cards)
        self.hypr_state(**({'clients': [client('0x1', 'kitty'), client('0x2', 'org.gnome.Calculator'),
                                        client('0x3', 'obsidian'), client('0x4', 'weird')]} | state))
        return self.cards_json('fallback', '--file', str(path), '--addresses', json.dumps(list(addresses)))

    def test_fallback_groups_every_member(self):
        out = self.fallback([card([1], [2, 3])])
        self.assertEqual(out, {'built': 1, 'kept': 0, 'notes': []})
        c = self.clients_by_address()
        self.assertEqual(sorted(c['0x2']['grouped']), ['0x2', '0x3', '0x4'])
        self.assertEqual({a: c[a]['hidden'] for a in ('0x2', '0x3', '0x4')}, {'0x2': False, '0x3': True, '0x4': True})
        d = self.dispatches()
        self.assertEqual(d[:2], ["hl.dsp.focus({ window = 'address:0x2' })", 'hl.dsp.group.toggle()'])
        self.assertEqual(d.count("hl.dsp.window.move({ into_group = 'l' })"), 2)

    def test_the_visible_back_comes_to_the_front(self):
        self.fallback([card([1], [2, 3], visible=1)])
        c = self.clients_by_address()
        self.assertEqual([a for a in ('0x2', '0x3', '0x4') if not c[a]['hidden']], ['0x3'])

    def test_a_floating_card_floats_the_group_where_it_was(self):
        self.fallback([card([1], [2], floating={'at': [100, 120], 'size': [800, 600]})])
        d = self.dispatches()
        self.assertIn("hl.dsp.window.float({ window = 'address:0x2', state = 'on' })", d)
        self.assertIn("hl.dsp.window.resize({ window = 'address:0x2', x = 800, y = 600, exact = true })", d)
        self.assertIn("hl.dsp.window.move({ window = 'address:0x2', x = 100, y = 120, exact = true })", d)

    def test_fallback_leaves_an_existing_group_alone(self):
        grouped = [client('0x1', 'kitty'), client('0x2', 'org.gnome.Calculator', grouped=['0x2', '0x3']),
                   client('0x3', 'obsidian', hidden=True, grouped=['0x2', '0x3']), client('0x4', 'weird')]
        out = self.fallback([card([1], [2])], clients=grouped)
        self.assertEqual((out['built'], out['kept']), (0, 1))
        self.assertEqual(self.dispatches(), [])
        out = self.fallback([card([1], [3])], clients=grouped)
        self.assertEqual(out['notes'], ['Card Calculator ↔ weird was left as it is: Calculator is already in a card or group'])
        self.assertEqual(self.dispatches(), [])

    def test_a_missing_window_leaves_the_rest_of_its_side(self):
        out = self.fallback([card([1], [2, 3])], ('0x1', '0x2', '0x3', None))
        self.assertEqual(out['built'], 1)
        self.assertEqual(sorted(self.clients_by_address()['0x2']['grouped']), ['0x2', '0x3'])

    def test_an_empty_side_is_not_built(self):
        out = self.fallback([card([1], [2])], ('0x1', '0x2', None, None))
        self.assertEqual(out['notes'], ['Card Calculator ↔ Obsidian was not rebuilt: one of its sides has none of its windows open'])
        self.assertEqual(self.dispatches(), [])

    def test_a_failing_dispatch_is_noted_and_logged(self):
        out = self.fallback([card([1], [2])], fail=['group.toggle'])
        self.assertEqual(out['built'], 0)
        self.assertTrue(out['notes'][0].startswith('Card Calculator ↔ Obsidian could not be grouped: '), out['notes'])
        self.assertIn('could not be grouped', (self.state_dir / 'restore.log').read_text())

    def test_ungroup_releases_every_group(self):
        self.hypr_state(clients=[
            client('0x1', 'a', grouped=['0x1', '0x2']), client('0x2', 'b', hidden=True, grouped=['0x1', '0x2']),
            client('0x3', 'c', grouped=['0x3', '0x4', '0x5']), client('0x4', 'd', hidden=True, grouped=['0x3', '0x4', '0x5']),
            client('0x5', 'e', hidden=True, grouped=['0x3', '0x4', '0x5']),
            client('0x6', 'f', ws=4, grouped=['0x6', '0x7']), client('0x7', 'g', ws=4, hidden=True, grouped=['0x6', '0x7'])])
        out = self.cards_json('ungroup', '--workspace', '3')
        self.assertGreaterEqual(out['released'], 2)
        c = self.clients_by_address()
        self.assertEqual([a for a in ('0x1', '0x2', '0x3', '0x4', '0x5') if c[a]['grouped'] or c[a]['hidden']], [])
        self.assertEqual(c['0x7']['grouped'], ['0x6', '0x7'])
```

Además, el `test_invalid_cards_block_is_ignored` de la Task 4 ahora también ejercita `layout`.

- [ ] **Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL (`invalid choice: 'layout'`).

- [ ] **Step 3: `layout`, `fallback` y `ungroup`**

En `bin/cards`, agregar debajo de `MAX_PANES = 5`:

```python
PARKING = 'special:savethemall'   # the same hidden workspace restore-them-all parks windows on
PAUSE = float(os.environ.get('SAVE_THEM_ALL_PAUSE') or 0.25)
```

Agregar antes de `def main`:

```python
# -- restoring: the place of each card --------------------------------------

def rect(win):
    try:
        (x, y), (w, h) = win['at'], win['size']
    except (KeyError, TypeError, ValueError):
        return None
    return (x, y, w, h) if all(whole(v) for v in (x, y, w, h)) else None


@command('layout')
def layout(args):
    """In the tree, a card takes one place: the one of its slot (its front's
    first open window), as large as the side that was showing. Its other
    windows wait outside the tree; a floating card keeps all of them out."""
    windows, cards, problem = read_file(Path(args.file or ''))
    addresses = addresses_arg(args)
    hide, slots = [], []
    if problem:
        return {'hide': [], 'slots': []}
    for card in cards:
        faces = [[i for i in f['windows'] if i < len(addresses) and addresses[i]] for f in card['faces']]
        if not all(faces):
            continue   # it will not be built: its windows stay in the tree
        members = faces[0] + faces[1]
        if card['floating'] is not None:
            hide += members
            continue
        slot = faces[0][0]
        rects = [r for r in (rect(windows[i]) for i in faces[card['visible']]) if r] or \
            [r for r in (rect(windows[slot]),) if r]
        if rects:
            x0, y0 = min(r[0] for r in rects), min(r[1] for r in rects)
            x1, y1 = max(r[0] + r[2] for r in rects), max(r[1] + r[3] for r in rects)
            slots.append({'i': slot, 'at': [x0, y0], 'size': [x1 - x0, y1 - y0]})
        hide += [i for i in members if i != slot]
    return {'hide': sorted(hide), 'slots': slots}


# -- restoring without Hyprflip: native groups ----------------------------------

def build_group(card, faces, ws, now):
    """One card as a native group in its slot: every window a tab, the
    visible side's first window in front, floating where it was."""
    members = faces[0] + faces[1]
    slot, shown = faces[0][0], faces[card['visible']][0]
    for a in members:
        if now[a].get('floating'):
            # Tiled first: Hyprflip's own helper un-floats with action = "disable".
            dispatch(f"hl.dsp.window.float({{ window = 'address:{a}', action = 'disable' }})")
    dispatch(focus(slot))
    dispatch('hl.dsp.group.toggle()')
    current = slot
    for m in members:
        if m == slot:
            continue
        # Out, and back in to the right of the group; then into the group on
        # its left. A window joins the group next to it: this makes it ours.
        dispatch(move_to(m, PARKING))
        time.sleep(PAUSE)
        dispatch(focus(current))
        dispatch("hl.dsp.layout('preselect r')")
        dispatch(move_to(m, ws))
        time.sleep(PAUSE)
        dispatch(focus(m))
        dispatch("hl.dsp.window.move({ into_group = 'l' })")
        current = m
    group = clients().get(slot, {}).get('grouped') or []
    if sorted(group) != sorted(members):
        raise CardsError(msg('the group came out with %1 of its %2 windows', len(group), len(members)))
    # Focus is on the group (its last tab); bring the visible side forward.
    dispatch(f'hl.dsp.group.active({{ index = {group.index(shown) + 1} }})')
    if card['floating'] is not None:
        (x, y), (w, h) = card['floating']['at'], card['floating']['size']
        dispatch(f"hl.dsp.window.float({{ window = 'address:{shown}', state = 'on' }})")
        dispatch(f"hl.dsp.window.resize({{ window = 'address:{shown}', x = {w}, y = {h}, exact = true }})")
        dispatch(f"hl.dsp.window.move({{ window = 'address:{shown}', x = {x}, y = {y}, exact = true }})")


def fallback_cards(filename, windows, cards, problem, addresses, notes=None):
    result = {'built': 0, 'kept': 0, 'notes': list(notes or [])}
    if problem:
        result['notes'].append(note(msg('Cards in %1 were ignored: %2', filename, problem)))
        return result
    try:
        ws = active_workspace()
    except HyprError as error:
        result['notes'].append(note(msg('Cards were not rebuilt: %1', error)))
        return result
    for card in cards:
        title = saved_title(card, windows)
        faces = present(card, addresses)
        if not all(faces):
            result['notes'].append(note(msg('Card %1 was not rebuilt: one of its sides has none of its windows open', title)))
            continue
        members = faces[0] + faces[1]
        try:
            now = clients()
            groups = [now.get(a, {}).get('grouped') or [] for a in members]
            if all(sorted(g) == sorted(members) for g in groups):
                result['kept'] += 1
                continue
            busy = next((a for a, g in zip(members, groups) if g), None)
            if busy:
                result['notes'].append(note(msg('Card %1 was left as it is: %2 is already in a card or group',
                                                title, app_name(now[busy].get('class')))))
                continue
            build_group(card, faces, ws, now)
            result['built'] += 1
        except CardsError as error:
            result['notes'].append(note(msg('Card %1 could not be grouped: %2', title, error)))
    return result


@command('fallback')
def fallback(args):
    path = Path(args.file or '')
    windows, cards, problem = read_file(path)
    return fallback_cards(path.name, windows, cards, problem, addresses_arg(args))


@command('ungroup')
def ungroup(args):
    """Let go of every native group on the workspace: the windows of a card
    Hyprflip can no longer flip come back as plain tiles."""
    ws = workspace_arg(args)
    released = 0
    for _ in range(64):
        grouped = [c for c in clients().values()
                   if c.get('workspace', {}).get('id') == ws and c.get('grouped')]
        if not grouped:
            return {'released': released}
        shown = next((c for c in grouped if not c.get('hidden')), grouped[0])
        dispatch(focus(shown['address']))
        dispatch('hl.dsp.window.move({ out_of_group = true })')
        released += 1
    raise CardsError(msg('Some windows are still in a group; try again'))
```

En el docstring del módulo, debajo de `preserve`:

```
    cards layout   --file F --addresses A        which windows wait outside the tree, and each card's place
    cards fallback --file F --addresses A        build the saved cards as native Hyprland groups
    cards ungroup  --workspace N                 let go of every native group on the workspace
```

En `tests/fakes/hyprctl`, que `float` acepte también la forma con que se desflota (`action = 'disable'`): cambiar

```python
    elif m := re.fullmatch(r"hl\.dsp\.window\.float\(\{ window = '" + ADDR + r"', state = 'on' \}\)", expr):
        clients[m[1]]['floating'] = True
```

por

```python
    elif m := re.fullmatch(r"hl\.dsp\.window\.float\(\{ window = '" + ADDR + r"', state = 'on' \}\)", expr):
        clients[m[1]]['floating'] = True
    elif m := re.fullmatch(r"hl\.dsp\.window\.float\(\{ window = '" + ADDR + r"', action = 'disable' \}\)", expr):
        clients[m[1]]['floating'] = False
```

- [ ] **Step 4: Traducciones**

Agregar a `bin/messages.es.json`:

```json
  "the group came out with %1 of its %2 windows": "el grupo quedó con %1 de sus %2 ventanas",
  "Cards in %1 were ignored: %2": "Se ignoraron las tarjetas de %1: %2",
  "Cards were not rebuilt: %1": "No se rearmaron las tarjetas: %1",
  "Card %1 was not rebuilt: one of its sides has none of its windows open": "La tarjeta %1 no se rearmó: una de sus caras no tiene ninguna ventana abierta",
  "Card %1 was left as it is: %2 is already in a card or group": "La tarjeta %1 quedó como estaba: %2 ya está en una tarjeta o grupo",
  "Card %1 could not be grouped: %2": "La tarjeta %1 no se pudo agrupar: %2",
  "Some windows are still in a group; try again": "Algunas ventanas siguen en un grupo; probá de nuevo"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `make test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add bin tests
git commit -m "feat: bin/cards: lugar de cada tarjeta, grupo nativo sin Hyprflip y mostrar las dos caras"
```

---

### Task 8: `bin/cards rebuild`: armar las tarjetas con Hyprflip

**Files:**
- Modify: `bin/cards` (`run_helper`, `rebuild`)
- Modify: `bin/messages.es.json`
- Create: `tests/test_cards_rebuild.py`

**Interfaces:**
- Consumes: `helper_snapshot`, `flip_status`, `fallback_cards`, `present`, `set_name` (Tasks 4 y 7); la acción `create` con `faces` (Task 6).
- Produces:
  - `bin/cards rebuild --file F --addresses JSON` → `{built, kept, notes}`. Arma cada tarjeta con un `create`, y cada `create` usa un contexto fresco del helper.
    - Si el helper no tiene `create_faces`, arma grupos nativos (`fallback_cards`) y lo dice en una nota.
    - Nunca aborta: cada falla es una nota y una línea en `restore.log`.
  - `run_helper(request) -> (kind, message)`:
    - reanuda cada handoff y cancela cualquier pregunta;
    - mata al helper a los `SAVE_THEM_ALL_HELPER_TIMEOUT` segundos (30 por defecto).

- [ ] **Step 1: Write the failing test**

`tests/test_cards_rebuild.py`:

```python
"""With Hyprflip, each saved card is built again with one `create` call to its
helper. A helper that fails or hangs never stops the rest."""
import json
import time

from scripttest import ScriptTest, client, flip, saved_window

W = [saved_window('kitty', (0, 0), (960, 1080), None),
     saved_window('org.gnome.Calculator', (960, 0), (960, 1080), None),
     saved_window('obsidian', (960, 0), (960, 540), None),
     saved_window('weird', (960, 540), (960, 540), None)]
CARD = {'name': '', 'faces': [{'windows': [1], 'axis': 'row', 'ratios': [1.0]},
                              {'windows': [2, 3], 'axis': 'column', 'ratios': [0.6, 0.4]}],
        'visible': 0, 'floating': None}


class RebuildTest(ScriptTest):
    def setUp(self):
        super().setUp()
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip(), clients=[
            client('0x1', 'kitty'), client('0x2', 'org.gnome.Calculator'),
            client('0x3', 'obsidian'), client('0x4', 'weird')])

    def rebuild(self, cards=(CARD,), addresses=('0x1', '0x2', '0x3', '0x4'), env=None):
        path = self.write_saved(3, W, cards=list(cards))
        return self.cards_json('rebuild', '--file', str(path), '--addresses', json.dumps(list(addresses)), env=env)

    def test_one_create_per_card(self):
        self.assertEqual(self.rebuild(), {'built': 1, 'kept': 0, 'notes': []})
        [request] = self.helper_requests()
        self.assertEqual(request['action'], 'create')
        self.assertEqual(request['context']['workspace'], 3)
        self.assertEqual(request['faces'], [['address:0x2'], ['address:0x3', 'address:0x4']])
        self.assertEqual((request['axes'], request['ratios']), (['row', 'column'], [[1.0], [0.6, 0.4]]))
        self.assertEqual((request['visible'], request['floating']), (0, None))
        self.assertEqual(self.hypr()['hyprflip']['containers'][0]['faces'], [['0x2'], ['0x3', '0x4']])

    def test_the_new_card_gets_its_name(self):
        self.rebuild([dict(CARD, name='Trading')])
        self.assertEqual(json.loads((self.runtime / 'cards-save-them-all-test.json').read_text()), {'1': 'Trading'})

    def test_second_rebuild_keeps_the_card(self):
        self.rebuild()
        self.assertEqual(self.rebuild(), {'built': 0, 'kept': 1, 'notes': []})
        self.assertEqual(len(self.helper_requests()), 1)

    def test_a_missing_window_leaves_the_rest_of_its_side(self):
        self.rebuild(addresses=('0x1', '0x2', '0x3', None))
        [request] = self.helper_requests()
        self.assertEqual((request['faces'], request['ratios']), ([['address:0x2'], ['address:0x3']], [[1.0], [1.0]]))

    def test_an_empty_side_is_not_built(self):
        out = self.rebuild(addresses=('0x1', '0x2', None, None))
        self.assertEqual(out['built'], 0)
        self.assertIn('one of its sides has none of its windows open', out['notes'][0])
        self.assertEqual(self.helper_requests(), [])

    def test_a_window_in_another_group_is_left_alone(self):
        state = self.hypr()
        state['clients'][2]['grouped'] = ['0x3', '0x9']
        self.hypr_state(**state)
        out = self.rebuild()
        self.assertEqual(out['notes'], ['Card Calculator ↔ Obsidian + weird was left as it is: Obsidian is already in a card or group'])
        self.assertEqual(self.helper_requests(), [])

    def test_a_helper_error_is_noted_and_logged(self):
        self.helper_config(outcome='error', message='Una de las apps elegidas se cerró.')
        out = self.rebuild()
        self.assertEqual(out['notes'], ['Card Calculator ↔ Obsidian + weird could not be rebuilt: Una de las apps elegidas se cerró.'])
        self.assertIn('could not be rebuilt', (self.state_dir / 'restore.log').read_text())

    def test_hung_helper_is_killed_and_noted(self):
        self.helper_config(outcome='hang')
        started = time.monotonic()
        out = self.rebuild(env={'SAVE_THEM_ALL_HELPER_TIMEOUT': '1'})
        self.assertLess(time.monotonic() - started, 20)
        self.assertEqual(out['built'], 0)
        self.assertIn('did not answer within 1 s', out['notes'][0])

    def test_an_unreadable_answer_is_noted(self):
        self.helper_config(outcome='garbage')
        self.assertIn('unreadable answer', self.rebuild()['notes'][0])

    def test_an_old_helper_falls_back_to_groups(self):
        self.helper_config(create_faces=False)
        out = self.rebuild()
        self.assertEqual(out['built'], 1)
        self.assertTrue(out['notes'][0].startswith('Cards were grouped as tabs instead: '), out['notes'])
        self.assertEqual(self.helper_requests(), [])
        self.assertEqual(sorted(self.clients_by_address()['0x2']['grouped']), ['0x2', '0x3', '0x4'])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL (`invalid choice: 'rebuild'`).

- [ ] **Step 3: `run_helper` y `rebuild`**

En `bin/cards`, debajo de `PAUSE = …`:

```python
HELPER_TIMEOUT = float(os.environ.get('SAVE_THEM_ALL_HELPER_TIMEOUT') or 30)
```

Agregar antes de `def main`:

```python
# -- restoring with Hyprflip -----------------------------------------------------

def run_helper(request):
    """One helper operation, start to end: every focus handoff is resumed
    (nobody here holds a keyboard grab), every question refused (a restore
    asks nothing) and the helper killed if it has not finished in
    HELPER_TIMEOUT seconds. -> (kind, message)"""
    try:
        proc = subprocess.Popen(['python3', str(HELPER), 'run', '--request', json.dumps(request)],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    except OSError as error:
        return 'error', str(error)
    expired = threading.Event()

    def expire():
        expired.set()
        proc.kill()
    timer = threading.Timer(HELPER_TIMEOUT, expire)
    timer.start()

    def write(value):
        try:
            proc.stdin.write(json.dumps(value) + '\n')
            proc.stdin.flush()
        except (OSError, ValueError):
            pass
    outcome = ('error', msg('The Hyprflip helper stopped without an answer'))
    try:
        for line in proc.stdout:
            try:
                message = json.loads(line)
            except ValueError:
                outcome = ('error', msg('The Hyprflip helper sent an unreadable answer'))
                continue
            kind = message.get('type') if isinstance(message, dict) else None
            if kind == 'handoff':
                write({'resume': message.get('id')})
            elif kind == 'question':
                write({'cancel': True})
            elif kind in ('done', 'error', 'cancelled'):
                outcome = (kind, str(message.get('message') or ''))
        proc.wait()
        errors = proc.stderr.read()
    finally:
        timer.cancel()
    if expired.is_set():
        return 'error', msg('The Hyprflip helper did not answer within %1 s', f'{HELPER_TIMEOUT:g}')
    if errors.strip():
        log('helper: ' + errors.strip()[-500:])
    return outcome


@command('rebuild')
def rebuild(args):
    path = Path(args.file or '')
    windows, cards, problem = read_file(path)
    addresses = addresses_arg(args)
    if problem:
        return {'built': 0, 'kept': 0, 'notes': [note(msg('Cards in %1 were ignored: %2', path.name, problem))]}
    try:
        snapshot = helper_snapshot()
    except CardsError as error:
        snapshot = {'error': str(error)}
    if not snapshot.get('available') or not (snapshot.get('capabilities') or {}).get('create_faces'):
        why = (msg('the Hyprflip helper cannot build whole cards; update it') if snapshot.get('available')
               else snapshot.get('error') or msg('Hyprflip is not available'))
        return fallback_cards(path.name, windows, cards, '', addresses,
                              [note(msg('Cards were grouped as tabs instead: %1', why))])
    result = {'built': 0, 'kept': 0, 'notes': []}
    for card in cards:
        title = saved_title(card, windows)
        faces = present(card, addresses)
        if not all(faces):
            result['notes'].append(note(msg('Card %1 was not rebuilt: one of its sides has none of its windows open', title)))
            continue
        members = faces[0] + faces[1]
        try:
            containers = (flip_status() or {}).get('containers', [])
            now = clients()
        except CardsError as error:
            result['notes'].append(note(msg('Card %1 could not be rebuilt: %2', title, error)))
            continue
        if any(c.get('faces') == faces for c in containers):
            result['kept'] += 1
            continue
        owned = {a for c in containers for f in c.get('faces', []) for a in f}
        busy = next((a for a in members if a in owned or now.get(a, {}).get('grouped')), None)
        if busy:
            result['notes'].append(note(msg('Card %1 was left as it is: %2 is already in a card or group',
                                            title, app_name(now[busy].get('class')))))
            continue
        try:
            context = helper_snapshot().get('context')
        except CardsError:
            context = None
        if not context:
            result['notes'].append(note(msg('Card %1 could not be rebuilt: %2', title, msg('Hyprflip is not available'))))
            continue
        weights = [ratios([r for i, r in zip(f['windows'], f['ratios']) if i < len(addresses) and addresses[i]],
                          len(faces[n])) for n, f in enumerate(card['faces'])]
        kind, message = run_helper({'protocol': 1, 'action': 'create', 'context': context,
                                    'faces': [['address:' + a for a in f] for f in faces],
                                    'axes': [f['axis'] for f in card['faces']], 'ratios': weights,
                                    'visible': card['visible'], 'floating': card['floating']})
        if kind != 'done':
            result['notes'].append(note(msg('Card %1 could not be rebuilt: %2', title, message or kind)))
            continue
        result['built'] += 1
        if card['name']:
            try:
                new = next((c for c in (flip_status() or {}).get('containers', []) if c.get('faces') == faces), None)
            except CardsError:
                new = None
            if new:
                set_name(new['id'], card['name'])
    return result
```

En el docstring del módulo, debajo de `ungroup`:

```
    cards rebuild  --file F --addresses A        build the saved cards with Hyprflip's create action
```

- [ ] **Step 4: Traducciones**

Agregar a `bin/messages.es.json`:

```json
  "The Hyprflip helper stopped without an answer": "El asistente de Hyprflip se detuvo sin responder",
  "The Hyprflip helper sent an unreadable answer": "El asistente de Hyprflip mandó una respuesta ilegible",
  "The Hyprflip helper did not answer within %1 s": "El asistente de Hyprflip no respondió en %1 s",
  "the Hyprflip helper cannot build whole cards; update it": "el asistente de Hyprflip no puede armar tarjetas enteras; actualizalo",
  "Hyprflip is not available": "Hyprflip no está disponible",
  "Cards were grouped as tabs instead: %1": "Las tarjetas se agruparon como pestañas: %1",
  "Card %1 could not be rebuilt: %2": "La tarjeta %1 no se pudo rearmar: %2"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `make test`
Expected: PASS. El test del helper colgado tarda alrededor de un segundo.

- [ ] **Step 6: Commit**

```bash
git add bin tests
git commit -m "feat: bin/cards rebuild arma las tarjetas guardadas con Hyprflip"
```

---

### Task 9: Restaurar con tarjetas

**Files:**
- Modify: `bin/restore-them-all`
- Modify: `bin/messages.es.json`
- Create: `tests/test_restore.py`

**Interfaces:**
- Consumes: `bin/cards layout|status|rebuild|fallback` (Tasks 4, 7 y 8).
- Produces: el orden de `restore-them-all` pasa a ser este:
  1. abrir lo que falta;
  2. el árbol: los miembros de una tarjeta que no son su slot esperan afuera, y las ventanas que ya están en una tarjeta o grupo no se tocan;
  3. las tarjetas (`rebuild` con Hyprflip, `fallback` sin él);
  4. la geometría: el slot toma el tamaño de su tarjeta y los demás miembros no se tocan.

  Las notas de las tarjetas van a la notificación final (aun con `--quiet`) y a `restore.log`. Nunca cambian el código de salida.

- [ ] **Step 1: Write the failing test**

`tests/test_restore.py`:

```python
"""Restoring a workspace rebuilds its cards after the windows, and never lets
a card stop the windows from coming back."""
from scripttest import ScriptTest, client, flip, saved_window

TERMINAL = {'kind': 'terminal'}
CALC = {'kind': 'app', 'desktop': 'org.gnome.Calculator.desktop'}
OBSIDIAN = {'kind': 'app', 'desktop': 'obsidian.desktop'}
WINDOWS = [saved_window('kitty', (0, 0), (960, 1080), TERMINAL),
           saved_window('org.gnome.Calculator', (960, 0), (960, 1080), CALC),
           saved_window('obsidian', (960, 0), (960, 1080), OBSIDIAN)]
CARD = {'name': 'Notes', 'faces': [{'windows': [1], 'axis': 'row', 'ratios': [1.0]},
                                   {'windows': [2], 'axis': 'row', 'ratios': [1.0]}],
        'visible': 0, 'floating': None}
PARK = "hl.dsp.window.move({ window = 'address:%s', workspace = 'special:savethemall', follow = false })"


class RestoreCardsTest(ScriptTest):
    def fresh_session(self, with_flip=True, cards=(CARD,)):
        self.write_saved(3, WINDOWS, cards=list(cards))
        self.hypr_state(plugins=['hyprflip'] if with_flip else [], hyprflip=flip() if with_flip else None, clients=[
            client('0x1', 'kitty', at=(0, 0), size=(600, 600)),
            client('0x2', 'org.gnome.Calculator', at=(600, 0), size=(600, 600)),
            client('0x3', 'obsidian', at=(1200, 0), size=(600, 600))])

    def test_restore_rebuilds_the_card_with_hyprflip(self):
        self.fresh_session()
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        [request] = self.helper_requests()
        self.assertEqual(request['faces'], [['address:0x2'], ['address:0x3']])
        d = self.dispatches()
        # the back waits outside the tree and comes back last, next to the others
        self.assertIn(PARK % '0x3', d)
        self.assertLess(max(i for i, x in enumerate(d) if "'address:0x2', workspace = '3'" in x),
                        max(i for i, x in enumerate(d) if "'address:0x3', workspace = '3'" in x))
        # the hidden side is never resized
        self.assertFalse([x for x in d if x.startswith("hl.dsp.window.resize({ window = 'address:0x3'")])
        self.assertEqual(self.clients_by_address()['0x2']['size'], [960, 1080])
        self.assertEqual(self.notifications()[-1][0], 'Windows restored on workspace 3')

    def test_restore_without_hyprflip_groups_the_card(self):
        self.fresh_session(with_flip=False)
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        c = self.clients_by_address()
        self.assertEqual(sorted(c['0x2']['grouped']), ['0x2', '0x3'])
        self.assertEqual((c['0x2']['hidden'], c['0x3']['hidden']), (False, True))
        self.assertEqual(self.helper_requests(), [])

    def test_second_restore_leaves_cards_alone(self):
        self.fresh_session()
        self.assertEqual(self.run_script('restore-them-all').returncode, 0)
        before = len(self.dispatches())
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        second = self.dispatches()[before:]
        self.assertEqual(len(self.helper_requests()), 1)
        touched = [x for x in second if ("'address:0x2'" in x or "'address:0x3'" in x)
                   and not x.startswith('hl.dsp.focus(')]   # giving focus back is fine; moving is not
        self.assertEqual(touched, [])

    def test_restore_with_invalid_cards_still_restores_windows(self):
        self.fresh_session(cards=[{'faces': 'bad'}])
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual({a: c['size'] for a, c in self.clients_by_address().items()},
                         {'0x1': [960, 1080], '0x2': [960, 1080], '0x3': [960, 1080]})
        title, body = self.notifications()[-1]
        self.assertEqual(title, 'Windows restored on workspace 3, cards with notes')
        self.assertIn('Cards in workspace-3.json were ignored: card 1 needs exactly two sides', body)
        self.assertEqual(self.helper_requests(), [])

    def test_restore_survives_failing_cards(self):
        self.fresh_session()
        self.helper_config(outcome='error', message='Fake failure')
        r = self.run_script('restore-them-all', '--quiet')
        self.assertEqual(r.returncode, 0, r.stderr)
        title, body = self.notifications()[-1]
        self.assertEqual(title, 'Windows restored on workspace 3, cards with notes')
        self.assertIn('Card Notes could not be rebuilt: Fake failure', body)
        self.assertIn('Card Notes could not be rebuilt', (self.state_dir / 'restore.log').read_text())
        # nothing stays hidden: the back came back to the tree
        self.assertEqual(self.clients_by_address()['0x3']['workspace']['id'], 3)

    def test_a_file_without_cards_never_calls_bin_cards(self):
        self.write_saved(3, WINDOWS[:2])
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip(), clients=[
            client('0x1', 'kitty', size=(600, 600)), client('0x2', 'org.gnome.Calculator', at=(600, 0), size=(600, 600))])
        self.assertEqual(self.run_script('restore-them-all').returncode, 0)
        self.assertEqual(self.helper_requests(), [])
        self.assertFalse((self.state_dir / 'restore.log').exists())
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL (no se llama a `bin/cards`; no hay grupo ni `create`).

- [ ] **Step 3: `restore-them-all`**

a) Debajo de `QUIET=0`, agregar:

```bash
LOG="$STATE_DIR/restore.log"   # what went wrong with cards, beyond the notification
```

b) Justo antes de `# ---------- 2. Rebuild the dwindle tree ----------`, agregar:

```bash
# Where each saved window stands now, by its index in the file: the address,
# or null when it could not be opened. This is what bin/cards takes.
addr_json() {
  local i out=()
  ((${#entries[@]})) || { echo '[]'; return; }
  for i in "${!entries[@]}"; do out+=("${addrs[$i]:-null}"); done
  printf '%s\n' "${out[@]}" | jq -Rsc 'split("\n")[:-1] | map(if . == "null" then null else . end)'
}
addresses=$(addr_json)

# Cards: in the tree each card takes one place, the one of its slot; its
# other windows wait outside until the card is built (bin/cards layout).
has_cards=$(jq -r 'if (.cards | type) == "array" and (.cards | length) > 0 then "yes" else "no" end' "$file" 2>/dev/null || echo no)
declare -A hidden=() slot=()
if [[ $has_cards == yes ]] && card_layout=$("$BIN_DIR/cards" layout --file "$file" --addresses "$addresses" 2>>"$LOG"); then
  while read -r i; do [[ -n $i ]] && hidden[$i]=1; done < <(jq -r '.hide[]' <<<"$card_layout")
  while IFS=$'\t' read -r i x y w h; do [[ -n $i ]] && slot[$i]="$x $y $w $h"; done \
    < <(jq -r '.slots[] | [.i, .at[0], .at[1], .size[0], .size[1]] | @tsv' <<<"$card_layout")
fi
hidden_addrs=$(for i in "${!hidden[@]}"; do echo "${addrs[$i]:-}"; done)

# A window already in a card or a group is left exactly where it is.
grouped_now=$(hyprctl -j clients | jq -r '.[] | select((.grouped // []) | length > 0) | .address')
is_grouped() { grep -qx -- "$1" <<<"$grouped_now"; }

# The window a slot's card shows now: once the card is built the slot may be
# on its hidden side, and only the shown window can be resized.
shown_of() { # $1 address
  hyprctl -j clients | jq -r --arg a "$1" '
    (map(select(.address == $a)) | first | .grouped // []) as $g
    | if ($g | length) == 0 then $a
      else ([.[] | select((.address as $x | $g | index($x)) != null and ((.hidden // false) | not)) | .address] | first // $a)
      end'
}

rect_of() { # $1 index -> "x y w h": its card's place for a slot, its own otherwise
  if [[ -n ${slot[$1]:-} ]]; then
    echo "${slot[$1]}"
  else
    jq -r '"\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"' <<<"${entries[$1]}"
  fi
}
```

c) Reemplazar el bloque `# ---------- 2. Rebuild the dwindle tree ----------` entero (hasta el `fi` que cierra `if (( $(jq length <<<"$tiled") > 1 ))`) por:

```bash
# ---------- 2. Rebuild the dwindle tree ----------
tiled='[]'
for i in "${!entries[@]}"; do
  [[ -n ${addrs[$i]:-} ]] || continue
  [[ -n ${hidden[$i]:-} ]] && continue
  is_grouped "${addrs[$i]}" && continue
  [[ $(jq -r .floating <<<"${entries[$i]}") == true ]] && continue
  read -r x y w h < <(rect_of "$i")
  tiled=$(jq -c --argjson i "$i" --argjson x "$x" --argjson y "$y" --argjson w "$w" --argjson h "$h" \
    '. + [{i: $i, x: $x, y: $y, w: $w, h: $h}]' <<<"$tiled")
done

if (( $(jq length <<<"$tiled") > 1 )); then
  plan=$(build_plan "$tiled")
  managed=$(printf '%s\n' "${addrs[@]}")
  extras=()
  later=()
  # Park every tiled window on the workspace, including the ones that were not
  # saved; never one that is already in a card or group.
  while IFS=$'\t' read -r a fl; do
    [[ $fl == true ]] && continue
    is_grouped "$a" && continue
    if grep -qx -- "$a" <<<"$hidden_addrs"; then
      later+=("$a")
    elif ! grep -qx -- "$a" <<<"$managed"; then
      extras+=("$a")
    fi
    park "$a"
  done < <(clients_on_ws | jq -r '.[] | [.address, (.floating|tostring)] | @tsv')
  sleep 0.3
  last=""
  while IFS= read -r step; do
    i=$(jq -r .i <<<"$step")
    if [[ $(jq -r .op <<<"$step") == insert ]]; then
      unpark "${addrs[$i]}" "${addrs[$(jq -r .next_to <<<"$step")]}" "$(jq -r .dir <<<"$step")"
    else
      unpark "${addrs[$i]}"
    fi
    last=${addrs[$i]}
  done < <(jq -c '.[]' <<<"$plan")
  # Unsaved windows come back last, to the right of the last one; then the
  # windows that wait for their card, so a card that cannot be built hides nothing.
  for a in "${extras[@]}" "${later[@]}"; do
    unpark "$a" "$last" r
    last=$a
  done
fi

# ---------- 3. Cards ----------
card_notes=()
if [[ $has_cards == yes ]]; then
  sub=fallback
  if "$BIN_DIR/cards" status 2>>"$LOG" | jq -e '.available == true' >/dev/null; then sub=rebuild; fi
  if out=$("$BIN_DIR/cards" "$sub" --file "$file" --addresses "$addresses" 2>>"$LOG"); then
    mapfile -t card_notes < <(jq -r '.notes[]' <<<"$out")
    echo "cards: $(jq -r '"\(.built) built, \(.kept) already there"' <<<"$out")"
  else
    card_notes+=("$(msg "Cards were not rebuilt: see %1" "$LOG")")
  fi
fi
```

d) Reemplazar el encabezado `# ---------- 3. Geometry ----------` y su bucle por:

```bash
# ---------- 4. Geometry ----------
for i in "${!entries[@]}"; do
  [[ -n ${addrs[$i]:-} ]] || continue
  [[ -n ${hidden[$i]:-} ]] && continue      # a card's other windows follow their card
  is_grouped "${addrs[$i]}" && continue     # it was in a card or group before: untouched
  read -r fl < <(jq -r '.floating' <<<"${entries[$i]}")
  read -r x y w h < <(rect_of "$i")
  target=${addrs[$i]}
  [[ -n ${slot[$i]:-} ]] && target=$(shown_of "$target")
  if [[ $fl == true && -z ${slot[$i]:-} ]]; then
    place_floating "$target" "$w" "$h" "$x" "$y"
  else
    fit "$target" x "$w"
    fit "$target" y "$h"
  fi
done
```

e) Reemplazar el final, desde `summary=$(msg "%1 opened, %2 already there" …)`, por:

```bash
summary=$(msg "%1 opened, %2 already there" "$opened" "$skipped")
extra=""
((${#card_notes[@]})) && extra=$(printf '\n%s' "${card_notes[@]}")
if ((${#missing[@]})); then
  notify "$(msg "Windows: %1 missing" "${#missing[@]}")" "$(printf '%s, ' "${missing[@]}" | sed 's/, $//')$extra"
  msg "%1; missing: %2" "$summary" "${missing[*]}" >&2
  exit 1
fi
echo "$summary"
if ((${#card_notes[@]})); then
  # Card notes are news even when the caller asked for quiet.
  notify "$(msg "Windows restored on workspace %1, cards with notes" "$ws")" "$summary$extra"
  printf '%s\n' "${card_notes[@]}" >&2
else
  ((QUIET)) || notify "$(msg "Windows restored on workspace %1" "$ws")" "$summary"
fi
```

- [ ] **Step 4: Traducciones**

Agregar a `bin/messages.es.json`:

```json
  "Cards were not rebuilt: see %1": "No se rearmaron las tarjetas: mirá %1",
  "Windows restored on workspace %1, cards with notes": "Ventanas restauradas en el escritorio %1, tarjetas con avisos"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `make test`
Expected: PASS: `test_restore.py`, y `test_legacy.py` sin cambios.

- [ ] **Step 6: Commit**

```bash
git add bin tests
git commit -m "feat: restaurar un workspace vuelve a armar sus tarjetas"
```

---

### Task 10: El servicio y la conexión con Hyprflip

**Files:**
- Create: `Protocol.js`, `Hyprflip.qml`, `Service.qml`, `tests/protocol.test.js`
- Modify: `manifest.json` (kinds `service` y `bar-widget`), `BarWidget.qml` (le pasa `service` al panel), `Panel.qml` (recibe `service`; la restauración al iniciar sesión pasa al servicio), `I18n.js`

**Interfaces:**
- Consumes: `bin/cards status` (Task 4), el helper `control.py` (`snapshot` / `run`, protocolo 1; `create` con caras y `unpair` de la Task 6), `I18n.js`, `AppNames.js`.
- Produces:
  - `Protocol.js`: `emptySnapshot()`, `parseSnapshot(text) -> {snapshot, problem}`, `request(action, context, extra)`, `receive(line) -> {kind, id, message}`, `faceAddresses(card)`, `sameFaces(a, b)`, `cardTarget(card)` y `unavailableText(status, t)`.
  - `Hyprflip.qml` (dentro del servicio, como `service.flip`):
    - propiedades: `status`, `snapshot`, `available`, `canCreate`, `canUnpair`, `unavailableText`, `notice`, `failed`, `busy`;
    - funciones: `check()`, `refresh()` y `run(action, extra, options) -> bool`, con `options = {workspace, card, replace, reopen}`;
    - señal `finished(action, ok, message, pending)`.
  - `Service.qml` (kind `service`):
    - propiedades: `lang`, `languageSetting`, `binDir`, `stateDir`, `clients`, `byAddress`, `names`, `entries`, `focusedWorkspace`, `panel`, `flip`;
    - funciones: `t(text, args)`, `appName(win)`, `appIcon(win)`, `attach(panel)`, `setLanguage(value)`, `setName(id, name)`, `refreshClients()` y `toplevelFor(address)`.
  - El panel recibe `service`. El panel tiene `dismiss()` y `reveal()`: Hyprflip lo cierra durante un handoff y el servicio lo vuelve a abrir.

- [ ] **Step 1: Write the failing test**

`tests/protocol.test.js`:

```js
// Run with: node --test tests/
const test = require("node:test")
const assert = require("node:assert/strict")
const { load } = require("./load.js")
const Protocol = load("Protocol.js")
const I18n = load("I18n.js")

const en = (s, a) => I18n.t(s, "en", a)
const es = (s, a) => I18n.t(s, "es", a)

test("parseSnapshot keeps a protocol 1 snapshot and fills what is missing", () => {
  const r = Protocol.parseSnapshot(JSON.stringify({ protocol: 1, available: true, context: { workspace: 3 }, cards: [{ id: 1 }] }))
  assert.equal(r.problem, "")
  assert.equal(r.snapshot.available, true)
  assert.deepEqual(r.snapshot.cards, [{ id: 1 }])
  assert.deepEqual(r.snapshot.capabilities, {})
  assert.deepEqual(r.snapshot.shortcuts, { available: false, rows: [], occupied: [] })
})

test("parseSnapshot refuses garbage and other protocols", () => {
  assert.equal(Protocol.parseSnapshot("not json").problem, "unreadable")
  assert.equal(Protocol.parseSnapshot("[1]").problem, "unreadable")
  assert.equal(Protocol.parseSnapshot('{"protocol": 2}').problem, "protocol")
  assert.equal(Protocol.parseSnapshot('{"protocol": 2}').snapshot.available, false)
  const r = Protocol.parseSnapshot('{"protocol": 1, "available": "yes", "cards": {}, "shortcuts": {"rows": []}}')
  assert.equal(r.snapshot.available, false)
  assert.deepEqual(r.snapshot.cards, [])
  assert.deepEqual(r.snapshot.shortcuts.occupied, [])
})

test("request puts protocol, action and context first", () => {
  assert.deepEqual(Protocol.request("flip", { workspace: 3 }, { target: { id: 1 } }),
    { protocol: 1, action: "flip", context: { workspace: 3 }, target: { id: 1 } })
  assert.deepEqual(Protocol.request("unpair", null), { protocol: 1, action: "unpair", context: null })
})

test("receive reads each helper line", () => {
  assert.deepEqual(Protocol.receive('{"type":"handoff","id":4}'), { kind: "handoff", id: 4, message: "" })
  assert.deepEqual(Protocol.receive('{"type":"done","message":"Tarjeta creada."}'), { kind: "done", id: null, message: "Tarjeta creada." })
  assert.equal(Protocol.receive("  ").kind, "blank")
  assert.equal(Protocol.receive("oops").kind, "unreadable")
  assert.equal(Protocol.receive('{"type":"launch-missiles"}').kind, "unreadable")
})

test("sameFaces compares the addresses of both sides in order", () => {
  const card = { faces: [{ panes: [{ address: "0x1" }] }, { panes: [{ address: "0x2" }, { address: "0x3" }] }] }
  assert.deepEqual(Protocol.faceAddresses(card), [["0x1"], ["0x2", "0x3"]])
  assert.ok(Protocol.sameFaces([["0x1"], ["0x2", "0x3"]], Protocol.faceAddresses(card)))
  assert.ok(!Protocol.sameFaces([["0x1"], ["0x3", "0x2"]], Protocol.faceAddresses(card)))
  assert.ok(!Protocol.sameFaces(null, [["0x1"]]))
  assert.deepEqual(Protocol.cardTarget({ kind: "container", id: 7, token: "t", faces: [] }), { kind: "container", id: 7, token: "t" })
})

test("unavailableText says what happened and what to run", () => {
  assert.equal(Protocol.unavailableText({ reason: "ok" }, en), "")
  assert.equal(Protocol.unavailableText({ reason: "no-plugin", fix: "make" }, en), "Hyprflip is not loaded. Install it with: make")
  assert.equal(Protocol.unavailableText({ reason: "mismatch", hyprland: "0.57.0", built_for: "0.56.2", fix: "make" }, es),
    "Hyprflip no cargó: Hyprland es 0.57.0 y Hyprflip se compiló para 0.56.2. Recompilalo con: make")
  assert.equal(Protocol.unavailableText({}, en), "Checking Hyprflip…")
  for (const reason of ["no-hyprland", "no-helper", "protocol", "helper"])
    assert.notEqual(Protocol.unavailableText({ reason: reason, fix: "x", detail: "y" }, es), Protocol.unavailableText({ reason: reason, fix: "x", detail: "y" }, en))
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL (`ENOENT … Protocol.js`).

- [ ] **Step 3: `Protocol.js`**

```js
// The Hyprflip helper's panel protocol (version 1), as Save Them All speaks
// it: what a snapshot holds, how a request is built and how each line the
// helper writes back is read. No QML in here, so node can test it.

var PROTOCOL = 1
var KINDS = ["handoff", "question", "opening", "done", "error", "cancelled"]

function emptySnapshot() {
  return { protocol: PROTOCOL, available: false, error: "", context: null, capabilities: {},
           cards: [], transition: "flip", transition_modes: [], duration_ms: null,
           appearance: null, card_gap: null,
           shortcuts: { available: false, rows: [], occupied: [] } }
}

// text: what `control.py snapshot` printed. -> { snapshot, problem }, with
// problem "" | "unreadable" | "protocol"; the snapshot is always safe to read.
function parseSnapshot(text) {
  var data
  try {
    data = JSON.parse(String(text || ""))
  } catch (e) {
    return { snapshot: emptySnapshot(), problem: "unreadable" }
  }
  if (!data || typeof data !== "object" || Array.isArray(data)) return { snapshot: emptySnapshot(), problem: "unreadable" }
  if (data.protocol !== PROTOCOL) return { snapshot: emptySnapshot(), problem: "protocol" }
  var out = emptySnapshot()
  for (var k in data) if (Object.prototype.hasOwnProperty.call(data, k)) out[k] = data[k]
  out.available = data.available === true
  if (!Array.isArray(out.cards)) out.cards = []
  if (!out.capabilities || typeof out.capabilities !== "object") out.capabilities = {}
  if (!out.shortcuts || typeof out.shortcuts !== "object" || !Array.isArray(out.shortcuts.rows))
    out.shortcuts = { available: false, rows: [], occupied: [] }
  if (!Array.isArray(out.shortcuts.occupied)) out.shortcuts.occupied = []
  return { snapshot: out, problem: "" }
}

function request(action, context, extra) {
  var out = { protocol: PROTOCOL, action: action, context: context }
  var more = extra || {}
  for (var k in more) if (Object.prototype.hasOwnProperty.call(more, k)) out[k] = more[k]
  return out
}

// One line of `control.py run`. -> { kind, id, message }: kind is the
// helper's type, "blank" for an empty line, "unreadable" for anything else.
function receive(line) {
  var text = String(line || "").trim()
  if (text === "") return { kind: "blank", id: null, message: "" }
  var m
  try {
    m = JSON.parse(text)
  } catch (e) {
    return { kind: "unreadable", id: null, message: "" }
  }
  if (!m || typeof m !== "object" || KINDS.indexOf(m.type) < 0) return { kind: "unreadable", id: null, message: "" }
  return { kind: m.type, id: m.id === undefined ? null : m.id, message: typeof m.message === "string" ? m.message : "" }
}

// A snapshot card's sides as lists of addresses.
function faceAddresses(card) {
  return ((card && card.faces) || []).map(function(f) { return (f.panes || []).map(function(p) { return p.address }) })
}

function sameFaces(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) return false
  return JSON.stringify(a) === JSON.stringify(b)
}

function cardTarget(card) {
  return { kind: card.kind, id: card.id, token: card.token }
}

// Why cards cannot be used, from `bin/cards status`, in the panel's
// language (t is the panel's translation function).
function unavailableText(status, t) {
  var s = status || {}
  switch (s.reason) {
  case "ok": return ""
  case "no-hyprland": return t("Hyprland is not answering, so cards are paused.")
  case "no-plugin": return t("Hyprflip is not loaded. Install it with: %1", [s.fix])
  case "mismatch": return t("Hyprflip did not load: Hyprland is %1 and Hyprflip was built for %2. Rebuild it with: %3", [s.hyprland, s.built_for, s.fix])
  case "no-helper": return t("The Hyprflip helper is not installed. Install it with: %1", [s.fix])
  case "protocol": return t("The Hyprflip helper speaks another protocol. Update it with: %1", [s.fix])
  case "helper": return t("The Hyprflip helper reports: %1", [s.detail])
  default: return t("Checking Hyprflip…")
  }
}

if (typeof module !== "undefined") {
  module.exports = { emptySnapshot: emptySnapshot, parseSnapshot: parseSnapshot, request: request, receive: receive,
                     faceAddresses: faceAddresses, sameFaces: sameFaces, cardTarget: cardTarget,
                     unavailableText: unavailableText }
}
```

- [ ] **Step 4: `Hyprflip.qml`**

```qml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Protocol.js" as Protocol

// The connection to Hyprflip, after OmaCards' Service.qml (MIT, see NOTICE).
// `bin/cards status` says whether cards can be used and, if not, why; the
// helper's `snapshot` lists the cards and `run` changes them. The helper owns
// every window change: this only asks, resumes its focus handoffs, refuses
// its questions (a panel action never has one) and reports how it ended.
Scope {
  id: root

  // Set by Service.qml.
  property var t: function(text, args) { return text }
  property string binDir: ""
  property string lang: "en"
  property var owner: null          // the panel: closed for a handoff
  property bool watching: false     // refresh on Hyprland events only while someone looks

  readonly property string helper: Quickshell.env("SAVE_THEM_ALL_HYPRFLIP_HELPER")
    || (Quickshell.env("HOME") + "/.local/lib/hyprflip/control.py")

  property var status: ({ available: false, reason: "", fix: "", detail: "", hyprland: "", built_for: "", hyprflip: "" })
  property var snapshot: Protocol.emptySnapshot()
  property string snapshotProblem: ""
  readonly property bool available: status.available === true && snapshot.available === true && snapshotProblem === ""
  readonly property bool canCreate: available && snapshot.capabilities.create_faces === true
  readonly property bool canUnpair: available && snapshot.capabilities.unpair === true
  readonly property string unavailableText: {
    if (status.available !== true) return Protocol.unavailableText(status, t)
    if (snapshotProblem !== "") return t("The Hyprflip helper sent an unreadable answer.")
    if (snapshot.available !== true) return t("The Hyprflip helper reports: %1", [snapshot.error || "?"])
    return ""
  }

  property string notice: ""
  property bool failed: false
  property var pending: null        // { action, extra, options } until the helper exits
  property var sent: null
  property bool completed: false
  property bool refused: false
  readonly property bool busy: pending !== null
  readonly property bool checking: statusProcess.running

  signal finished(string action, bool ok, string message, var pending)

  // Ask again whether Hyprflip can be used; then list its cards.
  function check() {
    if (!statusProcess.running) statusProcess.running = true
  }

  function refresh() {
    if (busy || snapshotProcess.running || status.available !== true) return
    snapshotProcess.running = true
  }

  // action: a helper action; extra: its fields; options:
  //   workspace  go there first (Hyprflip acts on the cards of the active workspace)
  //   card       {kind, id, faces}: the card acted on, checked against a fresh snapshot
  //   replace    the same, for a create that rebuilds a card
  //   reopen     the caller wants the panel back when it ends
  function run(action, extra, options) {
    if (busy || !available) return false
    pending = { action: action, extra: extra || {}, options: options || {} }
    notice = ""
    failed = false
    completed = false
    refused = false
    sent = null
    var ws = pending.options.workspace
    var here = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
    if (ws && ws !== here) {
      switchProcess.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = '" + Number(ws) + "' })"]
      switchProcess.running = true
    } else {
      snapshotProcess.running = true
    }
    return true
  }

  function fail(text) {
    var p = pending
    pending = null
    failed = true
    notice = text
    root.finished(p ? p.action : "", false, text, p)
  }

  // The fresh target of a card the panel showed, or null if it changed.
  function resolve(ref) {
    var fresh = (snapshot.cards || []).find(function(c) { return c.kind === ref.kind && c.id === ref.id }) || null
    if (!fresh || !Protocol.sameFaces(Protocol.faceAddresses(fresh), ref.faces)) return null
    return Protocol.cardTarget(fresh)
  }

  function accept(text) {
    var parsed = Protocol.parseSnapshot(text)
    snapshot = parsed.snapshot
    snapshotProblem = parsed.problem
    if (!pending) return
    if (!available) { fail(unavailableText); return }
    var o = pending.options
    if (o.workspace && (!snapshot.context || snapshot.context.workspace !== o.workspace)) {
      fail(t("Could not switch to workspace %1.", [o.workspace]))
      return
    }
    var extra = Object.assign({}, pending.extra)
    if (o.card) {
      extra.target = resolve(o.card)
      if (!extra.target) { fail(t("That card changed; look at it again.")); return }
    }
    if (o.replace) {
      extra.replace = resolve(o.replace)
      if (!extra.replace) { fail(t("That card changed; look at it again.")); return }
    }
    sent = Protocol.request(pending.action, snapshot.context, extra)
    operationProcess.command = ["python3", helper, "run", "--request", JSON.stringify(sent)]
    operationProcess.running = true
  }

  function write(value) {
    operationProcess.write(JSON.stringify(value) + "\n")
  }

  function receive(line) {
    var r = Protocol.receive(line)
    if (r.kind === "blank" || r.kind === "opening") return
    if (r.kind === "handoff") {
      // The panel holds a keyboard grab; the helper waits until it is gone.
      if (owner) owner.dismiss()
      Qt.callLater(function() { if (operationProcess.running) root.write({ resume: r.id }) })
    } else if (r.kind === "question" || r.kind === "unreadable") {
      refused = true
      failed = true
      notice = r.kind === "question"
        ? t("Hyprflip asked something this panel cannot answer; the action was cancelled.")
        : t("The Hyprflip helper sent an unreadable answer.")
      root.write({ cancel: true })
      cancelTimer.restart()
    } else {
      completed = true
      if (!refused) {
        notice = r.message
        failed = r.kind === "error"
      }
    }
  }

  Process {
    id: statusProcess
    command: [root.binDir + "/cards", "status"]
    environment: ({ SAVE_THEM_ALL_LANG: root.lang })
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var s = JSON.parse(String(text || ""))
          root.status = s && typeof s === "object" ? s : { available: false, reason: "helper", detail: "" }
        } catch (e) {
          root.status = { available: false, reason: "helper", detail: String(text || "").trim().slice(0, 200) }
        }
        if (root.status.available === true) root.refresh()
      }
    }
  }

  Process {
    id: snapshotProcess
    command: ["python3", root.helper, "snapshot"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.accept(text)
    }
  }

  Process {
    id: switchProcess
    onExited: if (root.pending) snapshotProcess.running = true
  }

  Process {
    id: operationProcess
    stdinEnabled: true
    stdout: SplitParser { onRead: function(data) { root.receive(data) } }
    stderr: StdioCollector { id: operationErrors; waitForEnd: true }
    onExited: function(exitCode) {
      cancelTimer.stop()
      var p = root.pending
      root.pending = null
      if (!root.completed && !root.refused) {
        root.failed = true
        root.notice = root.t("The Hyprflip helper stopped. Try again.")
        console.warn("[save-them-all] helper exit " + exitCode + ": " + operationErrors.text.slice(0, 2000))
      }
      root.finished(p ? p.action : "", !root.failed, root.notice, p)
      Qt.callLater(root.refresh)
    }
  }

  // A helper that ignores the cancel is stopped; it is our own child process.
  Timer {
    id: cancelTimer
    interval: 9000
    onTriggered: if (operationProcess.running) operationProcess.signal(15)
  }

  Timer { id: eventRefresh; interval: 180; onTriggered: root.refresh() }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "configreloaded") { root.check(); return }
      if (!root.watching || root.busy) return
      if (["openwindow", "closewindow", "movewindowv2", "workspacev2", "changefloatingmode"].indexOf(event.name) >= 0)
        eventRefresh.restart()
    }
  }

  Component.onDestruction: {
    if (operationProcess.running) {
      root.write({ cancel: true })
      operationProcess.signal(15)
    }
  }
}
```

- [ ] **Step 5: `Service.qml`**

```qml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "I18n.js" as I18n
import "AppNames.js" as AppNames

// Loaded once by the shell (kind "service"). It owns what outlives the
// panel: the language, the connection to Hyprflip, the list of windows and
// the card names of this session. The bar's panel (and, later, the pick
// overlay) read it as `service`.
Scope {
  id: root
  property var shell: null
  property var manifest: null

  readonly property string pluginId: "io.github.ferc10110.save-them-all"
  readonly property string stateDir: Quickshell.env("SAVE_THEM_ALL_STATE") || (Quickshell.env("HOME") + "/.local/state/save-them-all")
  readonly property string runtimeDir: Quickshell.env("SAVE_THEM_ALL_RUNTIME")
    || (Quickshell.env("XDG_RUNTIME_DIR") ? Quickshell.env("XDG_RUNTIME_DIR") + "/save-them-all" : "")
  readonly property string instance: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""
  readonly property string binDir: pluginPath("bin")

  property var settingsData: ({})
  readonly property string languageSetting: ["en", "es"].indexOf(settingsData.language) >= 0 ? settingsData.language : "auto"
  readonly property string lang: I18n.resolveLang(languageSetting,
    Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "")

  property var panel: null          // the bar panel shown last
  property var clients: []
  property var names: ({})
  readonly property var byAddress: {
    var out = {}
    clients.forEach(function(c) { out[c.address] = c })
    return out
  }
  readonly property var entries: DesktopEntries.applications.values.map(function(e) {
    return { id: e.id, name: e.name, icon: e.icon, startupClass: e.startupClass, exec: e.execString }
  })
  readonly property int focusedWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  readonly property bool watching: panel !== null && panel.opened === true
  readonly property var flip: flipConnection

  function pluginPath(relative) {
    var url = String(Qt.resolvedUrl(relative))
    return url.indexOf("file://") === 0 ? decodeURIComponent(url.substring(7)) : url
  }

  function t(text, args) { return I18n.t(text, lang, args) }
  function appName(win) { return AppNames.resolve(win, entries).name }
  function appIcon(win) { return AppNames.resolve(win, entries).icon }

  // The panel calls this when it opens: it is the one to close for a
  // handoff and to show again afterwards.
  function attach(p) {
    panel = p
    flipConnection.check()
    refreshClients()
  }

  function setLanguage(value) {
    var next = Object.assign({}, settingsData, { language: value })
    settingsData = next
    settingsWrite.command = ["sh", "-c",
      'mkdir -p "$1" && printf "%s\\n" "$2" >"$1/.settings.tmp" && mv "$1/.settings.tmp" "$1/settings.json"',
      "sh", stateDir, JSON.stringify(next)]
    settingsWrite.running = true
  }

  function setName(id, name) {
    Quickshell.execDetached([binDir + "/cards", "name", "--id", String(id), "--name", String(name || "")])
  }

  function refreshClients() {
    if (clientsProcess.running) clientsPending = true
    else clientsProcess.running = true
  }
  property bool clientsPending: false

  // Hyprland's toplevel for a window address ("0x…"), for live thumbnails.
  function toplevelFor(address) {
    var bare = String(address || "").replace(/^0x/, "")
    return Hyprland.toplevels.values.find(function(tl) { return tl.address === bare }) || null
  }

  function flipFinished(action, ok, message, pending) {
    var reopen = pending && pending.options && pending.options.reopen
    var ws = flipConnection.sent && flipConnection.sent.context ? flipConnection.sent.context.workspace : 0
    if (reopen && panel && (!ws || ws === focusedWorkspace)) panel.reveal()
  }

  Hyprflip {
    id: flipConnection
    t: function(text, args) { return root.t(text, args) }
    binDir: root.binDir
    lang: root.lang
    owner: root.panel
    watching: root.watching
    onFinished: function(action, ok, message, pending) { root.flipFinished(action, ok, message, pending) }
  }

  FileView {
    path: root.stateDir + "/settings.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var data = JSON.parse(String(text() || "{}"))
        root.settingsData = data && typeof data === "object" && !Array.isArray(data) ? data : {}
      } catch (e) {
        root.settingsData = {}
      }
    }
  }

  Process { id: settingsWrite }

  // Card names of this Hyprland session, written by bin/cards.
  FileView {
    path: root.runtimeDir && root.instance ? root.runtimeDir + "/cards-" + root.instance + ".json" : ""
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var data = JSON.parse(String(text() || "{}"))
        root.names = data && typeof data === "object" && !Array.isArray(data) ? data : {}
      } catch (e) {
        root.names = {}
      }
    }
    onLoadFailed: root.names = {}
  }

  Process {
    id: clientsProcess
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var list = JSON.parse(String(text || "[]"))
          root.clients = Array.isArray(list) ? list.filter(function(c) { return c && c.address }) : []
        } catch (e) {}
      }
    }
    onExited: {
      if (!root.clientsPending) return
      root.clientsPending = false
      running = true
    }
  }

  Timer { id: clientsRefresh; interval: 150; onTriggered: root.refreshClients() }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!root.watching) return
      if (["openwindow", "closewindow", "movewindowv2", "windowtitlev2", "changefloatingmode",
           "fullscreen", "workspacev2"].indexOf(event.name) >= 0)
        clientsRefresh.restart()
    }
  }

  // The shell loads this service when the session starts, which makes it the
  // place to bring marked layouts back. The script decides whether this is the
  // first start of the session; it runs detached so a shell reload halfway
  // through does not stop it.
  Component.onCompleted: Quickshell.execDetached([binDir + "/restore-them-all-at-login"])
}
```

- [ ] **Step 6: El manifiesto, el widget y el panel**

`manifest.json`: `kinds` y `entryPoints` pasan a ser:

```json
  "kinds": [
    "service",
    "bar-widget"
  ],
  "entryPoints": {
    "service": "Service.qml",
    "barWidget": "BarWidget.qml"
  },
```

`BarWidget.qml`:
- debajo de `moduleName: …`, agregar:

```qml
  // The plugin's service (Service.qml), shared by every bar and monitor.
  readonly property var service: bar && bar.shell ? bar.shell.serviceFor("io.github.ferc10110.save-them-all") : null
```

- en `injectPanel()`, debajo de la línea de `hostWidget`, agregar:

```qml
    if ("service" in target) target.service = root.service
```

- debajo de `onSettingsChanged: injectPanel()`, agregar:

```qml
  onServiceChanged: injectPanel()
```

`Panel.qml`:
- debajo de `property var hostWidget: null`, agregar:

```qml
  property var service: null
  onServiceChanged: if (service && opened) service.attach(root)
```

- agregar estas dos funciones debajo de `function save()`:

```qml
  // Hyprflip asks for the keyboard back while it works (a "handoff"); the
  // service shows the panel again when the action ends.
  function dismiss() { close() }
  function reveal() { open() }
```

- en `onOpenedChanged`, como primera línea del bloque `if (opened) { … }`, agregar:

```qml
    if (service) service.attach(root)
```

- en el `Process { id: proc`, agregar:

```qml
    environment: ({ SAVE_THEM_ALL_LANG: root.service ? root.service.lang : "" })
```

- cambiar el `Component.onCompleted` por `Component.onCompleted: refreshLogin()`, y borrar su comentario: la restauración al iniciar sesión es del servicio.

- [ ] **Step 7: Traducciones**

En `I18n.js`, dentro de `STRINGS.es`:

```js
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
```

- [ ] **Step 8: Run test to verify it passes**

Run: `make test`
Expected: PASS: `protocol.test.js` y la cobertura de `I18n.js`, que ahora ve los `t("…")` de `Protocol.js` y `Hyprflip.qml`.

- [ ] **Step 9: Commit**

```bash
git add Protocol.js Hyprflip.qml Service.qml manifest.json BarWidget.qml Panel.qml I18n.js tests
git commit -m "feat: servicio del plugin y conexión con Hyprflip"
```

---

### Task 11: Panel con pestañas, pestaña Workspace y tests de render

**Files:**
- Modify: `Panel.qml` (se reescribe: pestañas y páginas)
- Create: `WorkspaceTab.qml`, `BrowserQuitRow.qml`
- Modify: `Service.qml` (`ungroup`)
- Create: `tests/render.qml`, `tests/render-steps.js`, `tests/FakeHost.qml`, `tests/FakeService.qml`, `tests/fixtures/render.json`, `tests/test_render.py`
- Modify: `I18n.js`

**Interfaces:**
- Consumes: `service` (Task 10); los scripts de `bin/`.
- Produces:
  - Panel (el `host` de cada página):
    - propiedades: `service`, `foreground`, `dim`, `urgent`, `accent`, `fontFamily`, `workspaceId`, `record`, `phase`, `lastError`, `busy`, `hasSaved`, `loginRows`, `browserQuit`, `browserQuitError`, `pageName`;
    - funciones: `t(text, args)`, `save()`, `restore()`, `toggleLogin(row)`, `toggleBrowserQuit()`, `openPage(name)`, `close()`, `dismiss()`, `reveal()`.
    - `tabs` es la lista de pestañas y `pages` va del nombre de página a su `.qml`. Las Tasks 13, 14 y 15 les agregan entradas.
  - Una página es un `Item` con `required property var host`. Puede tener estas funciones, y el panel se las llama si existen:
    - `key(text)`, `move(dx, dy) -> bool`, `activate()`, `remove()` y `back() -> bool`;
    - `typing` (bool), para que las teclas vayan a un campo de texto.
  - Teclas del panel: `1`/`2`/`3` eligen pestaña, y `h`/`l` o ←/→ pasan de una pestaña a otra si la página no usa la tecla. `Tab` sigue siendo el de la barra, que pasa al panel vecino. `Esc` vuelve atrás si la página lo usa y, si no, cierra.
  - `service.ungroup(workspace)`: "Mostrar las dos caras".
  - Arnés de render:
    - `tests/render-steps.js` (`STEPS`: `{name, page, lang, patch}`) y `tests/fixtures/render.json`;
    - `FakeHost`/`FakeService` con la misma interfaz que el panel y el servicio, pero sin procesos;
    - `test_render.py` falla si una página no carga, si QML da error o si una página en español muestra un texto en inglés que tiene traducción.

- [ ] **Step 1: El arnés de render**

`tests/render-steps.js`:

```js
// The render harness's steps (tests/render.qml): which page, in which
// language, and what changes from tests/fixtures/render.json. A task that
// adds a page adds its steps here.
var STEPS = [
  { name: "workspace-en", page: "WorkspaceTab.qml", lang: "en", patch: {} },
  { name: "workspace-es", page: "WorkspaceTab.qml", lang: "es", patch: {} },
  { name: "workspace-paused-es", page: "WorkspaceTab.qml", lang: "es",
    patch: { status: { available: false, reason: "no-plugin", fix: "cd ~/.local/src/hyprflip-omacards && make" } } },
  { name: "workspace-empty-es", page: "WorkspaceTab.qml", lang: "es", patch: { record: null, loginRows: [] } },
]

if (typeof module !== "undefined") module.exports = { STEPS: STEPS }
```

`tests/fixtures/render.json`:

```json
{
  "focusedWorkspace": 3,
  "entries": [
    {"id": "org.gnome.Calculator.desktop", "name": "Calculator", "icon": "org.gnome.Calculator", "startupClass": "org.gnome.Calculator", "exec": "gnome-calculator"},
    {"id": "kitty.desktop", "name": "kitty", "icon": "kitty", "startupClass": "kitty", "exec": "kitty"},
    {"id": "obsidian.desktop", "name": "Obsidian", "icon": "obsidian", "startupClass": "", "exec": "obsidian %u"},
    {"id": "YouTube.desktop", "name": "YouTube", "icon": "", "startupClass": "", "exec": "omarchy-launch-webapp https://youtube.com/"}
  ],
  "clients": [
    {"address": "0x1", "class": "kitty", "title": "~", "at": [0, 0], "size": [960, 1080], "workspace": {"id": 3, "name": "3"}, "floating": false, "hidden": false, "grouped": [], "fullscreen": 0, "pinned": false, "mapped": true, "monitor": 0, "focusHistoryID": 1},
    {"address": "0x2", "class": "org.gnome.Calculator", "title": "Calculator", "at": [960, 0], "size": [960, 540], "workspace": {"id": 3, "name": "3"}, "floating": false, "hidden": false, "grouped": ["0x2", "0x3"], "fullscreen": 0, "pinned": false, "mapped": true, "monitor": 0, "focusHistoryID": 2},
    {"address": "0x3", "class": "obsidian", "title": "Notes", "at": [960, 0], "size": [960, 540], "workspace": {"id": 3, "name": "3"}, "floating": false, "hidden": true, "grouped": ["0x2", "0x3"], "fullscreen": 0, "pinned": false, "mapped": true, "monitor": 0, "focusHistoryID": 5},
    {"address": "0x4", "class": "kitty", "title": "btop", "at": [960, 540], "size": [960, 540], "workspace": {"id": 3, "name": "3"}, "floating": false, "hidden": false, "grouped": [], "fullscreen": 0, "pinned": false, "mapped": true, "monitor": 0, "focusHistoryID": 3},
    {"address": "0x5", "class": "chrome-youtube.com__-Default", "title": "YouTube", "at": [0, 0], "size": [1920, 1080], "workspace": {"id": 5, "name": "5"}, "floating": false, "hidden": false, "grouped": [], "fullscreen": 0, "pinned": false, "mapped": true, "monitor": 0, "focusHistoryID": 4}
  ],
  "names": {"1": "Notes"},
  "status": {"available": true, "reason": "ok", "hyprland": "0.56.2", "built_for": "0.56.2", "hyprflip": "0.3.0", "create_faces": true, "detail": "", "fix": ""},
  "snapshot": {
    "protocol": 1, "available": true, "error": "",
    "context": {"instance": "render", "workspace": 3, "anchor": "0x1", "anchor_label": "kitty", "anchor_token": "x"},
    "capabilities": {"containers": true, "max_panes": 5, "create_faces": true, "unpair": true, "floating": true,
                     "appearance": true, "spacing": true, "drag_to_add": true},
    "cards": [
      {"id": 1, "kind": "container", "key": "container:1", "token": "t1", "current": "0x2", "active": 0,
       "unfolded": false, "floating": false, "workspace": 3, "name": "Calculator ↔ Obsidian",
       "faces": [{"index": 0, "axis": "horizontal", "panes": [{"address": "0x2", "label": "Calculator"}]},
                 {"index": 1, "axis": "horizontal", "panes": [{"address": "0x3", "label": "Obsidian"}]}]}
    ],
    "transition": "flip", "transition_modes": ["flip", "vertical", "slide", "fade", "instant"],
    "duration_ms": 420, "appearance": "classic", "card_gap": -1,
    "shortcuts": {"available": true,
      "rows": [{"id": "flip", "label": "Voltear tarjeta", "mask": 76, "key": "F", "default_mask": 76, "default_key": "F", "shortcut": "Super+Ctrl+Alt+F", "editable": true},
               {"id": "peek", "label": "Echar un vistazo", "mask": 76, "key": "P", "default_mask": 76, "default_key": "P", "shortcut": "Super+Ctrl+Alt+P", "editable": true}],
      "occupied": [{"id": "flip", "mask": 76, "key": "F", "keycode": 0, "submap": "", "universal": false, "label": "Voltear tarjeta"},
                   {"id": null, "mask": 64, "key": "RETURN", "keycode": 0, "submap": "", "universal": false, "label": "Terminal"}]}
  },
  "record": {
    "workspace": 3, "monitor": "DP-1", "saved_at": "2026-09-25T11:59:00-03:00", "autostart": true,
    "windows": [
      {"class": "kitty", "title": "~", "launch": {"kind": "terminal"}, "at": [0, 0], "size": [960, 1080], "floating": false},
      {"class": "org.gnome.Calculator", "title": "Calculator", "launch": {"kind": "app", "desktop": "org.gnome.Calculator.desktop"}, "at": [960, 0], "size": [960, 540], "floating": false},
      {"class": "obsidian", "title": "Notes", "launch": {"kind": "app", "desktop": "obsidian.desktop"}, "at": [960, 0], "size": [960, 540], "floating": false}
    ],
    "cards": [{"name": "Notes", "faces": [{"windows": [1], "axis": "row", "ratios": [1.0]}, {"windows": [2], "axis": "row", "ratios": [1.0]}], "visible": 0, "floating": null}]
  },
  "loginRows": [{"workspace": 3, "windows": 3, "cards": 1, "saved_at": "2026-09-25T11:59:00-03:00", "autostart": true},
                {"workspace": 5, "windows": 1, "cards": 0, "saved_at": "2026-09-24T09:00:00-03:00", "autostart": false}]
}
```

`tests/FakeService.qml`:

```qml
import QtQuick
import "SaveThemAll/I18n.js" as I18n
import "SaveThemAll/AppNames.js" as AppNames
import "SaveThemAll/Protocol.js" as Protocol

// Service.qml's face without processes: the render harness fills it from
// tests/fixtures/render.json, and every action does nothing.
QtObject {
  id: fake
  property string lang: "en"
  property string languageSetting: "auto"
  property var entries: []
  property var clients: []
  property var names: ({})
  property int focusedWorkspace: 3
  property bool thumbnails: false
  property var draft: null
  property string builderNotice: ""
  property string cardsNotice: ""
  property var pickDraft: null
  property int pickFace: 0
  readonly property var byAddress: {
    var out = {}
    clients.forEach(function(c) { out[c.address] = c })
    return out
  }

  readonly property QtObject flip: QtObject {
    property var t: function(text, args) { return fake.t(text, args) }
    property var status: ({ available: true, reason: "ok" })
    property var snapshot: Protocol.emptySnapshot()
    readonly property bool available: status.available === true && snapshot.available === true
    readonly property bool canCreate: available && snapshot.capabilities.create_faces === true
    readonly property bool canUnpair: available && snapshot.capabilities.unpair === true
    readonly property string unavailableText: status.available === true ? "" : Protocol.unavailableText(status, t)
    property bool busy: false
    property string notice: ""
    property bool failed: false
    function check() {}
  }

  function t(text, args) { return I18n.t(text, lang, args) }
  function appName(win) { return AppNames.resolve(win, entries).name }
  function appIcon(win) { return AppNames.resolve(win, entries).icon }

  function load(f, language) {
    lang = language
    entries = f.entries || []
    clients = f.clients || []
    names = f.names || {}
    focusedWorkspace = f.focusedWorkspace || 3
    draft = f.draft === undefined ? null : f.draft
    pickDraft = f.pickDraft === undefined ? draft : f.pickDraft
    builderNotice = f.builderNotice || ""
    cardsNotice = f.cardsNotice || ""
    flip.status = f.status || { available: true, reason: "ok" }
    flip.snapshot = Protocol.parseSnapshot(JSON.stringify(f.snapshot || {})).snapshot
    flip.busy = f.busy === true
    flip.notice = f.notice || ""
    flip.failed = f.failed === true
  }

  // Actions: the harness only looks.
  function attach(panel) {}
  function setLanguage(value) { languageSetting = value }
  function setName(id, name) {}
  function refreshClients() {}
  function toplevelFor(address) { return null }
  function ungroup(workspace) {}
}
```

`tests/FakeHost.qml`:

```qml
import QtQuick
import qs.Commons

// Panel.qml's face for the pages, without the bar, the processes or the
// keyboard grab: what the render harness hands each page as `host`.
QtObject {
  id: host
  readonly property FakeService service: FakeService {}
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.55)
  property color urgent: Color.urgent
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property int workspaceId: 3
  property var record: null
  property string phase: ""
  property string lastError: ""
  property var loginRows: []
  property var browserQuit: ({ enabled: false, conflict: "" })
  property string browserQuitError: ""
  property string pageName: ""
  readonly property bool busy: phase !== ""
  readonly property bool hasSaved: record !== null

  function t(text, args) { return service.t(text, args) }

  function load(fixture, lang, patch) {
    var f = Object.assign({}, fixture, patch || {})
    record = f.record === undefined ? null : f.record
    loginRows = f.loginRows || []
    phase = f.phase || ""
    lastError = f.lastError || ""
    service.load(f, lang)
  }

  function save() {}
  function restore() {}
  function toggleLogin(row) {}
  function toggleBrowserQuit() {}
  function openPage(name) { pageName = name }
  function close() {}
}
```

`tests/render.qml`:

```qml
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.Commons
import "render-steps.js" as Steps

// Loads each page of the panel with a fake host and service, one step of
// tests/render-steps.js at a time, and logs the texts each one shows:
//   RENDER_TEXTS <step> <lang> <json list of texts>
// SAVE_THEM_ALL_CAPTURE_DIR, when set, also gets a PNG per step.
ShellRoot {
  id: harness
  property int step: -1
  property var fixture: null
  property bool finishing: false

  FakeHost { id: host }

  FileView {
    path: Quickshell.env("SAVE_THEM_ALL_RENDER_FIXTURE")
    onLoaded: {
      harness.fixture = JSON.parse(text())
      tick.start()
    }
  }

  Window {
    visible: true
    width: 760
    height: 760
    color: Color.popups.background

    Rectangle {
      id: area
      anchors.fill: parent
      color: Color.popups.background
      Loader { id: page; anchors.fill: parent; anchors.margins: 14 }
    }
  }

  function texts(item, out) {
    if (!item || item.visible === false) return out
    if (typeof item.text === "string" && item.text !== "") out.push(item.text)
    if (typeof item.placeholderText === "string" && item.placeholderText !== "") out.push(item.placeholderText)
    var kids = item.children || []
    for (var i = 0; i < kids.length; i++) texts(kids[i], out)
    return out
  }

  Timer {
    id: tick
    interval: 300
    onTriggered: {
      if (harness.finishing) { console.log("SAVE_THEM_ALL_RENDER_OK"); Qt.quit(); return }
      if (harness.step >= 0) {
        var done = Steps.STEPS[harness.step]
        console.log("RENDER_TEXTS " + done.name + " " + done.lang + " " + JSON.stringify(harness.texts(page.item, [])))
        var dir = Quickshell.env("SAVE_THEM_ALL_CAPTURE_DIR")
        if (dir) area.grabToImage(function(result) { result.saveToFile(dir + "/" + done.name + ".png") })
      }
      harness.step++
      if (harness.step >= Steps.STEPS.length) {
        harness.finishing = true
        tick.start()
        return
      }
      var next = Steps.STEPS[harness.step]
      host.load(harness.fixture, next.lang, next.patch)
      page.setSource(Qt.resolvedUrl("SaveThemAll/" + next.page), { host: host })
      tick.start()
    }
  }
}
```

`tests/test_render.py`:

```python
"""The panel's pages rendered offscreen with a fake host and service, in
English and Spanish: every step loads without QML errors, and a Spanish page
shows no English text that has a translation. Skipped without quickshell."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from scripttest import FAKES, FIXTURES, ROOT

QUICKSHELL = shutil.which('quickshell')
SHELL = Path('/usr/share/omarchy/shell')
PROBLEMS = ('ERROR', 'WARN scene', 'TypeError', 'ReferenceError', 'is not defined', 'Cannot assign')
ALLOWED = ('hyprland socket', 'Cannot connect to hyprland')


def node_json(script):
    return json.loads(subprocess.run(['node', '-e', script], cwd=ROOT, capture_output=True,
                                     text=True, check=True).stdout)


@unittest.skipUnless(QUICKSHELL and SHELL.is_dir(), 'needs quickshell and the Omarchy shell')
class RenderTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.es = node_json('const {load} = require("./tests/load.js");'
                           'process.stdout.write(JSON.stringify(load("I18n.js").STRINGS.es))')
        cls.steps = node_json('process.stdout.write(JSON.stringify(require("./tests/render-steps.js").STEPS))')
        with tempfile.TemporaryDirectory(prefix='save-them-all-render-') as directory:
            root = Path(directory)
            for name in ('Ui', 'Commons'):
                (root / name).symlink_to(SHELL / name)
            plugin = root / 'SaveThemAll'
            plugin.mkdir()
            for source in [*ROOT.glob('*.qml'), *ROOT.glob('*.js')]:
                shutil.copy2(source, plugin / source.name)
            shutil.copy2(ROOT / 'tests/render.qml', root / 'shell.qml')
            for name in ('FakeHost.qml', 'FakeService.qml', 'render-steps.js'):
                shutil.copy2(ROOT / 'tests' / name, root / name)
            for name in ('runtime', 'config', 'cache', 'state'):
                (root / name).mkdir(mode=0o700)
            env = {k: v for k, v in os.environ.items()
                   if k not in ('WAYLAND_DISPLAY', 'DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE')}
            env.update(PATH=f'{FAKES}:{os.environ["PATH"]}', XDG_RUNTIME_DIR=str(root / 'runtime'),
                       XDG_CONFIG_HOME=str(root / 'config'), XDG_CACHE_HOME=str(root / 'cache'),
                       SAVE_THEM_ALL_STATE=str(root / 'state'), QT_QPA_PLATFORM='offscreen',
                       QT_QPA_PLATFORMTHEME='', QT_QUICK_BACKEND='software', LIBGL_ALWAYS_SOFTWARE='1',
                       SAVE_THEM_ALL_RENDER_FIXTURE=str(FIXTURES / 'render.json'))
            done = subprocess.run([QUICKSHELL, '-p', str(root), '--no-color'], env=env,
                                  capture_output=True, text=True, timeout=180)
        cls.returncode = done.returncode
        cls.log = done.stdout + done.stderr
        cls.pages = {}
        for line in cls.log.splitlines():
            if 'RENDER_TEXTS ' in line:
                name, lang, texts = line.split('RENDER_TEXTS ', 1)[1].split(' ', 2)
                cls.pages[name] = (lang, json.loads(texts))

    def test_every_step_renders_without_qml_errors(self):
        self.assertEqual(self.returncode, 0, self.log)
        self.assertIn('SAVE_THEM_ALL_RENDER_OK', self.log)
        problems = [line for line in self.log.splitlines()
                    if any(p in line for p in PROBLEMS) and not any(a in line for a in ALLOWED)]
        self.assertEqual(problems, [])
        self.assertEqual(sorted(self.pages), sorted(s['name'] for s in self.steps))

    def test_spanish_pages_show_no_english_with_a_translation(self):
        for name, (lang, texts) in self.pages.items():
            if lang == 'es':
                left = [t for t in texts if t in self.es and self.es[t] != t]
                self.assertEqual(left, [], name)

    def test_pages_speak_their_language(self):
        expected = {
            'workspace-en': ['Save them all', 'Restore them all', 'Restore at login'],
            'workspace-es': ['Guardar todas', 'Restaurar todas', 'Restaurar al iniciar', 'Escritorio 3'],
            'workspace-paused-es': ['Tarjetas en pausa', 'Mostrar las dos caras'],
            'workspace-empty-es': ['Todavía no hay nada guardado para este escritorio.'],
        }
        for name, shown in expected.items():
            texts = self.pages[name][1]
            for text in shown:
                self.assertTrue(any(text in t for t in texts), f'{name}: {text!r} not in {texts}')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL: `test_render.py` no encuentra `WorkspaceTab.qml` (o, sin `quickshell`, se saltea; en ese caso el paso siguiente se verifica igual con `python3 -m unittest tests/test_render.py` en una máquina con Omarchy).

- [ ] **Step 3: `WorkspaceTab.qml` y `BrowserQuitRow.qml`**

`WorkspaceTab.qml`:

```qml
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// The Workspace tab: what is saved for the workspace you are on, the notice
// when its saved cards are paused, save / restore, and which workspaces come
// back at login. Everything it shows comes from files the scripts own.
Column {
  id: tab
  required property var host
  readonly property var service: host.service
  readonly property var record: host.record
  readonly property var windows: record && Array.isArray(record.windows) ? record.windows : []
  readonly property int cardCount: record && Array.isArray(record.cards) ? record.cards.length : 0
  readonly property bool cardsPaused: cardCount > 0 && service !== null
    && service.flip.status.reason !== "" && !service.flip.available
  spacing: Style.space(10)

  function key(text) {
    var k = String(text).toLowerCase()
    if (k === "s") host.save()
    else if (k === "r") host.restore()
  }

  function windowsText(n) { return n === 1 ? host.t("1 window") : host.t("%1 windows", [n]) }
  function cardsText(n) { return n === 1 ? host.t("1 card") : host.t("%1 cards", [n]) }

  readonly property string savedAtText: {
    if (!record || !record.saved_at) return host.t("earlier")
    var when = new Date(String(record.saved_at))
    if (isNaN(when.getTime())) return host.t("earlier")
    var now = new Date()
    var sameDay = when.getFullYear() === now.getFullYear() && when.getMonth() === now.getMonth()
      && when.getDate() === now.getDate()
    return sameDay ? Qt.formatTime(when, "HH:mm") : Qt.formatDateTime(when, "d MMM HH:mm")
  }

  readonly property string summaryText: {
    if (host.lastError !== "") return host.lastError
    if (host.phase === "save") return host.t("Saving…")
    if (host.phase === "restore") return host.t("Restoring…")
    if (!record) return host.t("Nothing saved for this workspace yet.")
    var parts = [windowsText(windows.length)]
    if (cardCount > 0) parts.push(cardsText(cardCount))
    parts.push(host.t("saved %1", [savedAtText]))
    return parts.join(" · ")
  }

  Text {
    textFormat: Text.PlainText
    width: parent.width
    text: tab.summaryText
    color: host.lastError !== "" ? host.urgent : host.dim
    font.family: host.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  // Hyprflip is gone but this workspace saved cards: say why, and offer to
  // take the windows out of their groups so none stays hidden.
  Column {
    width: parent.width
    visible: tab.cardsPaused
    spacing: Style.space(6)

    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: host.t("Cards paused")
      color: host.urgent
      font.family: host.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: tab.service ? tab.service.flip.unavailableText : ""
      color: host.dim
      font.family: host.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Button {
      text: host.t("Show both faces")
      iconText: "󰕰"
      tooltipText: host.t("Take this workspace's windows out of their groups so none stays hidden")
      bordered: true
      leftAlign: true
      foreground: host.foreground
      fontFamily: host.fontFamily
      onClicked: tab.service.ungroup(host.workspaceId)
    }
  }

  PanelSeparator {
    width: parent.width
    visible: tab.windows.length > 0
    foreground: host.foreground
  }

  // What is on disk, in the order the layout was saved.
  Column {
    width: parent.width
    visible: tab.windows.length > 0
    spacing: Style.space(2)

    Repeater {
      model: tab.windows

      Text {
        required property var modelData
        textFormat: Text.PlainText
        width: parent.width
        text: "· " + (tab.service ? tab.service.appName(modelData) : String(modelData["class"]))
        color: host.dim
        font.family: host.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
  }

  PanelSeparator { width: parent.width; foreground: host.foreground }

  ColumnLayout {
    width: parent.width
    spacing: Style.space(6)

    Button {
      Layout.fillWidth: true
      text: host.t("Save them all")
      iconText: "󰆓"
      tooltipText: host.t("Save every window on this workspace (s)")
      enabled: !host.busy && host.workspaceId > 0
      leftAlign: true
      bordered: true
      foreground: host.foreground
      fontFamily: host.fontFamily
      iconSpinning: host.phase === "save"
      onClicked: host.save()
    }

    Button {
      Layout.fillWidth: true
      text: host.t("Restore them all")
      iconText: "󰑓"
      tooltipText: host.hasSaved ? host.t("Reopen the saved layout (r)") : host.t("Nothing saved for this workspace yet.")
      enabled: !host.busy && host.hasSaved
      leftAlign: true
      bordered: true
      foreground: host.foreground
      fontFamily: host.fontFamily
      iconSpinning: host.phase === "restore"
      onClicked: host.restore()
    }
  }

  // Which layouts come back on their own at login: one switch per saved
  // workspace. The choice lives in each layout's own file.
  PanelSeparator { width: parent.width; visible: host.loginRows.length > 0; foreground: host.foreground }

  PanelSectionHeader {
    width: parent.width
    visible: host.loginRows.length > 0
    text: host.t("Restore at login")
    foreground: host.foreground
    fontFamily: host.fontFamily
  }

  Column {
    width: parent.width
    visible: host.loginRows.length > 0
    spacing: Style.space(6)

    Repeater {
      model: host.loginRows

      Toggle {
        required property var modelData
        width: parent.width
        label: host.t("Workspace %1", [modelData.workspace])
        description: tab.windowsText(modelData.windows)
          + (modelData.cards > 0 ? " · " + tab.cardsText(modelData.cards) : "")
          + (modelData.workspace === host.workspaceId ? " · " + host.t("this workspace") : "")
        checked: modelData.autostart === true
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: host.toggleLogin(modelData)
      }
    }
  }

  BrowserQuitRow { width: parent.width; host: tab.host }
}
```

`BrowserQuitRow.qml`:

```qml
import QtQuick
import qs.Commons
import qs.Ui

// Omarchy's Logout, Reboot and Shutdown close windows one at a time, which
// costs Chromium its tabs. This is the one switch that reaches outside the
// plugin's own files, so it starts off and says so.
Column {
  id: row
  required property var host
  spacing: Style.space(10)

  readonly property bool blocked: host.browserQuit.enabled !== true
    && (host.browserQuit.conflict !== "" || host.browserQuitError !== "")

  readonly property string description: {
    if (host.browserQuitError !== "") return host.browserQuitError
    if (host.browserQuit.enabled !== true && host.browserQuit.conflict !== "")
      return host.t("Your Omarchy menu already changes %1, so this stays off.", [host.browserQuit.conflict])
    return host.t("Before Logout, Reboot and Shutdown, so it brings its tabs back. Edits the Omarchy menu.")
  }

  PanelSeparator { width: parent.width; foreground: row.host.foreground }

  PanelSectionHeader {
    width: parent.width
    text: row.host.t("Leaving the session")
    foreground: row.host.foreground
    fontFamily: row.host.fontFamily
  }

  Toggle {
    width: parent.width
    label: row.host.t("Close the browser cleanly")
    description: row.description
    checked: row.host.browserQuit.enabled === true
    enabled: !row.blocked
    opacity: enabled ? 1 : 0.55
    foreground: row.host.foreground
    fontFamily: row.host.fontFamily
    onClicked: row.host.toggleBrowserQuit()
  }
}
```

- [ ] **Step 4: `Panel.qml` con pestañas**

Reemplazar `Panel.qml` entero:

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "I18n.js" as I18n

// The panel is a face over the scripts in bin/ and over the plugin's service.
// It shows tabs (Workspace, and later Cards and Settings) and loads each page
// with itself as `host`: the pages read state and call actions through it.
// What it knows about saved layouts comes from files the scripts own, so a
// layout saved from the menu or a terminal shows up here too.
Panel {
  id: root
  moduleName: "io.github.ferc10110.save-them-all"
  ipcTarget: "io.github.ferc10110.save-them-all"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null

  property var record: null
  property string lastError: ""
  property string phase: ""        // "save" | "restore" | ""
  property var loginRows: []       // [{ workspace, windows, cards, saved_at, autostart }]
  property bool listPending: false
  property var browserQuit: ({ enabled: false, conflict: "" })
  property string browserQuitError: ""

  readonly property bool busy: phase !== ""
  readonly property bool hasSaved: record !== null
  readonly property int workspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  readonly property string stateDir: Quickshell.env("SAVE_THEM_ALL_STATE") || (Quickshell.env("HOME") + "/.local/state/save-them-all")
  readonly property string statePath: workspaceId > 0 ? stateDir + "/workspace-" + workspaceId + ".json" : ""
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Tabs, in order, and every page by name. Later tasks add entries.
  readonly property var tabs: ["workspace"]
  readonly property var pages: ({ workspace: "WorkspaceTab.qml" })
  property string pageName: "workspace"
  readonly property bool onTab: tabs.indexOf(pageName) >= 0
  readonly property bool wide: false

  function t(text, args) { return service ? service.t(text, args) : I18n.t(text, "en", args) }

  function tabLabel(id) {
    switch (id) {
    case "workspace": return t("Workspace")
    default: return id
    }
  }

  function openPage(name) {
    if (!(name in pages)) return
    pageName = name
    page.setSource(pages[name], { host: root })
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function selectTab(index) {
    if (index >= 0 && index < tabs.length) openPage(tabs[index])
  }

  function stepTab(direction) {
    var i = tabs.indexOf(pageName)
    if (i < 0) return false
    selectTab((i + direction + tabs.length) % tabs.length)
    return true
  }

  function pluginPath(relative) {
    var url = String(Qt.resolvedUrl(relative))
    return url.indexOf("file://") === 0 ? decodeURIComponent(url.substring(7)) : url
  }

  function run(phaseName, script) {
    if (busy) return
    lastError = ""
    phase = phaseName
    proc.command = [pluginPath("bin/" + script), "--quiet"]
    proc.running = true
  }

  function save() { run("save", "save-them-all") }

  function restore() {
    if (!hasSaved) return
    run("restore", "restore-them-all")
    // Restoring shuffles every window on the workspace; a panel floating over
    // that is in the way of the thing you asked to look at.
    close()
  }

  // Hyprflip asks for the keyboard back while it works (a "handoff"); the
  // service shows the panel again when the action ends.
  function dismiss() { close() }
  function reveal() { open() }

  function refreshLogin() {
    if (listProc.running) listPending = true
    else listProc.running = true
  }

  function toggleLogin(row) {
    if (toggleProc.running) return
    var on = row.autostart !== true
    // Flip the switch on screen now; the list read after the write confirms it.
    loginRows = loginRows.map(function(r) {
      return r.workspace === row.workspace ? Object.assign({}, r, { autostart: on }) : r
    })
    toggleProc.command = [pluginPath("bin/restore-them-all-at-login"), on ? "--enable" : "--disable", String(row.workspace)]
    toggleProc.running = true
  }

  function setBrowserQuitError(text) {
    var message = String(text || "").trim()
    if (message !== "") browserQuitError = message.split("\n").pop().replace(/^close-browser-at-logout: /, "")
  }

  function refreshBrowserQuit() {
    if (!quitStatusProc.running) quitStatusProc.running = true
  }

  function toggleBrowserQuit() {
    var blocked = browserQuit.enabled !== true && (browserQuit.conflict !== "" || browserQuitError !== "")
    if (quitToggleProc.running || blocked) return
    var on = browserQuit.enabled !== true
    browserQuitError = ""
    browserQuit = Object.assign({}, browserQuit, { enabled: on })
    quitToggleProc.command = [pluginPath("bin/close-browser-at-logout"), on ? "--enable" : "--disable"]
    quitToggleProc.running = true
  }

  onServiceChanged: if (service && opened) service.attach(root)

  onOpenedChanged: if (opened) {
    if (service) service.attach(root)
    refreshLogin()
    browserQuitError = ""
    refreshBrowserQuit()
    if (!page.item) openPage(pageName)
  }

  Component.onCompleted: refreshLogin()

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: {
      reload()
      root.refreshLogin()
    }
    onLoaded: {
      try {
        var parsed = JSON.parse(String(text() || ""))
        root.record = parsed && typeof parsed === "object" && Array.isArray(parsed.windows) ? parsed : null
      } catch (e) {
        root.record = null
      }
    }
    onLoadFailed: root.record = null
  }

  Process {
    id: proc
    environment: ({ SAVE_THEM_ALL_LANG: root.service ? root.service.lang : "" })
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "") root.lastError = message.split("\n").pop()
      }
    }
    onExited: function(exitCode) {
      root.phase = ""
      if (exitCode === 0) root.lastError = ""
      else if (root.lastError === "") root.lastError = root.t("Something went wrong. Check the notification.")
      root.refreshLogin()
    }
  }

  Process {
    id: listProc
    command: [root.pluginPath("bin/restore-them-all-at-login"), "--list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var rows = JSON.parse(String(text || "[]"))
          root.loginRows = Array.isArray(rows) ? rows : []
        } catch (e) {
          root.loginRows = []
        }
      }
    }
    onExited: {
      if (!root.listPending) return
      root.listPending = false
      running = true
    }
  }

  Process {
    id: toggleProc
    onExited: root.refreshLogin()
  }

  Process {
    id: quitStatusProc
    command: [root.pluginPath("bin/close-browser-at-logout"), "--status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var status = JSON.parse(String(text || ""))
          if (status && typeof status === "object") root.browserQuit = status
        } catch (e) {}
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.setBrowserQuitError(text)
    }
  }

  Process {
    id: quitToggleProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.setBrowserQuitError(text)
    }
    onExited: root.refreshBrowserQuit()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.wide ? Style.space(760) : Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, root.wide ? Style.space(760) : Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: page.item ? page.item.typing === true : false
      onCloseRequested: {
        if (page.item && typeof page.item.back === "function" && page.item.back()) return
        root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (page.item && typeof page.item.move === "function" && page.item.move(dx, dy)) return
        if (dx !== 0) root.stepTab(dx)
      }
      onActivateRequested: if (page.item && typeof page.item.activate === "function") page.item.activate()
      onDeleteRequested: if (page.item && typeof page.item.remove === "function") page.item.remove()
      onTextKey: function(text) {
        if (root.onTab && text >= "1" && text <= "9") { root.selectTab(Number(text) - 1); return }
        if (page.item && typeof page.item.key === "function") page.item.key(String(text))
      }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        Column {
          id: column
          width: flick.width
          spacing: Style.space(10)

          PanelHero {
            id: hero
            width: parent.width
            visible: root.onTab
            title: "Save Them All"
            meta: root.workspaceId > 0 ? root.t("Workspace %1", [root.workspaceId]) : root.t("No workspace")
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "󱂬"
                color: hero.foreground
                font.family: hero.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          Row {
            width: parent.width
            visible: root.onTab && root.tabs.length > 1
            spacing: Style.space(6)

            Repeater {
              model: root.tabs

              Button {
                required property var modelData
                required property int index
                text: root.tabLabel(modelData)
                tooltipText: String(index + 1)
                selected: root.pageName === modelData
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.openPage(modelData)
              }
            }
          }

          Loader {
            id: page
            width: parent.width
          }
        }
      }
    }
  }
}
```

- [ ] **Step 5: `ungroup` en el servicio**

En `Service.qml`, debajo de `function setName`:

```qml
  // "Show both faces": let go of every native group on the workspace.
  function ungroup(workspace) {
    if (ungroupProcess.running) return
    ungroupProcess.command = [binDir + "/cards", "ungroup", "--workspace", String(workspace)]
    ungroupProcess.running = true
  }
```

y, junto a los otros `Process`:

```qml
  Process {
    id: ungroupProcess
    environment: ({ SAVE_THEM_ALL_LANG: root.lang })
    onExited: {
      root.refreshClients()
      flipConnection.check()
    }
  }
```

- [ ] **Step 6: Traducciones**

En `I18n.js`, dentro de `STRINGS.es`:

```js
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
```

- [ ] **Step 7: Run test to verify it passes**

Run: `make test`
Expected: PASS: node (cobertura), unittest y `test_render.py` con los 4 pasos de Workspace. La cobertura ya no ve los textos de la vista vieja porque `Panel.qml` se reescribió.

- [ ] **Step 8: Commit**

```bash
git add Panel.qml WorkspaceTab.qml BrowserQuitRow.qml Service.qml I18n.js tests
git commit -m "feat: panel con pestañas, pestaña Workspace y tests de render"
```

---

### Task 12: La lógica del constructor y de "Elegir en pantalla" (`Builder.js`, `Pick.js`)

**Files:**
- Create: `Builder.js`, `Pick.js`, `tests/builder.test.js`, `tests/pick.test.js`
- Modify: `I18n.js`

**Interfaces:**
- Consumes: la forma de `hyprctl -j clients` y las tarjetas del snapshot del helper (`{id, kind, faces: [{axis, panes: [{address}]}], active, floating, workspace}`).
- Produces:
  - `Builder.js`: `MAX_PER_SIDE` (5), `newDraft(workspace)`, `editDraft(card, name, rect)`, `faceOf(draft, address)`, `context(cards, draft, capabilities)` y `reason(win, ctx, t)`.
  - También: `candidates(clients, draft, ctx, t)`, `place(draft, address, face, index, t) -> {draft, problem}`, `remove(draft, address)`, `setAxis(draft, face, axis)` y `prune(draft, clients) -> {draft, gone}`.
  - Y además: `ready(draft)`, `request(draft)`, `movesFrom(draft, byAddress)`, `twinWords(win, clients, appName)`, `wordText(word, t)`, `label(win, clients, appName, t)`, `slotAspect(draft, byAddress)` y `submitText(draft, t)`.
  - El borrador es `{mode: "create"|"edit", card: null|{kind, id, faces}, workspace, faces: [[address…], […]], axes: ["row"|"column", …], visible: 0|1, floating: null|{at, size}, name, cursor}`.
  - `Pick.js`: `rects(clients, workspace, origin)`, `hit(rects, x, y)`, `toggle(draft, address, face, t)` y `faceOfPick(draft, address)`.

- [ ] **Step 1: Write the failing test**

`tests/builder.test.js`:

```js
// Run with: node --test tests/
const test = require("node:test")
const assert = require("node:assert/strict")
const { load } = require("./load.js")
const Builder = load("Builder.js")

const t = (s, a) => s.replace(/%(\d+)/g, (m, n) => (a && a[n - 1] !== undefined ? String(a[n - 1]) : m))
const win = (address, cls, ws, extra) => Object.assign({ address, class: cls, title: cls, at: [0, 0], size: [800, 600],
  workspace: { id: ws, name: String(ws) }, floating: false, hidden: false, grouped: [], fullscreen: 0, pinned: false,
  mapped: true, focusHistoryID: 1 }, extra || {})
const appName = w => w.class
const CARD = { id: 1, kind: "container", token: "t", workspace: 3, active: 1, floating: false, current: "0x3",
  faces: [{ axis: "horizontal", panes: [{ address: "0x2" }] }, { axis: "vertical", panes: [{ address: "0x3" }, { address: "0x4" }] }] }

test("newDraft starts empty on its workspace", () => {
  assert.deepEqual(Builder.newDraft(3), { mode: "create", card: null, workspace: 3, faces: [[], []], axes: ["row", "row"],
    visible: 0, floating: null, name: "", cursor: "" })
})

test("editDraft loads a card: sides, axes, the visible side and where it floats", () => {
  const d = Builder.editDraft(CARD, "Notes", null)
  assert.deepEqual(d.faces, [["0x2"], ["0x3", "0x4"]])
  assert.deepEqual(d.axes, ["row", "column"])
  assert.equal(d.visible, 1)
  assert.deepEqual(d.card, { kind: "container", id: 1, faces: [["0x2"], ["0x3", "0x4"]] })
  assert.equal(d.name, "Notes")
  const f = Builder.editDraft(Object.assign({}, CARD, { floating: true }), "", { at: [10, 20], size: [800, 600] })
  assert.deepEqual(f.floating, { at: [10, 20], size: [800, 600] })
})

test("reason says why a window cannot join", () => {
  const ctx = Builder.context([CARD], Builder.newDraft(3), {})
  assert.equal(Builder.reason(win("0x2", "a", 3), ctx, t), "Already in a card")
  assert.equal(Builder.reason(win("0x9", "a", 3, { fullscreen: 2 }), ctx, t), "Fullscreen")
  assert.equal(Builder.reason(win("0x9", "a", -98), ctx, t), "On a special workspace")
  assert.equal(Builder.reason(win("0x9", "org.quickshell", 3), ctx, t), "This panel")
  assert.equal(Builder.reason(win("0x9", "a", 3, { grouped: ["0x9", "0x8"] }), ctx, t), "In a window group")
  assert.equal(Builder.reason(win("0x9", "a", 3, { pinned: true }), ctx, t), "Pinned")
  assert.equal(Builder.reason(win("0x9", "a", 3, { floating: true }), ctx, t), "Floating; Hyprflip needs it tiled")
  assert.equal(Builder.reason(win("0x9", "a", 3, { floating: true }), Builder.context([], Builder.newDraft(3), { floating_members: true }), t), "")
  assert.equal(Builder.reason(win("0x9", "a", 3), ctx, t), "")
})

test("the card being edited does not stand in the way of its own windows", () => {
  const ctx = Builder.context([CARD], Builder.editDraft(CARD, "", null), {})
  assert.equal(Builder.reason(win("0x3", "b", 3, { hidden: true, grouped: ["0x2", "0x3", "0x4"] }), ctx, t), "")
})

test("candidates: this workspace first, then the others, then the special ones", () => {
  const clients = [win("0x5", "e", 5), win("0x1", "a", 3, { at: [900, 0] }), win("0x6", "f", -98), win("0x7", "g", 1), win("0x8", "h", 3)]
  const draft = Builder.place(Builder.newDraft(3), "0x8", 1, -1, t).draft
  const groups = Builder.candidates(clients, draft, Builder.context([], draft, {}), t)
  assert.deepEqual(groups.map(g => [g.workspace, g.current]), [[3, true], [1, false], [5, false], [-98, false]])
  assert.deepEqual(groups[0].windows.map(w => [w.address, w.face]), [["0x8", 1], ["0x1", -1]])
  assert.equal(groups[3].windows[0].reason, "On a special workspace")
})

test("place moves a window between sides and keeps the order asked", () => {
  let d = Builder.newDraft(3)
  d = Builder.place(d, "0x1", 0, -1, t).draft
  d = Builder.place(d, "0x2", 0, 0, t).draft
  assert.deepEqual(d.faces, [["0x2", "0x1"], []])
  d = Builder.place(d, "0x2", 1, -1, t).draft
  assert.deepEqual(d.faces, [["0x1"], ["0x2"]])
  assert.equal(d.cursor, "0x2")
  d = Builder.place(d, "0x1", 1, 0, t).draft
  assert.deepEqual(d.faces, [[], ["0x1", "0x2"]])
})

test("a side holds up to five windows", () => {
  let d = Builder.newDraft(3)
  for (const a of ["0x1", "0x2", "0x3", "0x4", "0x5"]) d = Builder.place(d, a, 0, -1, t).draft
  const r = Builder.place(d, "0x6", 0, -1, t)
  assert.equal(r.problem, "A side holds up to 5 windows.")
  assert.deepEqual(r.draft, d)
  assert.deepEqual(Builder.place(d, "0x5", 0, 0, t).draft.faces[0], ["0x5", "0x1", "0x2", "0x3", "0x4"])
})

test("prune removes closed windows and says which", () => {
  let d = Builder.place(Builder.place(Builder.newDraft(3), "0x1", 0, -1, t).draft, "0x2", 1, -1, t).draft
  d = Builder.place(d, "0x3", 1, -1, t).draft
  const r = Builder.prune(d, [win("0x1", "a", 3), win("0x3", "c", 3)])
  assert.deepEqual(r.gone, ["0x2"])
  assert.deepEqual(r.draft.faces, [["0x1"], ["0x3"]])
  assert.deepEqual(Builder.prune(r.draft, [win("0x1", "a", 3), win("0x3", "c", 3)]).gone, [])
})

test("request names every window by address; ratios start equal", () => {
  let d = Builder.editDraft(CARD, "Notes", null)
  d = Builder.setAxis(d, 0, "column")
  assert.ok(Builder.ready(d))
  assert.deepEqual(Builder.request(d), { faces: [["address:0x2"], ["address:0x3", "address:0x4"]],
    axes: ["column", "column"], ratios: null, visible: 1, floating: null })
  assert.ok(!Builder.ready(Builder.newDraft(3)))
})

test("movesFrom lists the windows that will change workspace", () => {
  const d = Builder.place(Builder.place(Builder.newDraft(3), "0x1", 0, -1, t).draft, "0x5", 1, -1, t).draft
  assert.deepEqual(Builder.movesFrom(d, { "0x1": win("0x1", "a", 3), "0x5": win("0x5", "e", 5) }), ["0x5"])
})

test("twins get where they are on screen", () => {
  const left = win("0x1", "kitty", 3, { at: [0, 0], size: [960, 1080] })
  const top = win("0x2", "kitty", 3, { at: [960, 0], size: [960, 540] })
  const bottom = win("0x3", "kitty", 3, { at: [960, 540], size: [960, 540] })
  const all = [left, top, bottom, win("0x4", "other", 3)]
  assert.deepEqual(Builder.twinWords(left, all, appName), ["left", "middle"])
  assert.deepEqual(Builder.twinWords(top, all, appName), ["right", "top"])
  assert.deepEqual(Builder.twinWords(win("0x4", "other", 3), all, appName), [])
  assert.equal(Builder.label(bottom, all, appName, t), "kitty · right bottom")
  assert.equal(Builder.label(all[3], all, appName, t), "other")
})

test("slotAspect is the shape of the first front window, 16:9 without one", () => {
  const d = Builder.place(Builder.newDraft(3), "0x1", 0, -1, t).draft
  assert.equal(Builder.slotAspect(d, { "0x1": win("0x1", "a", 3, { size: [960, 1080] }) }), 960 / 1080)
  assert.equal(Builder.slotAspect(Builder.newDraft(3), {}), 16 / 9)
})

test("submitText follows the mode", () => {
  assert.equal(Builder.submitText(Builder.newDraft(3), t), "Create card")
  assert.equal(Builder.submitText(Builder.editDraft(CARD, "", null), t), "Save changes")
})
```

`tests/pick.test.js`:

```js
// Run with: node --test tests/
const test = require("node:test")
const assert = require("node:assert/strict")
const { load } = require("./load.js")
const Pick = load("Pick.js")
const Builder = load("Builder.js")

const t = (s, a) => s.replace(/%(\d+)/g, (m, n) => (a && a[n - 1] !== undefined ? String(a[n - 1]) : m))
const win = (address, ws, at, size, extra) => Object.assign({ address, class: "a", at, size, workspace: { id: ws },
  floating: false, hidden: false, mapped: true, focusHistoryID: 5 }, extra || {})

test("rects: the shown windows of the workspace, relative to the monitor, floating on top", () => {
  const clients = [win("0x1", 3, [1920, 0], [960, 1080], { focusHistoryID: 2 }),
                   win("0x2", 3, [2200, 100], [400, 300], { floating: true, focusHistoryID: 3 }),
                   win("0x3", 3, [2880, 0], [960, 1080], { hidden: true }),
                   win("0x4", 4, [1920, 0], [960, 1080])]
  assert.deepEqual(Pick.rects(clients, 3, { x: 1920, y: 0 }).map(r => [r.address, r.x, r.y, r.w, r.h]),
    [["0x2", 280, 100, 400, 300], ["0x1", 0, 0, 960, 1080]])
})

test("hit finds the topmost window under the pointer", () => {
  const rects = [{ address: "0x2", x: 280, y: 100, w: 400, h: 300 }, { address: "0x1", x: 0, y: 0, w: 960, h: 1080 }]
  assert.equal(Pick.hit(rects, 300, 200), "0x2")
  assert.equal(Pick.hit(rects, 10, 10), "0x1")
  assert.equal(Pick.hit(rects, 2000, 10), "")
})

test("toggle adds to the active side and takes a picked window out", () => {
  let r = Pick.toggle(Builder.newDraft(3), "0x1", 1, t)
  assert.deepEqual(r.draft.faces, [[], ["0x1"]])
  assert.equal(Pick.faceOfPick(r.draft, "0x1"), 1)
  r = Pick.toggle(r.draft, "0x1", 0, t)
  assert.deepEqual(r.draft.faces, [[], []])
  assert.equal(Pick.faceOfPick(r.draft, "0x1"), -1)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL (`ENOENT … Builder.js`).

- [ ] **Step 3: `Builder.js`**

```js
// The card builder's draft and every rule about it, without QML: which
// windows can join a card and why not, where each one goes, and the request
// Hyprflip's `create` gets. The builder page and the pick overlay only draw
// this and call it. t is the panel's translation function.
//
// draft: { mode: "create" | "edit", card: null | { kind, id, faces },
//          workspace, faces: [[address…], [address…]],
//          axes: ["row" | "column", …], visible: 0 | 1,
//          floating: null | { at, size }, name, cursor }

var MAX_PER_SIDE = 5

function copy(draft) {
  return JSON.parse(JSON.stringify(draft))
}

function newDraft(workspace) {
  return { mode: "create", card: null, workspace: workspace, faces: [[], []], axes: ["row", "row"],
           visible: 0, floating: null, name: "", cursor: "" }
}

// card: a snapshot card; name: its name; rect: { at, size } of the window it
// shows when it floats, so it keeps its place.
function editDraft(card, name, rect) {
  var faces = card.faces.map(function(f) { return f.panes.map(function(p) { return p.address }) })
  return { mode: "edit", card: { kind: card.kind, id: card.id, faces: faces }, workspace: card.workspace,
           faces: copy(faces), axes: card.faces.map(function(f) { return f.axis === "vertical" ? "column" : "row" }),
           visible: card.active === 1 ? 1 : 0, floating: card.floating && rect ? rect : null,
           name: name || "", cursor: "" }
}

function faceOf(draft, address) {
  if (!draft) return -1
  for (var i = 0; i < 2; i++) if (draft.faces[i].indexOf(address) >= 0) return i
  return -1
}

// What reason() needs: the windows of other cards, the windows of the card
// being edited, and whether Hyprflip takes floating windows.
function context(cards, draft, capabilities) {
  var owned = {}, own = {}
  var editing = draft && draft.card ? draft.card : null
  ;(cards || []).forEach(function(c) {
    var mine = editing && c.kind === editing.kind && c.id === editing.id
    c.faces.forEach(function(f) {
      f.panes.forEach(function(p) { if (mine) own[p.address] = true; else owned[p.address] = true })
    })
  })
  return { owned: owned, own: own, floatingOk: !!(capabilities && capabilities.floating_members) }
}

// Why a window cannot join the card, or "".
function reason(win, ctx, t) {
  var mine = ctx.own[win.address] === true
  if (ctx.owned[win.address]) return t("Already in a card")
  if (win.fullscreen) return t("Fullscreen")
  if (!win.workspace || win.workspace.id <= 0) return t("On a special workspace")
  if (win["class"] === "org.quickshell") return t("This panel")
  if (!mine && win.grouped && win.grouped.length > 0) return t("In a window group")
  if (win.pinned) return t("Pinned")
  if (!mine && win.floating && !ctx.floatingOk) return t("Floating; Hyprflip needs it tiled")
  return ""
}

function byPosition(a, b) {
  return (a.win.at[0] - b.win.at[0]) || (a.win.at[1] - b.win.at[1])
}

// The builder's window list: groups by workspace, the draft's first, then
// the other workspaces in order, then the special ones.
function candidates(clients, draft, ctx, t) {
  var groups = {}
  ;(clients || []).forEach(function(c) {
    if (c.mapped === false) return
    var ws = c.workspace ? c.workspace.id : 0
    if (!groups[ws]) groups[ws] = []
    groups[ws].push({ address: c.address, win: c, reason: reason(c, ctx, t), face: faceOf(draft, c.address) })
  })
  var ids = Object.keys(groups).map(Number).sort(function(a, b) {
    if (a === draft.workspace) return -1
    if (b === draft.workspace) return 1
    if ((a > 0) !== (b > 0)) return a > 0 ? -1 : 1
    return a - b
  })
  return ids.map(function(id) {
    return { workspace: id, current: id === draft.workspace, windows: groups[id].sort(byPosition) }
  })
}

// Put a window on a side at index (-1: at the end), taking it off the
// other side. -> { draft, problem }; on a problem the draft is unchanged.
function place(draft, address, face, index, t) {
  var d = copy(draft)
  var from = faceOf(d, address)
  if (from >= 0) d.faces[from].splice(d.faces[from].indexOf(address), 1)
  if (d.faces[face].length >= MAX_PER_SIDE) return { draft: draft, problem: t("A side holds up to %1 windows.", [MAX_PER_SIDE]) }
  var at = index === undefined || index < 0 || index > d.faces[face].length ? d.faces[face].length : index
  d.faces[face].splice(at, 0, address)
  d.cursor = address
  return { draft: d, problem: "" }
}

function remove(draft, address) {
  var d = copy(draft)
  d.faces = d.faces.map(function(f) { return f.filter(function(a) { return a !== address }) })
  return d
}

function setAxis(draft, face, axis) {
  var d = copy(draft)
  d.axes[face] = axis === "column" ? "column" : "row"
  return d
}

// Take closed windows out. -> { draft, gone: [address…] }
function prune(draft, clients) {
  var open = {}
  ;(clients || []).forEach(function(c) { open[c.address] = true })
  var gone = []
  draft.faces.forEach(function(f) { f.forEach(function(a) { if (!open[a]) gone.push(a) }) })
  var d = draft
  gone.forEach(function(a) { d = remove(d, a) })
  if (gone.indexOf(d.cursor) >= 0) d.cursor = ""
  return { draft: d, gone: gone }
}

function ready(draft) {
  return !!draft && draft.faces[0].length > 0 && draft.faces[1].length > 0
}

// The fields of Hyprflip's `create`. Ratios start equal: a new layout.
function request(draft) {
  return { faces: draft.faces.map(function(f) { return f.map(function(a) { return "address:" + a }) }),
           axes: draft.axes.slice(), ratios: null, visible: draft.visible, floating: draft.floating }
}

// Windows of the draft that live on another workspace: creating the card
// moves them to the card's.
function movesFrom(draft, byAddress) {
  var out = []
  draft.faces.forEach(function(f) {
    f.forEach(function(a) {
      var w = byAddress[a]
      if (w && w.workspace && w.workspace.id !== draft.workspace) out.push(a)
    })
  })
  return out
}

// Where a window is among windows with its name on its workspace, so two
// kitty windows read "left" and "right". [] when it has no twin.
function twinWords(win, clients, appName) {
  var name = appName(win)
  var ws = win.workspace ? win.workspace.id : null
  var same = (clients || []).filter(function(c) { return c.workspace && c.workspace.id === ws && appName(c) === name })
  if (same.length < 2) return []
  function cx(c) { return c.at[0] + c.size[0] / 2 }
  function cy(c) { return c.at[1] + c.size[1] / 2 }
  var xs = same.map(cx), ys = same.map(cy)
  var minX = Math.min.apply(null, xs), maxX = Math.max.apply(null, xs)
  var minY = Math.min.apply(null, ys), maxY = Math.max.apply(null, ys)
  var words = []
  if (maxX - minX > 10) words.push(cx(win) <= minX + 10 ? "left" : cx(win) >= maxX - 10 ? "right" : "center")
  if (maxY - minY > 10) words.push(cy(win) <= minY + 10 ? "top" : cy(win) >= maxY - 10 ? "bottom" : "middle")
  return words
}

function wordText(word, t) {
  switch (word) {
  case "left": return t("left")
  case "right": return t("right")
  case "center": return t("center")
  case "top": return t("top")
  case "bottom": return t("bottom")
  case "middle": return t("middle")
  default: return word
  }
}

function label(win, clients, appName, t) {
  var words = twinWords(win, clients, appName).map(function(w) { return wordText(w, t) })
  return appName(win) + (words.length ? " · " + words.join(" ") : "")
}

// Width over height of the place the card will take: its first front window.
function slotAspect(draft, byAddress) {
  var first = draft && draft.faces[0].length ? byAddress[draft.faces[0][0]] : null
  if (first && first.size && first.size[0] > 0 && first.size[1] > 0) return first.size[0] / first.size[1]
  return 16 / 9
}

function submitText(draft, t) {
  return draft && draft.mode === "edit" ? t("Save changes") : t("Create card")
}

if (typeof module !== "undefined") {
  module.exports = { MAX_PER_SIDE: MAX_PER_SIDE, newDraft: newDraft, editDraft: editDraft, faceOf: faceOf,
                     context: context, reason: reason, candidates: candidates, place: place, remove: remove,
                     setAxis: setAxis, prune: prune, ready: ready, request: request, movesFrom: movesFrom,
                     twinWords: twinWords, wordText: wordText, label: label, slotAspect: slotAspect,
                     submitText: submitText }
}
```

- [ ] **Step 4: `Pick.js`**

```js
.import "Builder.js" as Builder

// "Pick on screen": the windows drawn on the monitor, which one is under the
// pointer, and what a click does to the draft. No QML in here.

// The shown windows of a workspace, in monitor coordinates, topmost first:
// floating windows, then by how recently each had focus.
function rects(clients, workspace, origin) {
  return (clients || []).filter(function(c) {
    return c.workspace && c.workspace.id === workspace && !c.hidden && c.mapped !== false
  }).sort(function(a, b) {
    if (!!a.floating !== !!b.floating) return a.floating ? -1 : 1
    return (a.focusHistoryID || 0) - (b.focusHistoryID || 0)
  }).map(function(c) {
    return { address: c.address, x: c.at[0] - origin.x, y: c.at[1] - origin.y, w: c.size[0], h: c.size[1] }
  })
}

function hit(list, x, y) {
  for (var i = 0; i < list.length; i++) {
    var r = list[i]
    if (x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h) return r.address
  }
  return ""
}

// A click: a picked window comes out, any other goes to the active side.
function toggle(draft, address, face, t) {
  if (Builder.faceOf(draft, address) >= 0) return { draft: Builder.remove(draft, address), problem: "" }
  return Builder.place(draft, address, face, -1, t)
}

function faceOfPick(draft, address) {
  return Builder.faceOf(draft, address)
}

if (typeof module !== "undefined") {
  module.exports = { rects: rects, hit: hit, toggle: toggle, faceOfPick: faceOfPick }
}
```

- [ ] **Step 5: Traducciones**

En `I18n.js`, dentro de `STRINGS.es`:

```js
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
```

- [ ] **Step 6: Run test to verify it passes**

Run: `make test`
Expected: PASS: `builder.test.js` (13 tests), `pick.test.js` (3) y la cobertura.

- [ ] **Step 7: Commit**

```bash
git add Builder.js Pick.js I18n.js tests
git commit -m "feat: lógica del constructor de tarjetas y de elegir en pantalla"
```

---

### Task 13: El constructor de tarjetas

**Files:**
- Create: `CardBuilder.qml`, `FaceBox.qml`, `WindowTile.qml`, `Thumb.qml`
- Modify: `Service.qml` (el borrador, crear y editar), `Panel.qml` (página `builder`, `openHome()`)
- Modify: `tests/FakeService.qml`, `tests/render-steps.js`, `tests/test_render.py`, `I18n.js`

**Interfaces:**
- Consumes: `Builder.js` (Task 12), `service.flip.run("create", …)` (Task 10), `service.clients`/`byAddress`/`toplevelFor`.
- Produces:
  - Service:
    - propiedades: `draft`, `builderNotice`, `cardsNotice`, `thumbnails` (true);
    - funciones: `startBuilder(card)`, `moveCursor(address)`, `place(address, face, index)`, `removeFromDraft(address)`, `setAxis(face, axis)`, `setDraftName(name)`, `submitDraft()` y `cancelBuilder()`.
    - Al crear o editar, el nombre de la tarjeta queda en el registro de la sesión.
    - Si una ventana elegida se cierra, sale del borrador con un aviso (Review Focus 1).
  - Panel: `openHome()` vuelve a la pestaña Tarjetas (o a la primera, si todavía no existe).
  - Teclas del constructor:
    - `j`/`k` o ↑/↓ recorren la lista; `f` manda la ventana al Frente y `r` al Reverso; `x` la saca;
    - `n` va al nombre; `Enter` crea o guarda; `Esc` cancela.

- [ ] **Step 1: Pasos de render del constructor**

`tests/render-steps.js`: agregar al final de `STEPS`:

```js
  { name: "builder-new-en", page: "CardBuilder.qml", lang: "en",
    patch: { draft: { mode: "create", card: null, workspace: 3, faces: [["0x1"], ["0x4", "0x5"]], axes: ["row", "column"],
                      visible: 0, floating: null, name: "Work", cursor: "0x4" } } },
  { name: "builder-edit-es", page: "CardBuilder.qml", lang: "es",
    patch: { draft: { mode: "edit", card: { kind: "container", id: 1, faces: [["0x2"], ["0x3"]] }, workspace: 3,
                      faces: [["0x2"], ["0x3"]], axes: ["row", "row"], visible: 0, floating: null, name: "Notes", cursor: "" } } },
  { name: "builder-notice-es", page: "CardBuilder.qml", lang: "es",
    patch: { builderNotice: "Una cara admite hasta 5 ventanas.",
             draft: { mode: "create", card: null, workspace: 3, faces: [["0x1"], []], axes: ["row", "row"],
                      visible: 0, floating: null, name: "", cursor: "0x1" } } },
```

`tests/test_render.py`: en `expected` de `test_pages_speak_their_language`, agregar:

```python
            'builder-new-en': ['New card', 'Front', 'Back', 'Create card', 'Windows', 'kitty · left'],
            'builder-edit-es': ['Editar tarjeta', 'Frente', 'Reverso', 'Guardar cambios', 'Cancelar'],
            'builder-notice-es': ['Una cara admite hasta 5 ventanas.', 'Nueva tarjeta', '＋ soltá acá'],
```

`tests/FakeService.qml`: agregar debajo de `function ungroup(workspace) {}`:

```qml
  function moveCursor(address) {}
  function place(address, face, index) {}
  function removeFromDraft(address) {}
  function setAxis(face, axis) {}
  function setDraftName(name) {}
  function submitDraft() {}
  function cancelBuilder() {}
  function startBuilder(card) {}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL: `test_render.py` no puede cargar `CardBuilder.qml`.

- [ ] **Step 3: `Thumb.qml` y `WindowTile.qml`**

`Thumb.qml`:

```qml
import QtQuick
import Quickshell.Wayland

// A picture of one window. Live only while the pointer or the keyboard is on
// it; otherwise a new frame every few seconds. Hyprland draws no frames for
// a card's hidden side, so those keep their last picture, or none.
ScreencopyView {
  id: view
  property var toplevel: null
  captureSource: toplevel ? toplevel.wayland : null
  paintCursor: false
  live: false

  Timer {
    interval: 3000
    repeat: true
    running: !view.live && view.captureSource !== null
    triggeredOnStart: true
    onTriggered: view.captureFrame()
  }
}
```

`WindowTile.qml`:

```qml
import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Builder.js" as Builder

// One window in the card builder: a thumbnail (or its icon), its readable
// name and, when it cannot join a card, why. Drag it onto a side of the
// card; drag a placed one off the card to take it out.
Item {
  id: tile
  required property var host
  required property var win
  property string reason: ""
  property int face: -1            // the side it is on, or -1
  property bool current: false     // the keyboard cursor is here
  property bool large: false       // drawn inside a side of the card
  property Item dragLayer: null
  property bool dragged: false
  readonly property var service: host.service
  readonly property string address: win ? win.address : ""
  readonly property bool usable: reason === ""
  readonly property bool hot: mouse.containsMouse || current
  implicitWidth: Style.space(220)
  implicitHeight: large ? Style.space(90) : Style.space(46)

  Item {
    id: body
    property string address: tile.address
    width: tile.width
    height: tile.height
    opacity: tile.usable ? 1 : 0.45
    Drag.active: mouse.drag.active
    Drag.keys: ["save-them-all-window"]
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2
    Drag.onActiveChanged: if (Drag.active) tile.dragged = true

    Rectangle {
      anchors.fill: parent
      radius: Math.min(Style.cornerRadius, Style.space(6))
      color: tile.hot ? Qt.rgba(host.accent.r, host.accent.g, host.accent.b, 0.14) : "transparent"
      border.width: tile.current ? 2 : 1
      border.color: tile.current ? host.accent : Qt.rgba(host.foreground.r, host.foreground.g, host.foreground.b, 0.25)
    }

    Item {
      id: picture
      x: Style.space(4)
      y: Style.space(4)
      width: tile.large ? parent.width - Style.space(8) : (parent.height - Style.space(8)) * 16 / 9
      height: tile.large ? parent.height - names.height - Style.space(10) : parent.height - Style.space(8)
      clip: true

      Loader {
        id: thumb
        anchors.fill: parent
        active: tile.service.thumbnails === true
        source: "Thumb.qml"
        onLoaded: {
          item.toplevel = Qt.binding(function() { return tile.service.toplevelFor(tile.address) })
          item.live = Qt.binding(function() { return tile.hot })
        }
      }

      Image {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.6
        height: width
        visible: !(thumb.item && thumb.item.hasContent)
        source: {
          var icon = tile.service.appIcon(tile.win)
          return icon.indexOf("/") === 0 ? "file://" + icon : Quickshell.iconPath(icon || "application-x-executable", true)
        }
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectFit
        asynchronous: true
      }
    }

    Column {
      id: names
      x: tile.large ? Style.space(6) : picture.x + picture.width + Style.space(8)
      y: tile.large ? parent.height - height - Style.space(4) : (parent.height - height) / 2
      width: parent.width - x - Style.space(6)
      spacing: Style.space(1)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: Builder.label(tile.win, tile.service.clients, tile.service.appName, host.t)
        color: host.foreground
        font.family: host.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: text !== ""
        textFormat: Text.PlainText
        text: tile.reason
        color: host.dim
        font.family: host.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: tile.usable
      drag.target: body
      onPressed: tile.dragged = false
      onClicked: tile.service.moveCursor(tile.address)
      onReleased: {
        if (!tile.dragged) return
        var action = body.Drag.drop()
        if (action === Qt.IgnoreAction && tile.face >= 0) tile.service.removeFromDraft(tile.address)
      }
    }

    // While dragged, the tile leaves its list (which clips) for the page.
    states: State {
      when: mouse.drag.active && tile.dragLayer !== null
      ParentChange { target: body; parent: tile.dragLayer }
    }
  }
}
```

- [ ] **Step 4: `FaceBox.qml` y `CardBuilder.qml`**

`FaceBox.qml`:

```qml
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// One side of the card in the builder, with the shape of the place the card
// will take. Its windows are laid out as Hyprflip will lay them out (a row
// or a column); a window dropped here joins it where it lands.
Item {
  id: box
  required property var host
  required property int face
  property Item dragLayer: null
  property real aspect: 16 / 9
  readonly property var service: host.service
  readonly property var draft: service.draft
  readonly property var members: draft ? draft.faces[face] : []
  readonly property string axis: draft ? draft.axes[face] : "row"
  implicitHeight: header.implicitHeight + Style.space(6) + area.height

  RowLayout {
    id: header
    width: parent.width
    spacing: Style.space(8)

    Text {
      textFormat: Text.PlainText
      text: box.face === 0 ? host.t("Front") : host.t("Back")
      color: host.foreground
      font.family: host.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Text {
      Layout.fillWidth: true
      textFormat: Text.PlainText
      text: box.draft && box.draft.visible === box.face ? host.t("Showing") : ""
      color: host.dim
      font.family: host.fontFamily
      font.pixelSize: Style.font.caption
    }

    ButtonGroup {
      options: [{ value: "row", label: host.t("Row") }, { value: "column", label: host.t("Column") }]
      value: box.axis
      foreground: host.foreground
      fontFamily: host.fontFamily
      fontSize: Style.font.caption
      onChanged: function(value) { box.service.setAxis(box.face, value) }
    }
  }

  Rectangle {
    id: area
    y: header.implicitHeight + Style.space(6)
    width: parent.width
    height: Math.min(width / box.aspect, Style.space(240))
    radius: Math.min(Style.cornerRadius, Style.space(8))
    color: drop.containsDrag ? Qt.rgba(host.accent.r, host.accent.g, host.accent.b, 0.12) : "transparent"
    border.width: 1
    border.color: drop.containsDrag ? host.accent : Qt.rgba(host.foreground.r, host.foreground.g, host.foreground.b, 0.35)

    Grid {
      id: tiles
      anchors.fill: parent
      anchors.margins: Style.space(6)
      spacing: Style.space(6)
      columns: box.axis === "row" ? Math.max(1, box.members.length) : 1
      rows: box.axis === "column" ? Math.max(1, box.members.length) : 1

      Repeater {
        model: box.members

        WindowTile {
          required property var modelData
          host: box.host
          win: box.service.byAddress[modelData] || ({ address: modelData, "class": "", at: [0, 0], size: [1, 1] })
          face: box.face
          large: true
          current: box.draft !== null && box.draft.cursor === modelData
          dragLayer: box.dragLayer
          width: (tiles.width - tiles.spacing * (tiles.columns - 1)) / tiles.columns
          height: (tiles.height - tiles.spacing * (tiles.rows - 1)) / tiles.rows
        }
      }
    }

    Text {
      anchors.centerIn: parent
      visible: box.members.length === 0
      textFormat: Text.PlainText
      text: host.t("＋ drop here")
      color: host.dim
      font.family: host.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    DropArea {
      id: drop
      anchors.fill: parent
      keys: ["save-them-all-window"]
      onDropped: function(event) {
        var n = box.members.length
        var along = box.axis === "row" ? event.x / width : event.y / height
        var index = Math.max(0, Math.min(n, Math.floor(along * (n + 1))))
        box.service.place(event.source.address, box.face, index)
        event.accept(Qt.MoveAction)
      }
    }
  }
}
```

`CardBuilder.qml`:

```qml
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Builder.js" as Builder

// The card builder (spec §6.2, option B): the card on the left, drawn with
// the shape of its place, Front above and Back below; the windows that can
// join it on the right, the card's workspace first. Drag a window onto a
// side, or walk the list with j/k and press f (Front) or r (Back).
Item {
  id: page
  required property var host
  readonly property var service: host.service
  readonly property var draft: service.draft
  readonly property bool typing: nameField.activeFocus
  readonly property var ctx: Builder.context(service.flip.snapshot.cards, draft, service.flip.snapshot.capabilities)
  readonly property var groups: draft ? Builder.candidates(service.clients, draft, ctx, host.t) : []
  property var expanded: ({})
  readonly property var order: {
    var out = []
    groups.forEach(function(g) {
      if (g.current || expanded[g.workspace]) g.windows.forEach(function(w) { if (w.reason === "") out.push(w.address) })
    })
    return out
  }
  readonly property var moving: draft ? Builder.movesFrom(draft, service.byAddress) : []
  readonly property int count: draft ? draft.faces[0].length + draft.faces[1].length : 0
  implicitHeight: layout.implicitHeight

  function move(dx, dy) {
    if (dy !== 0 && order.length > 0 && draft) {
      var i = order.indexOf(draft.cursor)
      var next = i < 0 ? 0 : Math.max(0, Math.min(order.length - 1, i + dy))
      service.moveCursor(order[next])
    }
    return true
  }

  function key(text) {
    if (!draft) return
    var k = String(text).toLowerCase()
    if (k === "f" && draft.cursor) service.place(draft.cursor, 0, -1)
    else if (k === "r" && draft.cursor) service.place(draft.cursor, 1, -1)
    else if (k === "n") nameField.forceActiveFocus()
  }

  function remove() {
    if (draft && draft.cursor && Builder.faceOf(draft, draft.cursor) >= 0) service.removeFromDraft(draft.cursor)
  }

  function activate() {
    if (Builder.ready(draft)) service.submitDraft()
  }

  function back() {
    service.cancelBuilder()
    return true
  }

  function groupTitle(ws) {
    return ws > 0 ? host.t("Workspace %1", [ws]) : host.t("Special workspaces")
  }

  ColumnLayout {
    id: layout
    width: parent.width
    spacing: Style.space(10)

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(10)

      Text {
        textFormat: Text.PlainText
        text: page.draft && page.draft.mode === "edit" ? host.t("Edit card") : host.t("New card")
        color: host.foreground
        font.family: host.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: page.draft ? host.t("Workspace %1 · %2 windows", [page.draft.workspace, page.count]) : ""
        color: host.dim
        font.family: host.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(14)

      Column {
        Layout.preferredWidth: layout.width * 0.56
        Layout.alignment: Qt.AlignTop
        spacing: Style.space(10)

        Repeater {
          model: [0, 1]

          FaceBox {
            required property int modelData
            width: parent.width
            host: page.host
            face: modelData
            dragLayer: page
            aspect: Builder.slotAspect(page.draft, page.service.byAddress)
          }
        }
      }

      Column {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: Style.space(6)

        Text {
          textFormat: Text.PlainText
          text: host.t("Windows")
          color: host.foreground
          font.family: host.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Flickable {
          width: parent.width
          height: Math.min(list.implicitHeight, Style.space(460))
          contentWidth: width
          contentHeight: list.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height

          Column {
            id: list
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: page.groups

              Column {
                id: group
                required property var modelData
                readonly property bool open: modelData.current || page.expanded[modelData.workspace] === true
                width: list.width
                spacing: Style.space(4)

                Button {
                  width: parent.width
                  text: page.groupTitle(group.modelData.workspace)
                  iconText: group.open ? "▾" : "▸"
                  leftAlign: true
                  foreground: host.foreground
                  fontFamily: host.fontFamily
                  fontSize: Style.font.bodySmall
                  onClicked: {
                    var next = Object.assign({}, page.expanded)
                    next[group.modelData.workspace] = !group.open
                    page.expanded = next
                  }
                }

                Repeater {
                  model: group.open ? group.modelData.windows : []

                  WindowTile {
                    required property var modelData
                    width: group.width
                    host: page.host
                    win: modelData.win
                    reason: modelData.reason
                    face: modelData.face
                    current: page.draft !== null && page.draft.cursor === modelData.address
                    dragLayer: page
                  }
                }
              }
            }
          }
        }
      }
    }

    Text {
      Layout.fillWidth: true
      visible: page.moving.length > 0
      textFormat: Text.PlainText
      text: page.moving.length > 0 ? host.t("These windows will move to workspace %1: %2",
        [page.draft.workspace, page.moving.map(function(a) { return page.service.appName(page.service.byAddress[a]) }).join(", ")]) : ""
      color: host.accent
      font.family: host.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Text {
      Layout.fillWidth: true
      visible: text !== ""
      textFormat: Text.PlainText
      text: page.service.builderNotice
      color: host.urgent
      font.family: host.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }

    Text {
      Layout.fillWidth: true
      textFormat: Text.PlainText
      text: host.t("Drag a window onto a side, or pick it with j/k and press f (Front) or r (Back). x takes it out.")
      color: host.dim
      font.family: host.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      TextField {
        id: nameField
        Layout.fillWidth: true
        placeholderText: host.t("Card name (optional)")
        text: page.draft ? page.draft.name : ""
        maximumLength: 60
        onTextEdited: page.service.setDraftName(text)
        onAccepted: page.forceActiveFocus()
        Keys.onEscapePressed: page.forceActiveFocus()
      }

      Button {
        text: Builder.submitText(page.draft, host.t)
        iconText: "󰘸"
        bordered: true
        enabled: Builder.ready(page.draft) && !page.service.flip.busy
        iconSpinning: page.service.flip.busy
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: page.service.submitDraft()
      }

      Button {
        text: host.t("Cancel")
        bordered: true
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: page.service.cancelBuilder()
      }
    }
  }
}
```

- [ ] **Step 5: El borrador en el servicio**

En `Service.qml`:
- agregar los imports:

```qml
import "Builder.js" as Builder
import "Protocol.js" as Protocol
```

- debajo de `readonly property var flip: flipConnection`, agregar:

```qml
  readonly property bool thumbnails: true
  property var draft: null          // the card builder's, kept while the panel closes
  property string builderNotice: ""
  property string cardsNotice: ""
  property var namedFaces: null     // a card just made, waiting for its name
  property string pendingName: ""
```

- cambiar `readonly property bool watching: panel !== null && panel.opened === true` por:

```qml
  readonly property bool watching: (panel !== null && panel.opened === true) || draft !== null
```

- debajo de `function toplevelFor`, agregar:

```qml
  // -- the card builder --------------------------------------------------

  function startBuilder(card) {
    builderNotice = ""
    if (card) {
      var shown = byAddress[card.current]
      var rect = card.floating && shown ? { at: shown.at, size: shown.size } : null
      draft = Builder.editDraft(card, names[String(card.id)] || "", rect)
    } else {
      draft = Builder.newDraft(focusedWorkspace)
    }
    refreshClients()
    Hyprland.refreshToplevels()
    if (panel) panel.openPage("builder")
  }

  function moveCursor(address) {
    if (draft) draft = Object.assign({}, draft, { cursor: address })
  }

  function place(address, face, index) {
    if (!draft) return
    var r = Builder.place(draft, address, face, index, t)
    draft = r.draft
    builderNotice = r.problem
  }

  function removeFromDraft(address) {
    if (!draft) return
    draft = Builder.remove(draft, address)
    builderNotice = ""
  }

  function setAxis(face, axis) {
    if (draft) draft = Builder.setAxis(draft, face, axis)
  }

  function setDraftName(name) {
    if (draft) draft = Object.assign({}, draft, { name: String(name || "") })
  }

  function cancelBuilder() {
    draft = null
    builderNotice = ""
    if (panel) panel.openHome()
  }

  function submitDraft() {
    if (!draft) return
    if (!Builder.ready(draft)) { builderNotice = t("Put at least one window on each side."); return }
    if (flipConnection.busy) { builderNotice = t("Hyprflip is busy; try again in a moment."); return }
    if (!flipConnection.canCreate) { builderNotice = flipConnection.unavailableText || t("The card could not be made."); return }
    builderNotice = ""
    var started = flipConnection.run("create", Builder.request(draft), {
      workspace: draft.workspace, replace: draft.mode === "edit" ? draft.card : null, reopen: true })
    if (!started) builderNotice = t("Hyprflip is busy; try again in a moment.")
  }

  // A window of the draft closed: it leaves the card, the rest stays.
  function pruneDraft(before) {
    if (!draft) return
    var r = Builder.prune(draft, clients)
    if (r.gone.length === 0) return
    draft = r.draft
    builderNotice = t("%1 closed and left the card.", [r.gone.map(function(a) {
      return before[a] ? appName(before[a]) : a
    }).join(", ")])
  }
```

- en `function flipFinished`, agregar al final:

```qml
    if (action === "create" && draft) {
      if (ok) {
        cardsNotice = draft.mode === "edit" ? t("Changes saved.") : t("Card created.")
        namedFaces = draft.faces
        pendingName = draft.name
        draft = null
        builderNotice = ""
        if (panel) panel.openHome()
      } else {
        builderNotice = message || t("The card could not be made.")
      }
    }
```

- en el `StdioCollector` de `clientsProcess`, cambiar el `try` por:

```qml
        try {
          var list = JSON.parse(String(text || "[]"))
          var before = root.byAddress
          root.clients = Array.isArray(list) ? list.filter(function(c) { return c && c.address }) : []
          root.pruneDraft(before)
        } catch (e) {}
```

- debajo del objeto `Hyprflip { … }`, agregar:

```qml
  // A new card gets its name once Hyprflip lists it.
  Connections {
    target: flipConnection
    function onSnapshotChanged() {
      if (!root.namedFaces) return
      var made = (flipConnection.snapshot.cards || []).find(function(c) {
        return Protocol.sameFaces(Protocol.faceAddresses(c), root.namedFaces)
      })
      if (!made) return
      root.setName(made.id, root.pendingName)
      root.namedFaces = null
    }
  }
```

- [ ] **Step 6: La página en el panel**

En `Panel.qml`:
- cambiar `readonly property var pages: ({ workspace: "WorkspaceTab.qml" })` por:

```qml
  readonly property var pages: ({ workspace: "WorkspaceTab.qml", builder: "CardBuilder.qml" })
```

- cambiar `readonly property bool wide: false` por `readonly property bool wide: pageName === "builder"`.
- debajo de `function stepTab`, agregar:

```qml
  // Back from the builder: the Cards tab once it exists, else the first.
  function openHome() { openPage("cards" in pages ? "cards" : tabs[0]) }
```

- [ ] **Step 7: Traducciones**

En `I18n.js`, dentro de `STRINGS.es`:

```js
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
    "Drag a window onto a side, or pick it with j/k and press f (Front) or r (Back). x takes it out.": "Arrastrá una ventana a una cara, o elegila con j/k y apretá f (Frente) o r (Reverso). x la saca.",
    "Card name (optional)": "Nombre de la tarjeta (opcional)",
    "Cancel": "Cancelar",
    "Put at least one window on each side.": "Poné al menos una ventana en cada cara.",
    "Hyprflip is busy; try again in a moment.": "Hyprflip está ocupado; probá de nuevo en un momento.",
    "The card could not be made.": "No se pudo armar la tarjeta.",
    "%1 closed and left the card.": "%1 se cerró y salió de la tarjeta.",
    "Changes saved.": "Cambios guardados.",
    "Card created.": "Tarjeta creada.",
```

- [ ] **Step 8: Run test to verify it passes**

Run: `make test`
Expected: PASS: los 7 pasos de render (incluido `builder-new-en` con `kitty · left`, el gemelo de la izquierda) y la cobertura.

- [ ] **Step 9: Commit**

```bash
git add CardBuilder.qml FaceBox.qml WindowTile.qml Thumb.qml Service.qml Panel.qml I18n.js tests
git commit -m "feat: constructor de tarjetas con miniaturas, arrastre y teclado"
```

---

### Task 14: La pestaña Tarjetas

**Files:**
- Create: `CardsModel.js`, `CardsTab.qml`, `tests/cardsmodel.test.js`
- Modify: `Service.qml` (`cardAction`), `Panel.qml` (pestaña `cards`)
- Modify: `tests/FakeService.qml`, `tests/render-steps.js`, `tests/test_render.py`, `I18n.js`

**Interfaces:**
- Consumes: `service.flip` (Task 10), `service.startBuilder` (Task 13), `service.names`/`byAddress`/`appName`.
- Produces:
  - `CardsModel.js`: `faceNames(card, byAddress, appName)`, `title(card, names, byAddress, appName)`, `groups(cards, focused)`, `flat(groups)`, `step(groups, key, delta)`, `modeText(card, t)`, `sideText(face, names, t)` y `reference(card)`.
  - `service.cardAction(action, card)` sirve para `flip`, `unpair`, `unfold` y `floating`. Primero pasa al workspace de la tarjeta, después revisa que siga igual y al final vuelve a abrir el panel.
  - Teclas de la pestaña Tarjetas:
    - `j`/`k` eligen tarjeta;
    - `v` o `Enter` la voltean, `e` la edita, `d` la desarma, `u` la despliega y `t` la hace flotar o la pasa a mosaico;
    - `n` arma una nueva.

- [ ] **Step 1: Write the failing test**

`tests/cardsmodel.test.js`:

```js
// Run with: node --test tests/
const test = require("node:test")
const assert = require("node:assert/strict")
const { load } = require("./load.js")
const CardsModel = load("CardsModel.js")

const t = (s, a) => s.replace(/%(\d+)/g, (m, n) => (a && a[n - 1] !== undefined ? String(a[n - 1]) : m))
const card = (id, ws, faces, extra) => Object.assign({ id, kind: "container", key: "container:" + id, token: "t" + id,
  workspace: ws, active: 0, floating: false, unfolded: false,
  faces: faces.map(f => ({ axis: "horizontal", panes: f.map(a => ({ address: a, label: "L" + a })) })) }, extra || {})
const byAddress = { "0x1": { class: "kitty" }, "0x2": { class: "obsidian" } }
const appName = w => w.class

test("a card is called by its name, else by its apps", () => {
  const c = card(1, 3, [["0x1"], ["0x2", "0x9"]])
  assert.equal(CardsModel.title(c, { 1: "Notes" }, byAddress, appName), "Notes")
  assert.equal(CardsModel.title(c, {}, byAddress, appName), "kitty ↔ obsidian + L0x9")
  assert.deepEqual(CardsModel.faceNames(c, byAddress, appName), [["kitty"], ["obsidian", "L0x9"]])
})

test("groups put the workspace on screen first", () => {
  const cards = [card(1, 5, [["0x1"], ["0x2"]]), card(2, 3, [["0x3"], ["0x4"]]), card(3, 1, [["0x5"], ["0x6"]])]
  const g = CardsModel.groups(cards, 3)
  assert.deepEqual(g.map(x => [x.workspace, x.current]), [[3, true], [1, false], [5, false]])
  assert.deepEqual(CardsModel.flat(g).map(c => c.id), [2, 3, 1])
})

test("step walks the cards in the order shown", () => {
  const g = CardsModel.groups([card(1, 5, [["a"], ["b"]]), card(2, 3, [["c"], ["d"]])], 3)
  assert.equal(CardsModel.step(g, "", 0), "container:2")
  assert.equal(CardsModel.step(g, "container:2", 1), "container:1")
  assert.equal(CardsModel.step(g, "container:1", 1), "container:1")
  assert.equal(CardsModel.step([], "", 1), "")
})

test("mode and side texts", () => {
  assert.equal(CardsModel.modeText(card(1, 3, [["a"], ["b"]]), t), "Tiled")
  assert.equal(CardsModel.modeText(card(1, 3, [["a"], ["b"]], { floating: true }), t), "Floating")
  assert.equal(CardsModel.modeText(card(1, 3, [["a"], ["b"]], { unfolded: true, floating: true }), t), "Unfolded")
  assert.equal(CardsModel.sideText(1, ["a", "b"], t), "Back: a + b")
})

test("reference is what the service checks against a fresh snapshot", () => {
  assert.deepEqual(CardsModel.reference(card(4, 3, [["0x1"], ["0x2", "0x3"]])),
    { kind: "container", id: 4, faces: [["0x1"], ["0x2", "0x3"]] })
})
```

`tests/render-steps.js`: agregar al final de `STEPS`:

```js
  { name: "cards-en", page: "CardsTab.qml", lang: "en", patch: {} },
  { name: "cards-es", page: "CardsTab.qml", lang: "es", patch: { cardsNotice: "Tarjeta creada." } },
  { name: "cards-unavailable-es", page: "CardsTab.qml", lang: "es",
    patch: { status: { available: false, reason: "no-helper", fix: "python3 ~/.local/src/hyprflip-omacards/scripts/install-setup.py --backend-only" } } },
  { name: "cards-empty-en", page: "CardsTab.qml", lang: "en", patch: { emptyCards: true } },
```

`tests/test_render.py`: en `expected`, agregar:

```python
            'cards-en': ['Notes', 'Tiled', 'Front: Calculator', 'Back: Obsidian', 'Flip', 'New card'],
            'cards-es': ['Mosaico', 'Frente: Calculator', 'Reverso: Obsidian', 'Voltear', 'Desarmar', 'Tarjeta creada.'],
            'cards-unavailable-es': ['Las tarjetas necesitan Hyprflip', 'El asistente de Hyprflip no está instalado'],
            'cards-empty-en': ['No cards yet. Press n to make one.'],
```

`tests/FakeService.qml`:
- en `load`, debajo de `flip.snapshot = …`, agregar:

```qml
    if (f.emptyCards) flip.snapshot = Object.assign({}, flip.snapshot, { cards: [] })
```

- debajo de `function startBuilder(card) {}`, agregar:

```qml
  function cardAction(action, card) {}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL (`ENOENT … CardsModel.js`; el render no encuentra `CardsTab.qml`).

- [ ] **Step 3: `CardsModel.js`**

```js
// The Cards tab's view of Hyprflip's cards: grouped by workspace, the one
// on screen first, each with a readable title and the apps on each side.
// No QML in here. t is the panel's translation function.

function faceNames(card, byAddress, appName) {
  return card.faces.map(function(f) {
    return f.panes.map(function(p) { return byAddress[p.address] ? appName(byAddress[p.address]) : String(p.label || p.address) })
  })
}

// The name given in the builder, else its apps: "kitty ↔ obsidian + btop".
function title(card, names, byAddress, appName) {
  var name = names ? names[String(card.id)] : ""
  if (name) return String(name)
  return faceNames(card, byAddress, appName).map(function(f) { return f.join(" + ") }).join(" ↔ ")
}

function groups(cards, focused) {
  var by = {}
  ;(cards || []).forEach(function(c) {
    if (!by[c.workspace]) by[c.workspace] = []
    by[c.workspace].push(c)
  })
  return Object.keys(by).map(Number).sort(function(a, b) {
    if (a === focused) return -1
    if (b === focused) return 1
    return a - b
  }).map(function(ws) { return { workspace: ws, current: ws === focused, cards: by[ws] } })
}

function flat(list) {
  var out = []
  ;(list || []).forEach(function(g) { g.cards.forEach(function(c) { out.push(c) }) })
  return out
}

// The key of the card delta places away from key (the first card when key
// is not shown), or "" with no cards.
function step(list, key, delta) {
  var cards = flat(list)
  if (cards.length === 0) return ""
  var i = cards.findIndex(function(c) { return c.key === key })
  if (i < 0) return cards[0].key
  return cards[Math.max(0, Math.min(cards.length - 1, i + delta))].key
}

function modeText(card, t) {
  if (card.unfolded) return t("Unfolded")
  return card.floating ? t("Floating") : t("Tiled")
}

function sideText(face, names, t) {
  return face === 0 ? t("Front: %1", [names.join(" + ")]) : t("Back: %1", [names.join(" + ")])
}

// What Hyprflip.run's `card` option checks against a fresh snapshot.
function reference(card) {
  return { kind: card.kind, id: card.id,
           faces: card.faces.map(function(f) { return f.panes.map(function(p) { return p.address }) }) }
}

if (typeof module !== "undefined") {
  module.exports = { faceNames: faceNames, title: title, groups: groups, flat: flat, step: step,
                     modeText: modeText, sideText: sideText, reference: reference }
}
```

- [ ] **Step 4: `CardsTab.qml`**

```qml
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "CardsModel.js" as CardsModel

// The Cards tab: Hyprflip's cards on every workspace, the one on screen
// first. Each shows its name, whether it is tiled or floating, and the apps
// on each side, the side on show in bold. Flip, edit and take apart the
// chosen one, or make a new one.
Column {
  id: tab
  required property var host
  readonly property var service: host.service
  readonly property var flip: service.flip
  readonly property var groups: CardsModel.groups(flip.snapshot.cards, service.focusedWorkspace)
  property string selectedKey: ""
  readonly property var selected: CardsModel.flat(groups).find(function(c) { return c.key === selectedKey }) || null
  spacing: Style.space(10)

  function titleOf(card) { return CardsModel.title(card, service.names, service.byAddress, service.appName) }

  function move(dx, dy) {
    if (dy === 0) return false
    selectedKey = CardsModel.step(groups, selectedKey, dy)
    return true
  }

  function key(text) {
    var k = String(text).toLowerCase()
    if (k === "n") { if (flip.canCreate) service.startBuilder(null); return }
    if (!selected) return
    if (k === "v") service.cardAction("flip", selected)
    else if (k === "e" && flip.canCreate) service.startBuilder(selected)
    else if (k === "d" && flip.canUnpair) service.cardAction("unpair", selected)
    else if (k === "u") service.cardAction("unfold", selected)
    else if (k === "t") service.cardAction("floating", selected)
  }

  function activate() {
    if (selected) service.cardAction("flip", selected)
  }

  onGroupsChanged: if (!selected) selectedKey = CardsModel.step(groups, selectedKey, 0)
  Component.onCompleted: selectedKey = CardsModel.step(groups, "", 0)

  Column {
    width: parent.width
    visible: !tab.flip.available
    spacing: Style.space(6)

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: host.t("Cards need Hyprflip")
      color: host.foreground
      font.family: host.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: tab.flip.unavailableText
      color: host.dim
      font.family: host.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Button {
      text: host.t("Check again")
      iconText: "󰑓"
      bordered: true
      foreground: host.foreground
      fontFamily: host.fontFamily
      onClicked: tab.flip.check()
    }
  }

  Text {
    width: parent.width
    visible: text !== ""
    textFormat: Text.PlainText
    text: tab.flip.busy ? host.t("Working…") : (tab.flip.failed ? tab.flip.notice : tab.service.cardsNotice)
    color: tab.flip.failed ? host.urgent : host.dim
    font.family: host.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  Text {
    width: parent.width
    visible: tab.flip.available && tab.groups.length === 0
    textFormat: Text.PlainText
    text: host.t("No cards yet. Press n to make one.")
    color: host.dim
    font.family: host.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Repeater {
    model: tab.flip.available ? tab.groups : []

    Column {
      id: group
      required property var modelData
      width: tab.width
      spacing: Style.space(6)

      PanelSectionHeader {
        width: parent.width
        text: host.t("Workspace %1", [group.modelData.workspace])
        foreground: host.foreground
        fontFamily: host.fontFamily
      }

      Repeater {
        model: group.modelData.cards

        Rectangle {
          id: cardRow
          required property var modelData
          readonly property bool chosen: tab.selectedKey === modelData.key
          readonly property var names: CardsModel.faceNames(modelData, tab.service.byAddress, tab.service.appName)
          width: group.width
          height: details.implicitHeight + Style.space(14)
          radius: Math.min(Style.cornerRadius, Style.space(6))
          color: chosen ? Qt.rgba(host.accent.r, host.accent.g, host.accent.b, 0.14) : "transparent"
          border.width: chosen ? 2 : 1
          border.color: chosen ? host.accent : Qt.rgba(host.foreground.r, host.foreground.g, host.foreground.b, 0.25)

          Column {
            id: details
            x: Style.space(10)
            y: Style.space(7)
            width: parent.width - Style.space(20)
            spacing: Style.space(2)

            RowLayout {
              width: parent.width
              spacing: Style.space(8)

              Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: tab.titleOf(cardRow.modelData)
                color: host.foreground
                font.family: host.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                textFormat: Text.PlainText
                text: CardsModel.modeText(cardRow.modelData, host.t)
                color: host.dim
                font.family: host.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Repeater {
              model: [0, 1]

              Text {
                required property int modelData
                width: details.width
                textFormat: Text.PlainText
                text: CardsModel.sideText(modelData, cardRow.names[modelData] || [], host.t)
                color: cardRow.modelData.active === modelData ? host.foreground : host.dim
                font.family: host.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: cardRow.modelData.active === modelData
                elide: Text.ElideRight
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            onClicked: tab.selectedKey = cardRow.modelData.key
            onDoubleClicked: tab.service.cardAction("flip", cardRow.modelData)
          }
        }
      }
    }
  }

  Flow {
    width: parent.width
    spacing: Style.space(6)
    visible: tab.flip.available

    Button {
      text: host.t("Flip")
      iconText: "󰑓"
      bordered: true
      enabled: tab.selected !== null && !tab.flip.busy
      foreground: host.foreground
      fontFamily: host.fontFamily
      onClicked: tab.service.cardAction("flip", tab.selected)
    }

    Button {
      text: host.t("Edit")
      iconText: "󰏫"
      bordered: true
      enabled: tab.selected !== null && tab.flip.canCreate && !tab.flip.busy
      tooltipText: tab.flip.canCreate ? "e" : host.t("Creating and editing cards needs the updated Hyprflip helper.")
      foreground: host.foreground
      fontFamily: host.fontFamily
      onClicked: tab.service.startBuilder(tab.selected)
    }

    Button {
      text: host.t("Dismantle")
      iconText: "󰆴"
      bordered: true
      enabled: tab.selected !== null && tab.flip.canUnpair && !tab.flip.busy
      tooltipText: tab.flip.canUnpair ? "d" : host.t("Dismantling needs the updated Hyprflip helper.")
      foreground: host.foreground
      fontFamily: host.fontFamily
      onClicked: tab.service.cardAction("unpair", tab.selected)
    }

    Button {
      text: host.t("New card")
      iconText: "＋"
      bordered: true
      enabled: tab.flip.canCreate && !tab.flip.busy
      tooltipText: tab.flip.canCreate ? "n" : host.t("Creating and editing cards needs the updated Hyprflip helper.")
      foreground: host.foreground
      fontFamily: host.fontFamily
      onClicked: tab.service.startBuilder(null)
    }
  }

  Text {
    width: parent.width
    visible: tab.flip.available
    textFormat: Text.PlainText
    text: host.t("v flip · e edit · d dismantle · u unfold · t float · n new")
    color: host.dim
    font.family: host.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}
```

- [ ] **Step 5: El servicio y el panel**

En `Service.qml`:
- agregar el import `import "CardsModel.js" as CardsModel`;
- debajo de `function cancelBuilder`, agregar:

```qml
  // An action on a card the panel showed: Hyprflip acts on the cards of the
  // active workspace, so it goes there first.
  function cardAction(action, card) {
    if (!card) return
    cardsNotice = ""
    flipConnection.run(action, {}, { card: CardsModel.reference(card), workspace: card.workspace, reopen: true })
  }
```

- en `function flipFinished`, agregar al final:

```qml
    if (action === "unpair" && ok) cardsNotice = t("Card taken apart; its windows stay open.")
```

En `Panel.qml`:
- cambiar `readonly property var tabs: ["workspace"]` por `readonly property var tabs: ["workspace", "cards"]`;
- cambiar `pages` por:

```qml
  readonly property var pages: ({ workspace: "WorkspaceTab.qml", cards: "CardsTab.qml", builder: "CardBuilder.qml" })
```

- en `tabLabel`, agregar el caso:

```qml
    case "cards": return t("Cards")
```

- [ ] **Step 6: Traducciones**

En `I18n.js`, dentro de `STRINGS.es`:

```js
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
```

- [ ] **Step 7: Run test to verify it passes**

Run: `make test`
Expected: PASS: `cardsmodel.test.js` (5 tests), los 11 pasos de render y la cobertura.

- [ ] **Step 8: Commit**

```bash
git add CardsModel.js CardsTab.qml Service.qml Panel.qml I18n.js tests
git commit -m "feat: pestaña Tarjetas: voltear, editar, desarmar y crear"
```

---

### Task 15: Ajustes y atajos

**Files:**
- Create: `Labels.js`, `Shortcuts.js`, `ChoiceRow.qml`, `SettingsTab.qml`, `ShortcutsPage.qml`, `tests/shortcuts.test.js`
- Modify: `Service.qml` (`setOption`), `Panel.qml` (pestaña `settings`, página `shortcuts`, `ShortcutInhibitor`), `WorkspaceTab.qml` (el switch del navegador pasa a Ajustes)
- Modify: `tests/FakeService.qml`, `tests/render-steps.js`, `tests/test_render.py`, `I18n.js`

**Interfaces:**
- Consumes:
  - de `service.flip.snapshot`: `capabilities` (`appearance`, `spacing`, `drag_to_add`), `appearance`, `card_gap`, `transition`, `transition_modes`, `duration_ms` y `shortcuts` (`rows` y `occupied`);
  - las acciones del helper `appearance`, `spacing`, `transition`, `duration` y `shortcut`;
  - `service.setLanguage` (Task 10) y `BrowserQuitRow` (Task 11).
- Produces:
  - `Labels.js`: `TRANSITIONS`, `SPEEDS`, `APPEARANCES`, `SPACINGS`, `LANGUAGES`, `SHORTCUTS`, `transitions(modes)` y `shortcutLabel(id, fallback)`. Son textos propios en inglés: se traducen con `t(entry.label)` y la cobertura los encuentra.
  - `Shortcuts.js`: `chord(mask, key, t)`, `capture(code, modifiers, autoRepeat, t)` y `conflict(occupied, selectedId, mask, key, t, labelOf)`.
  - `service.setOption(action, extra)`.
  - La página `shortcuts` tiene `recording` y `stopRecording()`. Mientras graba, el panel activa `ShortcutInhibitor`, para que Hyprland no se trague el atajo.

- [ ] **Step 1: Write the failing test**

`tests/shortcuts.test.js`:

```js
// Run with: node --test tests/
const test = require("node:test")
const assert = require("node:assert/strict")
const { load } = require("./load.js")
const Shortcuts = load("Shortcuts.js")
const Labels = load("Labels.js")

const t = (s, a) => s.replace(/%(\d+)/g, (m, n) => (a && a[n - 1] !== undefined ? String(a[n - 1]) : m))
const META = 0x10000000, CTRL = 0x04000000, ALT = 0x08000000, SHIFT = 0x02000000

test("chord names the modifiers in Hyprland's order", () => {
  assert.equal(Shortcuts.chord(76, "F", t), "Super+Ctrl+Alt+F")
  assert.equal(Shortcuts.chord(65, "space", t), "Super+Shift+Space")
  assert.equal(Shortcuts.chord(4, "Escape", t), "Ctrl+Esc")
})

test("capture turns a key press into a mask and a key", () => {
  assert.deepEqual(Shortcuts.capture(0x46, META | CTRL | ALT, false, t), { mask: 76, key: "F" })
  assert.deepEqual(Shortcuts.capture(0x01000031, META, false, t), { mask: 64, key: "F2" })
  assert.deepEqual(Shortcuts.capture(0x01000012, CTRL | SHIFT, false, t), { mask: 5, key: "Left" })
  assert.deepEqual(Shortcuts.capture(0x01000021, CTRL, false, t), { ignore: true })
  assert.deepEqual(Shortcuts.capture(0x46, META, true, t), { ignore: true })
  assert.deepEqual(Shortcuts.capture(0x01000000, 0, false, t), { cancel: true })
  assert.deepEqual(Shortcuts.capture(0x46, SHIFT, false, t), { error: "Include Super, Ctrl or Alt." })
  assert.deepEqual(Shortcuts.capture(0xe9, META, false, t), { error: "Use a letter, a number, a function key or a navigation key." })
})

test("conflict finds who already uses a chord", () => {
  const occupied = [
    { id: "flip", mask: 76, key: "F", keycode: 0, submap: "", universal: false, label: "Voltear tarjeta" },
    { id: null, mask: 64, key: "RETURN", keycode: 0, submap: "", universal: false, label: "Terminal" },
    { id: null, mask: 12, key: "", keycode: 36, submap: "", universal: false, label: "Physical" },
    { id: null, mask: 64, key: "Q", keycode: 0, submap: "resize", universal: false, label: "In a submap" },
  ]
  const labelOf = b => b.label
  assert.equal(Shortcuts.conflict(occupied, "peek", 64, "return", t, labelOf), "Used by Terminal. Choose another shortcut.")
  assert.equal(Shortcuts.conflict(occupied, "flip", 76, "F", t, labelOf), "")
  assert.equal(Shortcuts.conflict(occupied, "peek", 12, "P", t, labelOf), "A physical-key shortcut uses these modifiers. Choose other modifiers.")
  assert.equal(Shortcuts.conflict(occupied, "peek", 64, "Q", t, labelOf), "")
})

test("every Hyprflip shortcut and transition has our own label", () => {
  for (const id of ["flip", "create", "edit", "library", "find", "peek", "unpair", "mark", "pair", "attach_h", "attach_v", "release", "cancel"])
    assert.notEqual(Labels.shortcutLabel(id, ""), "", id)
  assert.equal(Labels.shortcutLabel("something-new", "Algo nuevo"), "Algo nuevo")
  const modes = ["flip", "vertical", "slide", "fade", "dissolve", "portal", "instant"]
  assert.deepEqual(Labels.transitions(modes).map(x => x.value), modes)
  assert.deepEqual(Labels.transitions(["instant", "flip", "warp"]).map(x => x.value), ["flip", "instant"])
})
```

`tests/render-steps.js`: agregar al final de `STEPS`:

```js
  { name: "settings-en", page: "SettingsTab.qml", lang: "en", patch: {} },
  { name: "settings-es", page: "SettingsTab.qml", lang: "es", patch: {} },
  { name: "settings-unavailable-es", page: "SettingsTab.qml", lang: "es",
    patch: { status: { available: false, reason: "mismatch", hyprland: "0.57.0", built_for: "0.56.2", fix: "make" } } },
  { name: "shortcuts-es", page: "ShortcutsPage.qml", lang: "es", patch: {} },
```

`tests/test_render.py`: en `expected`, agregar:

```python
            'settings-en': ['Language', 'Automatic', 'Classic tabs', 'Flip', 'Normal', 'Keyboard shortcuts',
                            'Hyprflip 0.3.0 on Hyprland 0.56.2', 'Close the browser cleanly'],
            'settings-es': ['Idioma', 'Automático', 'Pestañas clásicas', 'Voltear', 'Atajos de teclado',
                            'Cerrar el navegador limpio'],
            'settings-unavailable-es': ['Hyprflip no está disponible', 'Hyprflip no cargó', 'Idioma'],
            'shortcuts-es': ['Atajos de teclado', 'Voltear la tarjeta', 'Super+Ctrl+Alt+F'],
```

`tests/FakeService.qml`: debajo de `function cardAction(action, card) {}`, agregar:

```qml
  function setOption(action, extra) {}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL (`ENOENT … Shortcuts.js`; el render no encuentra `SettingsTab.qml`).

- [ ] **Step 3: `Labels.js` y `Shortcuts.js`**

`Labels.js`:

```js
// Our own names for Hyprflip's choices, in English: the panel shows
// t(entry.label) and t(entry.detail). Hyprflip's helper names them in
// Spanish only, so its labels are the fallback for ids we do not know.

var TRANSITIONS = [
  { value: "flip", label: "Flip", detail: "Turns sideways" },
  { value: "vertical", label: "Vertical", detail: "Turns top to bottom" },
  { value: "slide", label: "Slide", detail: "The sides slide across" },
  { value: "fade", label: "Fade", detail: "The sides fade into each other" },
  { value: "dissolve", label: "Dissolve", detail: "Experimental · Reveals in soft fragments" },
  { value: "portal", label: "Portal", detail: "Experimental · Reveals from the center" },
  { value: "instant", label: "Instant", detail: "Switches without animation" }
]

var SPEEDS = [
  { ms: 280, label: "Fast" },
  { ms: 420, label: "Normal" },
  { ms: 600, label: "Slow" }
]

var APPEARANCES = [
  { value: "classic", label: "Classic tabs", detail: "Tab bars over tiled cards" },
  { value: "frame", label: "Card frame", detail: "A shared outline and a small Flip control · Experimental" }
]

var SPACINGS = [
  { value: -1, label: "Desktop spacing", detail: "The same gaps as other tiled windows" },
  { value: 12, label: "Compact spacing", detail: "12 px between the apps of a card" }
]

var LANGUAGES = [
  { value: "auto", label: "Automatic" },
  { value: "en", label: "English" },
  { value: "es", label: "Español" }
]

var SHORTCUTS = [
  { id: "flip", label: "Flip the card" },
  { id: "create", label: "Create a card" },
  { id: "edit", label: "Edit the card" },
  { id: "library", label: "Card library" },
  { id: "find", label: "Find an app" },
  { id: "peek", label: "Peek at the other side" },
  { id: "unpair", label: "Take the card apart" },
  { id: "mark", label: "Mark an app" },
  { id: "pair", label: "Pair with the marked app" },
  { id: "attach_h", label: "Attach side by side" },
  { id: "attach_v", label: "Attach stacked" },
  { id: "release", label: "Release an app" },
  { id: "cancel", label: "Cancel" }
]

// The transitions Hyprflip offers, in our order.
function transitions(modes) {
  return TRANSITIONS.filter(function(x) { return (modes || []).indexOf(x.value) >= 0 })
}

// The English label of a Hyprflip shortcut id, or fallback.
function shortcutLabel(id, fallback) {
  var found = SHORTCUTS.find(function(x) { return x.id === id })
  return found ? found.label : fallback
}

if (typeof module !== "undefined") {
  module.exports = { TRANSITIONS: TRANSITIONS, SPEEDS: SPEEDS, APPEARANCES: APPEARANCES, SPACINGS: SPACINGS,
                     LANGUAGES: LANGUAGES, SHORTCUTS: SHORTCUTS, transitions: transitions, shortcutLabel: shortcutLabel }
}
```

`Shortcuts.js`:

```js
// Recording and checking a Hyprflip shortcut, after OmaCards'
// ShortcutsContent.qml (MIT, see NOTICE). Masks are Hyprland's (Super 64,
// Ctrl 4, Alt 8, Shift 1). Key codes and modifier bits are Qt's, written
// out here so node can test this without QML.

var KEY = {
  Escape: 0x01000000, Tab: 0x01000001, Backtab: 0x01000002, Backspace: 0x01000003, Return: 0x01000004,
  Insert: 0x01000006, Delete: 0x01000007, Home: 0x01000010, End: 0x01000011, Left: 0x01000012,
  Up: 0x01000013, Right: 0x01000014, Down: 0x01000015, PageUp: 0x01000016, PageDown: 0x01000017,
  Shift: 0x01000020, Control: 0x01000021, Meta: 0x01000022, Alt: 0x01000023, AltGr: 0x01001103,
  F1: 0x01000030, F35: 0x01000052, Space: 0x20, A: 0x41, Z: 0x5a, D0: 0x30, D9: 0x39
}
var MOD = { Shift: 0x02000000, Control: 0x04000000, Alt: 0x08000000, Meta: 0x10000000 }

// Hyprland's names for the keys that are not a letter, a digit or F1–F35.
var NAMED = {}
NAMED[KEY.Space] = "space"
NAMED[KEY.Escape] = "Escape"
NAMED[KEY.Return] = "Return"
NAMED[KEY.Tab] = "Tab"
NAMED[KEY.Backtab] = "Tab"
NAMED[KEY.Backspace] = "BackSpace"
NAMED[KEY.Delete] = "Delete"
NAMED[KEY.Insert] = "Insert"
NAMED[KEY.Home] = "Home"
NAMED[KEY.End] = "End"
NAMED[KEY.PageUp] = "Prior"
NAMED[KEY.PageDown] = "Next"
NAMED[KEY.Left] = "Left"
NAMED[KEY.Right] = "Right"
NAMED[KEY.Up] = "Up"
NAMED[KEY.Down] = "Down"

function chord(mask, key, t) {
  var names = []
  if (mask & 64) names.push("Super")
  if (mask & 4) names.push("Ctrl")
  if (mask & 8) names.push("Alt")
  if (mask & 1) names.push("Shift")
  names.push(key === "space" ? t("Space") : key === "Escape" ? "Esc" : key)
  return names.join("+")
}

// One key press while recording. -> { ignore } (a modifier alone, a
// repeat), { cancel } (Esc alone), { error } or { mask, key }.
function capture(code, modifiers, autoRepeat, t) {
  if (autoRepeat) return { ignore: true }
  if ([KEY.Control, KEY.Shift, KEY.Alt, KEY.Meta, KEY.AltGr].indexOf(code) >= 0) return { ignore: true }
  var any = MOD.Shift | MOD.Control | MOD.Alt | MOD.Meta
  if (code === KEY.Escape && !(modifiers & any)) return { cancel: true }
  var mask = 0
  if (modifiers & MOD.Meta) mask |= 64
  if (modifiers & MOD.Control) mask |= 4
  if (modifiers & MOD.Alt) mask |= 8
  if (modifiers & MOD.Shift) mask |= 1
  if (!(mask & 76)) return { error: t("Include Super, Ctrl or Alt.") }
  var key = ""
  if ((code >= KEY.A && code <= KEY.Z) || (code >= KEY.D0 && code <= KEY.D9)) key = String.fromCharCode(code)
  else if (code >= KEY.F1 && code <= KEY.F35) key = "F" + (code - KEY.F1 + 1)
  else key = NAMED[code] || ""
  if (!key) return { error: t("Use a letter, a number, a function key or a navigation key.") }
  return { mask: mask, key: key }
}

// Why the chord cannot go to selectedId, or "". A binding in a submap only
// counts when it is universal; a physical-key binding blocks its modifiers.
function conflict(occupied, selectedId, mask, key, t, labelOf) {
  var found = (occupied || []).find(function(b) {
    return b.id !== selectedId && (!b.submap || b.universal) && b.mask === mask
      && (String(b.key).toLowerCase() === String(key).toLowerCase() || b.keycode)
  })
  if (!found) return ""
  if (found.keycode) return t("A physical-key shortcut uses these modifiers. Choose other modifiers.")
  return t("Used by %1. Choose another shortcut.", [labelOf(found)])
}

if (typeof module !== "undefined") {
  module.exports = { chord: chord, capture: capture, conflict: conflict }
}
```

- [ ] **Step 4: `ChoiceRow.qml`, `SettingsTab.qml` y `ShortcutsPage.qml`**

`ChoiceRow.qml`:

```qml
import QtQuick
import qs.Commons
import qs.Ui as Ui

// One choice in a list: a title, a line of detail, marked when chosen and
// when the keyboard cursor is on it. After OmaCards' ChoiceRow.qml (MIT,
// see NOTICE).
Ui.CursorSurface {
  id: row
  property string title: ""
  property string detail: ""
  property bool selected: false
  property bool cursorHere: false
  property color textColor: Color.foreground
  property string fontFamily: Style.font.family
  signal activated()
  implicitHeight: labels.implicitHeight + Style.space(14)
  current: selected
  hasCursor: mouse.containsMouse || cursorHere
  opacity: enabled ? 1 : 0.55

  Column {
    id: labels
    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.space(10) }
    spacing: Style.space(2)

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: row.title
      color: row.textColor
      font.family: row.fontFamily
      font.pixelSize: Style.font.body
      font.bold: row.selected
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      visible: text !== ""
      textFormat: Text.PlainText
      text: row.detail
      color: Qt.darker(row.textColor, 1.55)
      font.family: row.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    onClicked: if (row.enabled) row.activated()
  }
}
```

`SettingsTab.qml`:

```qml
import QtQuick
import qs.Commons
import qs.Ui
import "Labels.js" as Labels

// The Settings tab: language, and Hyprflip's own preferences for every card
// (appearance, spacing, animation, shortcuts), what Hyprflip says about
// itself, and the switch to close the browser cleanly. Every choice is one
// row, so j/k walk them all and Enter picks.
Column {
  id: tab
  required property var host
  readonly property var service: host.service
  readonly property var flip: service.flip
  readonly property var snap: flip.snapshot
  readonly property var caps: snap.capabilities
  property int cursor: 0
  spacing: Style.space(6)

  readonly property var rows: {
    var out = []
    Labels.LANGUAGES.forEach(function(l) {
      out.push({ section: "language", title: host.t(l.label), detail: "",
                 selected: service.languageSetting === l.value, act: { kind: "language", value: l.value } })
    })
    if (flip.available && caps.appearance === true) Labels.APPEARANCES.forEach(function(a) {
      out.push({ section: "appearance", title: host.t(a.label), detail: host.t(a.detail),
                 selected: snap.appearance === a.value, act: { kind: "appearance", value: a.value } })
    })
    if (flip.available && caps.spacing === true) Labels.SPACINGS.forEach(function(s) {
      out.push({ section: "spacing", title: host.t(s.label), detail: host.t(s.detail),
                 selected: snap.card_gap === s.value, act: { kind: "spacing", value: s.value } })
    })
    if (flip.available) {
      Labels.transitions(snap.transition_modes).forEach(function(m) {
        out.push({ section: "animation", title: host.t(m.label), detail: host.t(m.detail),
                   selected: snap.transition === m.value, act: { kind: "transition", value: m.value } })
      })
      Labels.SPEEDS.forEach(function(s) {
        out.push({ section: "speed", title: host.t(s.label), detail: host.t("%1 ms", [s.ms]),
                   selected: snap.duration_ms === s.ms, act: { kind: "duration", value: s.ms } })
      })
      out.push({ section: "shortcuts", title: host.t("Keyboard shortcuts"),
                 detail: host.t("Change a shortcut or bring back the default"), selected: false, act: { kind: "page" } })
    }
    out.push({ section: "hyprflip",
               title: flip.available ? host.t("Hyprflip %1 on Hyprland %2", [flip.status.hyprflip, flip.status.hyprland])
                                     : host.t("Hyprflip is not available"),
               detail: flip.available ? host.t("Everything is in order. Press Enter to check again.") : flip.unavailableText,
               selected: false, act: { kind: "check" } })
    return out
  }

  function sectionTitle(section) {
    switch (section) {
    case "language": return host.t("Language")
    case "appearance": return host.t("Card appearance")
    case "spacing": return host.t("Space between apps")
    case "animation": return host.t("Animation")
    case "speed": return host.t("Speed")
    case "shortcuts": return host.t("Shortcuts")
    default: return "Hyprflip"
    }
  }

  function choose(row) {
    var a = row.act
    if (a.kind === "language") service.setLanguage(a.value)
    else if (a.kind === "appearance") service.setOption("appearance", { style: a.value })
    else if (a.kind === "spacing") service.setOption("spacing", { gap: a.value })
    else if (a.kind === "transition") service.setOption("transition", { mode: a.value })
    else if (a.kind === "duration") service.setOption("duration", { duration_ms: a.value })
    else if (a.kind === "page") host.openPage("shortcuts")
    else if (a.kind === "check") flip.check()
  }

  function move(dx, dy) {
    if (dy === 0) return false
    cursor = Math.max(0, Math.min(rows.length - 1, cursor + dy))
    return true
  }

  function activate() {
    if (cursor >= 0 && cursor < rows.length) choose(rows[cursor])
  }

  Repeater {
    model: tab.rows

    Column {
      id: entry
      required property var modelData
      required property int index
      width: tab.width
      spacing: Style.space(4)

      PanelSectionHeader {
        width: parent.width
        visible: entry.index === 0 || tab.rows[entry.index - 1].section !== entry.modelData.section
        text: tab.sectionTitle(entry.modelData.section)
        foreground: host.foreground
        fontFamily: host.fontFamily
      }

      ChoiceRow {
        width: parent.width
        title: entry.modelData.title
        detail: entry.modelData.detail
        selected: entry.modelData.selected
        cursorHere: tab.cursor === entry.index
        textColor: host.foreground
        fontFamily: host.fontFamily
        enabled: !tab.flip.busy || entry.modelData.section === "language"
        onActivated: { tab.cursor = entry.index; tab.choose(entry.modelData) }
      }
    }
  }

  Text {
    width: parent.width
    visible: tab.flip.available && tab.caps.drag_to_add === true
    textFormat: Text.PlainText
    text: host.t("To add an app to a card, drag its window onto the card's “Drop to add” area. Esc cancels.")
    color: host.dim
    font.family: host.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Text {
    width: parent.width
    visible: text !== ""
    textFormat: Text.PlainText
    text: tab.flip.failed ? tab.flip.notice : ""
    color: host.urgent
    font.family: host.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  BrowserQuitRow { width: parent.width; host: tab.host }
}
```

`ShortcutsPage.qml`:

```qml
import QtQuick
import qs.Commons
import qs.Ui
import "Labels.js" as Labels
import "Shortcuts.js" as Shortcuts

// Hyprflip's keyboard shortcuts, after OmaCards' ShortcutsContent.qml (MIT,
// see NOTICE): pick one, record a new chord (the panel stops Hyprland from
// acting on it meanwhile), see what else uses it, and save.
Column {
  id: page
  required property var host
  readonly property var service: host.service
  readonly property var bindings: service.flip.snapshot.shortcuts
  property int cursor: 0
  property string selectedId: ""
  readonly property var selected: bindings.rows.find(function(r) { return r.id === selectedId }) || null
  property int candidateMask: 0
  property string candidateKey: ""
  property string error: ""
  property bool recording: false
  readonly property bool typing: recording
  readonly property string conflictText: selected
    ? Shortcuts.conflict(bindings.occupied, selectedId, candidateMask, candidateKey, host.t, labelOf) : ""
  spacing: Style.space(8)

  function labelOf(binding) {
    var own = Labels.shortcutLabel(binding.id, "")
    return own ? host.t(own) : String(binding.label || "")
  }

  function rowTitle(row) { return labelOf(row) }

  function rowDetail(row) {
    var text = row.key ? Shortcuts.chord(row.mask, row.key, host.t) : host.t("Not assigned")
    return row.editable ? text : text + " · " + host.t("Not editable here")
  }

  function choose(row) {
    if (!row.editable) return
    selectedId = row.id
    candidateMask = row.mask
    candidateKey = row.key
    recording = false
    error = ""
  }

  function capture(event) {
    event.accepted = true
    var r = Shortcuts.capture(event.key, event.modifiers, event.isAutoRepeat, host.t)
    if (r.ignore) return
    if (r.cancel) { recording = false; return }
    if (r.error) { error = r.error; return }
    candidateMask = r.mask
    candidateKey = r.key
    error = ""
    recording = false
  }

  function stopRecording() { recording = false }

  function move(dx, dy) {
    if (dy === 0) return false
    cursor = Math.max(0, Math.min(bindings.rows.length - 1, cursor + dy))
    return true
  }

  function activate() {
    if (cursor >= 0 && cursor < bindings.rows.length) choose(bindings.rows[cursor])
  }

  function back() {
    if (selectedId !== "") {
      recording = false
      selectedId = ""
      return true
    }
    host.openPage("settings")
    return true
  }

  Text {
    width: parent.width
    textFormat: Text.PlainText
    text: host.t("Keyboard shortcuts")
    color: host.foreground
    font.family: host.fontFamily
    font.pixelSize: Style.font.title
    font.bold: true
  }

  Text {
    width: parent.width
    textFormat: Text.PlainText
    text: page.bindings.available ? host.t("Pick an action to change its shortcut.")
                                  : host.t("Update Hyprflip's guided setup to edit shortcuts.")
    color: host.dim
    font.family: host.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  // Keys go here while recording; the panel's key catcher stands aside.
  Item {
    id: recorder
    width: 0
    height: 0
    Keys.onPressed: function(event) { if (page.recording) page.capture(event) }
  }

  Column {
    width: parent.width
    visible: page.selected !== null
    spacing: Style.space(6)

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: page.selected ? page.rowTitle(page.selected) : ""
      color: host.foreground
      font.family: host.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: page.recording ? host.t("Press the new shortcut. Esc cancels.")
                           : Shortcuts.chord(page.candidateMask, page.candidateKey, host.t)
      color: host.foreground
      font.family: host.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Text {
      width: parent.width
      visible: text !== ""
      textFormat: Text.PlainText
      text: page.error || page.conflictText
      color: host.urgent
      font.family: host.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Flow {
      width: parent.width
      spacing: Style.space(6)

      Button {
        text: page.recording ? host.t("Listening…") : host.t("Record shortcut")
        bordered: true
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: {
          page.error = ""
          page.recording = true
          recorder.forceActiveFocus()
        }
      }

      Button {
        text: host.t("Use default")
        bordered: true
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: {
          page.candidateMask = page.selected.default_mask
          page.candidateKey = page.selected.default_key
          page.error = ""
        }
      }

      Button {
        text: host.t("Save shortcut")
        bordered: true
        enabled: !page.recording && page.error === "" && page.conflictText === "" && page.selected !== null
          && page.candidateKey !== "" && (page.candidateMask !== page.selected.mask
          || page.candidateKey.toLowerCase() !== String(page.selected.key).toLowerCase())
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: page.service.setOption("shortcut", { binding: page.selectedId, mask: page.candidateMask, key: page.candidateKey })
      }

      Button {
        text: host.t("Cancel")
        bordered: true
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: {
          page.recording = false
          page.selectedId = ""
        }
      }
    }

    PanelSeparator { width: parent.width; foreground: host.foreground }
  }

  Repeater {
    model: page.bindings.rows

    ChoiceRow {
      required property var modelData
      required property int index
      width: page.width
      title: page.rowTitle(modelData)
      detail: page.rowDetail(modelData)
      selected: modelData.id === page.selectedId
      cursorHere: page.cursor === index
      enabled: modelData.editable === true
      textColor: host.foreground
      fontFamily: host.fontFamily
      onActivated: { page.cursor = index; page.choose(modelData) }
    }
  }
}
```

- [ ] **Step 5: El servicio, el panel y la pestaña Workspace**

En `Service.qml`, debajo de `function cardAction`:

```qml
  // One of Hyprflip's preferences (appearance, spacing, transition,
  // duration, shortcut): they apply to every card.
  function setOption(action, extra) {
    cardsNotice = ""
    flipConnection.run(action, extra, { reopen: true })
  }
```

En `Panel.qml`:
- agregar el import `import Quickshell.Wayland`;
- cambiar `tabs` y `pages` por:

```qml
  readonly property var tabs: ["workspace", "cards", "settings"]
  readonly property var pages: ({ workspace: "WorkspaceTab.qml", cards: "CardsTab.qml", settings: "SettingsTab.qml",
                                  shortcuts: "ShortcutsPage.qml", builder: "CardBuilder.qml" })
```

- en `tabLabel`, agregar el caso:

```qml
    case "settings": return t("Settings")
```

- dentro de `KeyboardPanel { id: panel`, debajo de `focusTarget: keyCatcher`, agregar:

```qml
    // While a shortcut is being recorded, Hyprland must not act on it.
    property ShortcutInhibitor shortcutCapture: ShortcutInhibitor {
      window: panel
      enabled: panel.open && page.item !== null && page.item.recording === true
      onCancelled: if (page.item && typeof page.item.stopRecording === "function") page.item.stopRecording()
    }
```

En `WorkspaceTab.qml`, borrar la última línea del `Column`:

```qml
  BrowserQuitRow { width: parent.width; host: tab.host }
```

- [ ] **Step 6: Traducciones**

En `I18n.js`, dentro de `STRINGS.es`:

```js
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
```

- [ ] **Step 7: Run test to verify it passes**

Run: `make test`
Expected: PASS: `shortcuts.test.js` (4 tests), los 15 pasos de render y la cobertura (que ve los `label:`/`detail:` de `Labels.js`).

- [ ] **Step 8: Commit**

```bash
git add Labels.js Shortcuts.js ChoiceRow.qml SettingsTab.qml ShortcutsPage.qml Service.qml Panel.qml WorkspaceTab.qml I18n.js tests
git commit -m "feat: pestaña Ajustes (idioma, apariencia, animación) y atajos de Hyprflip"
```

---

### Task 16: Elegir en pantalla

**Files:**
- Create: `PickView.qml`, `PickOverlay.qml`
- Modify: `Service.qml` (`pickDraft`, `pickFace`, `startPick`, `pickToggle`, `finishPick`), `manifest.json` (kind `overlay`), `CardBuilder.qml` (tecla `e` y botón)
- Modify: `tests/FakeService.qml`, `tests/render-steps.js`, `tests/test_render.py`, `I18n.js`

**Interfaces:**
- Consumes: `Pick.js` y `Builder.js` (Task 12); `service.shell` (`summon`/`hide`, limitados al propio plugin por el shell); `Hyprland.focusedMonitor` (`x`, `y`, `name`).
- Produces:
  - `service.startPick()`: cierra el panel y abre el overlay, que trabaja sobre una copia del borrador (`pickDraft`).
  - `service.pickToggle(address)` agrega la ventana a la cara activa o la saca.
  - `service.finishPick(apply)`: con `true` el constructor se queda con lo elegido, y con `false` todo queda como estaba. En los dos casos se cierra el overlay y vuelve el panel.
  - En el overlay:
    - clic agrega o saca una ventana;
    - `Tab` cambia la cara activa;
    - `Enter` vuelve con lo elegido y `Esc` vuelve sin cambios.
    - Las ventanas no elegibles no se resaltan, y al pasar el mouse muestran el motivo.

- [ ] **Step 1: El paso de render**

`tests/render-steps.js`: agregar al final de `STEPS`:

```js
  { name: "pick-es", page: "PickView.qml", lang: "es",
    patch: { pickFace: 0, draft: { mode: "create", card: null, workspace: 3, faces: [["0x1"], ["0x4"]], axes: ["row", "row"],
                                   visible: 0, floating: null, name: "", cursor: "0x4" } } },
```

`tests/test_render.py`: en `expected`, agregar:

```python
            'pick-es': ['Sumando a: Frente', '2 elegidas', 'Clic en una ventana', 'Reverso'],
            'builder-new-en': ['New card', 'Front', 'Back', 'Create card', 'Windows', 'kitty · left', 'Pick on screen'],
```

(la segunda línea reemplaza la entrada `builder-new-en` de la Task 13).

`tests/FakeService.qml`:
- en `load`, debajo de `pickDraft = …`, agregar `pickFace = f.pickFace || 0`;
- debajo de `function setOption(action, extra) {}`, agregar:

```qml
  function startPick() {}
  function pickToggle(address) {}
  function finishPick(apply) {}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL: el render no encuentra `PickView.qml`, y `builder-new-en` no muestra "Pick on screen".

- [ ] **Step 3: `PickView.qml` y `PickOverlay.qml`**

`PickView.qml`:

```qml
import QtQuick
import qs.Commons
import "Builder.js" as Builder
import "Pick.js" as Pick

// "Pick on screen": a veil over the monitor with the workspace's shown
// windows outlined. A click adds a window to the active side, or takes a
// picked one out; Tab switches side; Enter goes back to the builder with the
// picks and Esc without them. Only what is on screen can be picked.
Item {
  id: view
  required property var host
  property var origin: ({ x: 0, y: 0 })
  readonly property var service: host.service
  readonly property var draft: service.pickDraft
  readonly property int face: service.pickFace
  readonly property var ctx: Builder.context(service.flip.snapshot.cards, draft, service.flip.snapshot.capabilities)
  readonly property var rects: Pick.rects(service.clients, service.focusedWorkspace, origin)
  readonly property int count: draft ? draft.faces[0].length + draft.faces[1].length : 0
  property string hovered: ""
  focus: true

  function sideName(f) { return f === 0 ? host.t("Front") : host.t("Back") }

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      service.pickFace = 1 - face
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      service.finishPick(true)
      event.accepted = true
    } else if (event.key === Qt.Key_Escape) {
      service.finishPick(false)
      event.accepted = true
    }
  }

  Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.35) }

  Repeater {
    model: view.rects

    Rectangle {
      id: outline
      required property var modelData
      readonly property var win: view.service.byAddress[modelData.address] || null
      readonly property string why: win ? Builder.reason(win, view.ctx, view.host.t) : ""
      readonly property int picked: Pick.faceOfPick(view.draft, modelData.address)
      readonly property bool under: view.hovered === modelData.address
      x: modelData.x
      y: modelData.y
      width: modelData.w
      height: modelData.h
      color: picked >= 0 ? Qt.rgba(view.host.accent.r, view.host.accent.g, view.host.accent.b, 0.28)
        : (under && why === "" ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
      border.width: under || picked >= 0 ? 3 : 1
      border.color: why !== "" ? Qt.rgba(1, 1, 1, 0.25) : view.host.accent

      Column {
        anchors.centerIn: parent
        width: parent.width - Style.space(20)
        visible: outline.under || outline.picked >= 0
        spacing: Style.space(4)

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: outline.win ? Builder.label(outline.win, view.service.clients, view.service.appName, view.host.t) : ""
          color: "white"
          font.family: view.host.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: outline.why !== "" ? outline.why : (outline.picked >= 0 ? view.sideName(outline.picked) : "")
          color: "white"
          font.family: view.host.fontFamily
          font.pixelSize: Style.font.body
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onPositionChanged: function(mouse) { view.hovered = Pick.hit(view.rects, mouse.x, mouse.y) }
    onClicked: function(mouse) {
      var address = Pick.hit(view.rects, mouse.x, mouse.y)
      var win = view.service.byAddress[address]
      if (address && win && Builder.reason(win, view.ctx, view.host.t) === "") view.service.pickToggle(address)
    }
  }

  Rectangle {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(24)
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(parent.width - Style.space(32), bar.implicitWidth + Style.space(32))
    height: bar.implicitHeight + Style.space(20)
    radius: Style.cornerRadius
    color: Color.popups.background
    border.width: 1
    border.color: view.host.accent

    Column {
      id: bar
      anchors.centerIn: parent
      width: Math.min(implicitWidth, parent.width - Style.space(32))
      spacing: Style.space(4)

      Text {
        textFormat: Text.PlainText
        text: view.host.t("Adding to: %1", [view.sideName(view.face)]) + " · " + view.host.t("%1 picked", [view.count])
        color: view.host.foreground
        font.family: view.host.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Text {
        visible: text !== ""
        textFormat: Text.PlainText
        text: view.service.builderNotice
        color: view.host.urgent
        font.family: view.host.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Text {
        textFormat: Text.PlainText
        text: view.host.t("Click a window to add or take it out · Tab switches side · Enter goes back with them · Esc goes back without changes")
        color: view.host.dim
        font.family: view.host.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}
```

`PickOverlay.qml`:

```qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons

// The plugin's overlay entry point: the shell loads it when the builder
// summons "Pick on screen", calls open(), and unloads it on hide. It covers
// the focused monitor with PickView and takes the keyboard while it is up.
Item {
  id: root
  property var shell: null
  property var manifest: null
  property var service: null
  property bool opened: false

  function open(payloadJson) {
    opened = true
    Qt.callLater(function() { view.forceActiveFocus() })
  }

  // Hidden by anyone else (the shell, IPC): the builder keeps its draft.
  function close() {
    opened = false
    if (service && service.picking) service.finishPick(false)
  }

  function toggle() {
    if (opened) close()
    else open("")
  }

  QtObject {
    id: pickHost
    readonly property var service: root.service
    readonly property color foreground: Color.foreground
    readonly property color dim: Qt.darker(Color.foreground, 1.55)
    readonly property color urgent: Color.urgent
    readonly property color accent: Color.accent
    readonly property string fontFamily: Style.font.family
    function t(text, args) { return root.service ? root.service.t(text, args) : text }
  }

  PanelWindow {
    id: window
    visible: root.opened && root.service !== null && root.service.picking
    screen: {
      var name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
      return Quickshell.screens.find(function(s) { return s.name === name }) || null
    }
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "save-them-all-pick"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    PickView {
      id: view
      anchors.fill: parent
      host: pickHost
      origin: Hyprland.focusedMonitor ? ({ x: Hyprland.focusedMonitor.x, y: Hyprland.focusedMonitor.y }) : ({ x: 0, y: 0 })
    }
  }
}
```

- [ ] **Step 4: El servicio, el manifiesto y el constructor**

En `Service.qml`:
- agregar el import `import "Pick.js" as Pick`;
- debajo de `property string pendingName: ""`, agregar:

```qml
  property var pickDraft: null      // the overlay's copy of the draft
  property int pickFace: 0
  readonly property bool picking: pickDraft !== null
```

- debajo de `function setOption`, agregar:

```qml
  // -- pick on screen -----------------------------------------------------

  function startPick() {
    if (!draft || !shell) return
    pickDraft = draft
    pickFace = 0
    builderNotice = ""
    refreshClients()
    if (panel) panel.dismiss()
    shell.summon(pluginId, "{}")
  }

  function pickToggle(address) {
    if (!pickDraft) return
    var r = Pick.toggle(pickDraft, address, pickFace, t)
    pickDraft = r.draft
    builderNotice = r.problem
  }

  function finishPick(apply) {
    if (!pickDraft) return
    if (apply) draft = pickDraft
    pickDraft = null
    if (shell) shell.hide(pluginId)
    if (panel) panel.reveal()
  }
```

- en `function pruneDraft(before)`, agregar al principio, antes de `if (!draft) return`:

```qml
    if (pickDraft) pickDraft = Builder.prune(pickDraft, clients).draft
```

`manifest.json`: `kinds` y `entryPoints` pasan a ser:

```json
  "kinds": [
    "service",
    "bar-widget",
    "overlay"
  ],
  "entryPoints": {
    "service": "Service.qml",
    "barWidget": "BarWidget.qml",
    "overlay": "PickOverlay.qml"
  },
```

En `CardBuilder.qml`:
- en `function key(text)`, agregar la rama:

```qml
    else if (k === "e") service.startPick()
```

- reemplazar el texto de la leyenda por:

```qml
      text: host.t("Drag a window onto a side, or pick it with j/k and press f (Front) or r (Back). x takes it out; e picks on screen.")
```

- en el `RowLayout` de abajo, antes del botón de crear, agregar:

```qml
      Button {
        text: host.t("Pick on screen")
        iconText: "󰆿"
        bordered: true
        tooltipText: "e"
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: page.service.startPick()
      }
```

- [ ] **Step 5: Traducciones**

En `I18n.js`, dentro de `STRINGS.es`:
- borrar la entrada `"Drag a window onto a side, or pick it with j/k and press f (Front) or r (Back). x takes it out."`;
- agregar:

```js
    "Drag a window onto a side, or pick it with j/k and press f (Front) or r (Back). x takes it out; e picks on screen.": "Arrastrá una ventana a una cara, o elegila con j/k y apretá f (Frente) o r (Reverso). x la saca; e elige en pantalla.",
    "Pick on screen": "Elegir en pantalla",
    "Adding to: %1": "Sumando a: %1",
    "%1 picked": "%1 elegidas",
    "Click a window to add or take it out · Tab switches side · Enter goes back with them · Esc goes back without changes": "Clic en una ventana para sumarla o sacarla · Tab cambia de cara · Enter vuelve con lo elegido · Esc vuelve sin cambios",
```

- [ ] **Step 6: Run test to verify it passes**

Run: `make test && omarchy plugin validate .`
Expected: PASS: los 16 pasos de render y la cobertura. Además, el manifiesto valida con sus tres kinds.

- [ ] **Step 7: Commit**

```bash
git add PickView.qml PickOverlay.qml Service.qml manifest.json CardBuilder.qml I18n.js tests
git commit -m "feat: elegir en pantalla las ventanas de una tarjeta"
```

---

### Task 17: Documentación, versión 2.0.0, helper instalado y prueba en vivo

**Files:**
- Create: `NOTICE`, `CHANGELOG.md`
- Modify: `README.md`, `manifest.json` (versión 2.0.0 y descripción), `preview.png`
- Fuera del repo, solo con el OK del usuario: `~/.local/lib/hyprflip/control.py`, el helper instalado. Antes se hace un backup `.bak-<fecha>`.

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: la versión 2.0.0 lista para revisar. No se publica.

- [ ] **Step 1: `NOTICE`**

```
Save Them All
Copyright (c) 2026 Fernando Cancro. MIT License (see LICENSE).

Parts of Save Them All are adapted from OmaCards
(https://github.com/nocstah/omacards), used under the MIT License:

  Hyprflip.qml     the connection to Hyprflip's helper (after Service.qml)
  ChoiceRow.qml    the choice row
  Shortcuts.js     recording and checking shortcuts (after ShortcutsContent.qml)
  ShortcutsPage.qml

MIT License

Copyright (c) 2026 Nocstah and OmaCards contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Antes de escribirlo, comparar el texto de la licencia con el de `~/.config/omarchy/plugins/io.github.nocstah.omacards/LICENSE` (`diff`). Si difiere, va el de ese archivo, tal cual.

- [ ] **Step 2: `CHANGELOG.md`**

```markdown
# Changelog

## 2.0.0

### Added

- **Cards.** With [Hyprflip](https://github.com/nocstah/hyprflip) loaded, the
  panel makes and manages flip cards: windows grouped on two sides, Front and
  Back, that flip in the same place.
  - A card builder with live thumbnails: drag windows onto either side, or
    pick them with the keyboard. Twin windows are told apart by where they
    are on screen, and windows that cannot join a card say why.
  - **Pick on screen**: click the windows themselves.
  - A Cards tab to flip, edit, take apart, unfold or float any card, on any
    workspace.
  - Hyprflip's own settings (appearance, spacing, animation) and its keyboard
    shortcuts, with conflict detection.
- **Saving a workspace saves its cards**, and restoring it builds them again:
  sides, order, axis, proportions, the side on show and where a floating card
  was. Without Hyprflip, each card comes back as a native Hyprland group with
  tabs, so no window stays hidden.
- **Show both faces**: when Hyprflip stops loading (after a Hyprland update, for
  instance), one button takes every window out of its group.
- **English and Spanish**, for the panel and the notifications. Automatic
  follows the system language.

### Changed

- The panel has tabs: Workspace, Cards and Settings. **Close the browser
  cleanly** moved to Settings.
- Restoring at login is started by the plugin's service instead of the panel.

The card format in `workspace-N.json` is a new, optional `cards` block. Version
1.3.0 ignores it, and a file without it reads as before.
```

- [ ] **Step 3: `README.md`**

a) Debajo del párrafo que empieza "Omarchy restores your session…", agregar:

```markdown
With [Hyprflip](https://github.com/nocstah/hyprflip) it also keeps **flip
cards**: windows grouped on two sides that flip in the same place. Save Them
All builds them, saves them with the workspace and brings them back.
```

b) Antes de `## How it works`, agregar esta sección:

````markdown
### Cards

Cards need Hyprflip, a Hyprland plugin, and its helper. Without them
everything else works as before, and the Cards tab says what is missing and
the command that fixes it.

- **Cards tab**: every card on every workspace. `v` or `Enter` flips the one
  chosen, `e` edits it, `d` takes it apart (its windows stay open), `u`
  unfolds it, `t` floats or tiles it, and `n` makes a new one.
- **The builder**: the card on the left, Front above and Back below, shaped
  like the place it will take; the windows on the right, this workspace's
  first. Drag a window onto a side, or walk the list with `j`/`k` and press
  `f` (Front) or `r` (Back); `x` takes one out. A side holds up to five
  windows, in a row or a column. Windows from another workspace move to the
  card's when it is made.
- **Pick on screen** (`e` in the builder) covers the monitor: click windows to
  add them to the active side, `Tab` switches side, `Enter` goes back with
  them.

**Save them all** saves the workspace's cards too, and **Restore them all**
builds them again after the windows. A card that is already built is left
alone, and a window already in another card or group is never touched. If
Hyprflip is not there when you restore, each card comes back as a native
Hyprland group with tabs, the side that was on show in front.

If Hyprflip stops loading while cards are built (after a Hyprland update, for
instance), the Workspace tab says **Cards paused** and offers **Show both
faces**, which takes every window on the workspace out of its group.

### Language

Settings → Language: Automatic (the system language), English or Español. The
notifications follow it too.
````

c) En la tabla de `## Configure`, agregar estas filas al final:

```markdown
| `SAVE_THEM_ALL_LANG` | the Language setting | `en` or `es` for the scripts' notifications |
| `SAVE_THEM_ALL_HYPRFLIP_HELPER` | `~/.local/lib/hyprflip/control.py` | Hyprflip's helper |
| `SAVE_THEM_ALL_HYPRFLIP_SRC` | `~/.local/src/hyprflip-omacards` | Where Hyprflip's source is, for the fix commands shown |
| `SAVE_THEM_ALL_HELPER_TIMEOUT` | `30` | Seconds a card may take to build before restoring gives up on it |
```

d) Reemplazar `## Requirements` por:

```markdown
## Requirements

Omarchy 4 with Hyprland 0.56 or newer, on the dwindle layout. It leans on
`hyprctl`'s Lua dispatchers, which replaced the old string syntax in 0.56, and
on `jq`, `python3` and `pstree`, all of which ship with Omarchy.

Cards are optional and need Hyprflip 0.3 with its helper (protocol 1).
Building whole cards and taking them apart need a helper with the `create`
(with sides) and `unpair` actions; an older helper still flips and edits
nothing, and restoring falls back to native groups.
```

e) En `## Limitations`:
- cambiar el punto de **Login restore needs the widget in the bar.** por:

```markdown
- **Login restore needs the plugin enabled.** Its service is what starts it,
  so a disabled plugin restores nothing at login.
```

- agregar al final:

```markdown
- **A card lives on one workspace.** Its windows move there when it is made.
- **A card's hidden side has no live thumbnail.** Hyprland does not draw it, so
  the builder shows its last picture, or its icon.
- **Hyprflip's own messages are in Spanish.** Its helper writes them; the rest
  of the panel follows the Language setting.
```

- [ ] **Step 4: Versión y descripción**

`manifest.json`:
- `"version": "2.0.0"`;
- `"description": "Save the window layout of a Hyprland workspace and bring it back exactly, on demand or at login: the same apps, the same splits, the same sizes. With Hyprflip, it also builds, saves and restores flip cards."`;
- en `barWidget.description`: `"Save and restore the window layout and flip cards of the current workspace"`.

Run: `omarchy plugin validate . && make test`
Expected: el manifiesto valida y todo pasa.

- [ ] **Step 5: `preview.png`**

```bash
cap=$(mktemp -d)
SAVE_THEM_ALL_CAPTURE_DIR="$cap" python3 -m unittest tests/test_render.py
ls "$cap"   # expected: a PNG for every render step
cp "$cap/builder-new-en.png" preview.png
```

(Para que la variable llegue al arnés, `test_render.py` pasa `SAVE_THEM_ALL_CAPTURE_DIR` al entorno de `quickshell` si está definida. Hay que agregar en `env.update(...)` de `setUpClass`: `**({'SAVE_THEM_ALL_CAPTURE_DIR': os.environ['SAVE_THEM_ALL_CAPTURE_DIR']} if os.environ.get('SAVE_THEM_ALL_CAPTURE_DIR') else {})`.) Mirar la imagen: tiene que verse el constructor, con el Frente y el Reverso y la lista de ventanas.

- [ ] **Step 6: Commit**

```bash
git add NOTICE CHANGELOG.md README.md manifest.json preview.png tests/test_render.py
git commit -m "docs: README, CHANGELOG y NOTICE de la 2.0.0; versión 2.0.0"
```

- [ ] **Step 7: Instalar el helper actualizado (solo con el OK del usuario)**

Pedirle el OK al usuario con este texto: "Para probar crear y desarmar tarjetas en vivo hay que reemplazar `~/.local/lib/hyprflip/control.py` por el del fork (rama `save-them-all-create`). Queda un backup al lado. ¿Lo hago?". Sin el OK, saltar al Step 8 y probar solo lo que no crea ni desarma, más la restauración con grupos nativos.

Con el OK:

```bash
L=~/.local/lib/hyprflip
H=~/.local/src/hyprflip-omacards
diff -q "$H/scripts/workflow.py" "$L/workflow.py" && diff -q "$H/scripts/shortcuts.py" "$L/shortcuts.py"
# expected: no output. If they differ, stop: the installed helper is from another version; ask the user.
cp -p "$L/control.py" "$L/control.py.bak-$(date +%Y%m%d-%H%M%S)"
cp "$H/scripts/control.py" "$L/control.py"
python3 "$L/control.py" snapshot | jq '.protocol, .capabilities.create_faces, .capabilities.unpair'
# expected: 1, true, true
```

- [ ] **Step 8: Prueba en vivo**

La prueba usa solo ventanas descartables en un workspace vacío N ≥ 7, y el estado va a un directorio temporal. Nunca se tocan las ventanas del usuario ni sus `workspace-*.json`.

```bash
R=~/.config/omarchy/plugins/io.github.ferc10110.save-them-all
home_ws=$(hyprctl -j activeworkspace | jq '.id')
used=$(hyprctl -j clients | jq '[.[].workspace.id] | unique')
N=$(jq -n --argjson used "$used" 'first(range(7; 100) | select(. as $n | $used | index($n) | not))')
export SAVE_THEM_ALL_STATE=$(mktemp -d)
ls ~/.local/state/save-them-all/ > /tmp/sta-before.txt   # the user's files, to compare at the end
omarchy-restart-shell                                     # loads the service and the overlay
hyprctl dispatch "hl.dsp.focus({ workspace = '$N' })"
for i in 1 2 3; do kitty --class "sta-test-$i" --title "sta-test-$i" & sleep 1; done
hyprctl -j clients | jq --argjson n "$N" '[.[] | select(.workspace.id == $n) | .class]'
# expected: ["sta-test-1","sta-test-2","sta-test-3"] (any order)
```

En el panel, con esas tres ventanas en pantalla:
1. En Tarjetas, `n` abre el constructor. Mirar que las miniaturas se vean y que las tres digan su nombre. Arrastrar `sta-test-1` al Frente, y con `j`/`k` + `r` mandar `sta-test-2` al Reverso. Nombre: `Prueba`. **Crear tarjeta**. Expected: se arma la tarjeta y el panel vuelve con "Tarjeta creada." (o "Card created.").
2. `e` sobre la tarjeta, después `e` en el constructor (Elegir en pantalla). Clic en `sta-test-3` con el Reverso activo (`Tab`) y `Enter`. **Guardar cambios**. Expected: el Reverso tiene dos ventanas.
3. `v` voltea la tarjeta: se ve el Reverso.

Después, en la terminal (sobre el workspace `$N`):

```bash
"$R/bin/save-them-all"
jq '.cards' "$SAVE_THEM_ALL_STATE/workspace-$N.json"
# expected: one card named "Prueba", faces [[i], [j, k]], visible 1
```

4. En el panel, `d` desarma la tarjeta. Expected: las tres ventanas quedan en mosaico.

```bash
"$R/bin/restore-them-all"
python3 ~/.local/lib/hyprflip/control.py snapshot | jq --argjson n "$N" '[.cards[] | select(.workspace == $n) | [.faces[].panes | length]]'
# expected: [[1, 2]]: the card is back, with the Back on show
"$R/bin/restore-them-all"
# expected: same answer, nothing duplicated
```

5. Restaurar sin Hyprflip, sin descargar el plugin (tiene las tarjetas del usuario). Se simula con un helper que no existe, y restaurar tiene que agrupar. Antes, en el panel, `d` desarma otra vez la tarjeta de prueba:

```bash
SAVE_THEM_ALL_HYPRFLIP_HELPER=/nonexistent "$R/bin/restore-them-all"
hyprctl -j clients | jq --argjson n "$N" '[.[] | select(.workspace.id == $n) | {class, grouped: (.grouped | length), hidden}]'
# expected: the three sta-test windows grouped (grouped: 3), one of the Back's shown
"$R/bin/cards" ungroup --workspace "$N"
# expected: {"released": …}; the three windows tiled again
```

Cierre (siempre, aunque algo haya fallado):

```bash
for i in 1 2 3; do
  a=$(hyprctl -j clients | jq -r --arg c "sta-test-$i" '.[] | select(.class == $c) | .address')
  [[ -n $a ]] && hyprctl dispatch "hl.dsp.window.close({ window = 'address:$a' })"
done
hyprctl dispatch "hl.dsp.focus({ workspace = '$home_ws' })"
ls ~/.local/state/save-them-all/ | diff /tmp/sta-before.txt - && echo "user state untouched"
rm -rf "$SAVE_THEM_ALL_STATE" /tmp/sta-before.txt
unset SAVE_THEM_ALL_STATE
```

Expected: ninguna ventana `sta-test-*` abierta, la vista de vuelta en el workspace donde estaba, y "user state untouched".

Si un paso falla, arreglarlo con su test (TDD, en la tarea que corresponda) antes de seguir. Anotar en la entrega lo que no se pudo probar en vivo: la posición final de la tarjeta la decide Hyprflip, y si no hubo OK en el Step 7, crear y desarmar tarjetas desde el panel quedan sin probar.

(Sin push, sin tag y sin publicar: eso espera el OK del usuario.)

---

## Self-review

**Cobertura del spec:**

| Spec | Dónde |
|---|---|
| §1 criterios: crear una tarjeta de 3 apps en una pantalla; miniatura, nombre e ícono; gemelos; guardar, cerrar y restaurar con tarjetas; sin Hyprflip nada escondido | Tasks 13 y 16 (constructor y pick), 2 y 12 (`AppNames`, `twinWords`), 5, 8 y 9 (guardar y restaurar), 7 y 11 (fallback y "Mostrar las dos caras") |
| §2 Hyprflip opcional | Global Constraints, Task 4 (`status`) y Task 9 (sin tarjetas no se llama a `bin/cards`) |
| §2 todo lo de OmaCards | Task 14 (voltear, editar, desarmar, desplegar, flotar), Task 15 (apariencia, espaciado, animación, atajos con conflictos, arrastrar para sumar) y Task 16 |
| §2 idioma | Tasks 3, 10 y 15 |
| §3 arquitectura y §3.1 detección | Task 4 (`status`), Task 10 (`Hyprflip.qml`) y Task 11 (aviso de la pestaña Workspace) |
| §4.1 formato | Tasks 4 y 5; `read_file` invalida el bloque entero (Review Focus 2) |
| §4.2 guardar y conservar sin Hyprflip | Task 5 (`capture`, `preserve` y los miembros ocultos) |
| §4.3 restaurar y reglas comunes | Tasks 7, 8 y 9 |
| §4.4 Hyprflip roto con tarjetas armadas | Task 7 (`ungroup`) y Task 11 |
| §5 `create` con caras en el fork | Task 6 |
| §6.1 pestañas | Tasks 11, 14 y 15 |
| §6.2 constructor | Tasks 12 y 13 (la posición de los gemelos, los motivos, hasta 5 por cara y el aviso de ventanas de otro workspace) |
| §6.3 elegir en pantalla | Tasks 12 y 16 |
| §6.4 nombres | Tasks 2 y 4 (`test_names_match_appnames_js`) |
| §7 idioma y cobertura | Task 3 y los Steps de traducciones de cada tarea |
| §8 errores | Tasks 8 y 9 (`restore.log` y la notificación) y Task 13 (el constructor conserva el borrador si falla) |
| §9 pruebas | Tests por tarea, render (Task 11) y prueba en vivo (Task 17) |
| §11 entrega | Task 17 |

**Placeholders:** ningún "TBD", "TODO", "similar a" ni "agregar manejo de errores". Cada paso de código trae el código completo o el reemplazo exacto.

**Consistencia de tipos:**
- `draft`: tiene la misma forma en `Builder.js`, `Service.qml`, `render-steps.js` y `Pick.js`.
- `flip.run(action, extra, {workspace, card, replace, reopen})`: la usan `submitDraft`, `cardAction` y `setOption`, y `card`/`replace` son `{kind, id, faces}`, que es lo que produce `CardsModel.reference`.
- El pedido `create`: `faces` con `address:`, `axes` `row`/`column`, `ratios` null o por cara, `visible` y `floating` `{at, size}`. Es la misma forma en `bin/cards rebuild`, en `Builder.request` y en `full_card` del fork.
- `names`: van del id de contenedor (string) al nombre, en `bin/cards` y en `Service.qml`.
- Las páginas usan del `host` solo lo que `Panel.qml` y `FakeHost.qml` tienen en común.

**Review Focus → tests:**
1. `test_closed_window_is_rejected_before_any_mutation` (Task 6) y `prune removes closed windows and says which` (Task 12).
2. `test_invalid_cards_block_is_ignored` (Task 4) y `test_restore_with_invalid_cards_still_restores_windows` (Task 9).
3. `test_second_rebuild_keeps_the_card` (Task 8), `test_fallback_leaves_an_existing_group_alone` (Task 7) y `test_second_restore_leaves_cards_alone` (Task 9).
4. `test_hung_helper_is_killed_and_noted` (Task 8) y `test_restore_survives_failing_cards` (Task 9).
5. `test_hidden_members_saved_without_hyprflip` (Task 5), `test_fallback_groups_every_member` (Task 7) y `test_ungroup_releases_every_group` (Task 7).
