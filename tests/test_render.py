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
                       SAVE_THEM_ALL_RENDER_FIXTURE=str(FIXTURES / 'render.json'),
                       **({'SAVE_THEM_ALL_CAPTURE_DIR': os.environ['SAVE_THEM_ALL_CAPTURE_DIR']}
                          if os.environ.get('SAVE_THEM_ALL_CAPTURE_DIR') else {}))
            done = subprocess.run([QUICKSHELL, '-p', str(root), '--no-color'], env=env,
                                  capture_output=True, text=True, timeout=180)
        cls.returncode = done.returncode
        cls.log = done.stdout + done.stderr
        cls.pages, cls.calls, cls.state = {}, {}, {}
        for line in cls.log.splitlines():
            if 'RENDER_TEXTS ' in line:
                name, lang, texts = line.split('RENDER_TEXTS ', 1)[1].split(' ', 2)
                cls.pages[name] = (lang, json.loads(texts))
            elif 'RENDER_CALLS ' in line:
                name, calls = line.split('RENDER_CALLS ', 1)[1].split(' ', 1)
                cls.calls[name] = json.loads(calls)
            elif 'RENDER_STATE ' in line:
                name, state = line.split('RENDER_STATE ', 1)[1].split(' ', 1)
                cls.state[name] = json.loads(state)

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
            'workspace-unsettled-es': ['Escritorio 3'],
            'workspace-cards-notice-es': ['Algunas ventanas siguen en un grupo; probá de nuevo'],
            'workspace-ungrouped-es': ['Todas las ventanas de este escritorio salieron de su grupo.'],
            'builder-new-en': ['New card', 'Front', 'Back', 'Create card', 'Windows', 'kitty · left', 'Pick on screen'],
            'builder-edit-es': ['Editar tarjeta', 'Frente', 'Reverso', 'Guardar cambios', 'Cancelar'],
            'builder-notice-es': ['Una cara admite hasta 5 ventanas.', 'Nueva tarjeta', '＋ soltá acá', 'Escritorio 3 · 1 ventana'],
            'cards-en': ['Notes', 'Tiled', 'Front: Calculator', 'Back: Obsidian', 'Flip', 'New card'],
            'cards-es': ['v voltear', 'u desplegar', 'Mosaico', 'Frente: Calculator', 'Reverso: Obsidian', 'Voltear', 'Desarmar', 'Tarjeta creada.'],
            'cards-unavailable-es': ['Las tarjetas necesitan Hyprflip', 'El asistente de Hyprflip no está instalado'],
            'cards-unsettled-es': ['Revisando Hyprflip…'],
            'cards-snapshot-unavailable-es': ['Las tarjetas necesitan Hyprflip',
                                              'El asistente de Hyprflip dice: Hyprland no responde.'],
            'cards-snapshot-unavailable-en': ['Cards need Hyprflip',
                                              'The Hyprflip helper reports: Hyprland is not answering.'],
            'settings-unsettled-es': ['Idioma', 'Revisando Hyprflip…'],
            'cards-empty-en': ['No cards yet. Press n to make one.'],
            'cards-pair-keys-en': ['v flip', 'u unfold', 't float', 'n new'],
            'settings-en': ['Language', 'Automatic', 'Classic tabs', 'Flip', 'Normal', 'Keyboard shortcuts',
                            'Hyprflip 0.3.0 on Hyprland 0.56.2', 'Close the browser cleanly'],
            'settings-es': ['Idioma', 'Automático', 'Pestañas clásicas', 'Voltear', 'Atajos de teclado',
                            'Cerrar el navegador limpio'],
            'settings-unavailable-es': ['Hyprflip no está disponible', 'Hyprflip no cargó', 'Idioma'],
            'settings-custom-speed-en': ['Fast', 'Normal', 'Slow', 'Custom', '500 ms'],
            'shortcuts-es': ['Atajos de teclado', 'Voltear la tarjeta', 'Super+Ctrl+Alt+F'],
            'settings-failed-es': ['Hyprflip está ocupado; probá de nuevo en un momento.'],
            'shortcuts-busy-en': ['Working…'],
            'shortcuts-own-notice-en': ['Flip the card: Super+G'],
            'pick-es': ['Sumando a: Frente', '2 elegidas', 'Clic en una ventana', 'Reverso'],
        }
        for name, shown in expected.items():
            texts = self.pages[name][1]
            for text in shown:
                self.assertTrue(any(text in t for t in texts), f'{name}: {text!r} not in {texts}')

    def test_steps_ask_what_they_expect(self):
        # A step's `expect`: the service calls its `calls` made (every one,
        # in order) and the page properties it named in `state`.
        for step in self.steps:
            expect = step.get('expect')
            if not expect:
                continue
            if 'calls' in expect:
                self.assertEqual(self.calls[step['name']], expect['calls'], step['name'])
            if 'state' in expect:
                self.assertEqual(self.state[step['name']], expect['state'], step['name'])

    def test_pages_do_not_show_a_cards_paused_warning_without_a_verdict(self):
        # Hyprflip ok (workspace-es), no saved cards (workspace-empty-es), and
        # status ok but no snapshot yet (workspace-unsettled-es): none of them
        # has grounds to say cards are paused. Same reasoning on the Cards tab
        # itself (cards-unsettled-es): no verdict yet is not "Cards need
        # Hyprflip", just "Checking Hyprflip…".
        hidden = {
            'workspace-es': ['Tarjetas en pausa', 'Mostrar las dos caras'],
            'workspace-empty-es': ['Tarjetas en pausa', 'Mostrar las dos caras'],
            'workspace-unsettled-es': ['Tarjetas en pausa', 'Mostrar las dos caras'],
            'cards-unsettled-es': ['Las tarjetas necesitan Hyprflip'],
            'settings-unsettled-es': ['Hyprflip no está disponible', 'Apariencia de la tarjeta', 'Velocidad'],
            'workspace-card-notice-es': ['Tarjeta creada.'],
            'builder-notice-es': ['1 ventanas'],
            'settings-other-notices-es': ['Tarjeta creada.', 'Voltear la tarjeta: Super+G'],
            'shortcuts-own-notice-en': ['Card created.'],
            'cards-other-notices-en': ['Hyprflip is busy; try again in a moment.'],
        }
        for name, unshown in hidden.items():
            texts = self.pages[name][1]
            for text in unshown:
                self.assertFalse(any(text in t for t in texts), f'{name}: {text!r} found in {texts}')


CARDS_STUB = r'''#!/bin/sh
# bin/cards as the service harness needs it: status says Hyprflip is fine,
# name is logged, ungroup fails while ungroup-fails exists.
case "$1" in
  status) echo '{"available": true, "reason": "ok", "hyprflip": "0.3.0", "hyprland": "0.56.2"}' ;;
  name) shift; printf '%s\n' "$*" >> "$RENDER_HELPER_DIR/names.log" ;;
  ungroup)
    if [ -e "$RENDER_HELPER_DIR/ungroup-fails" ]; then
      echo "cards: Algunas ventanas siguen en un grupo; probá de nuevo" >&2
      exit 1
    fi ;;
esac
'''


@unittest.skipUnless(QUICKSHELL and SHELL.is_dir(), 'needs quickshell and the Omarchy shell')
class ServiceTest(unittest.TestCase):
    """Service.qml and Hyprflip.qml themselves, driven by the scenarios of
    tests/render-service.qml against tests/render-helper.py, a stub bin/cards
    and tests/fakes/hyprctl."""

    @classmethod
    def setUpClass(cls):
        with tempfile.TemporaryDirectory(prefix='save-them-all-service-') as directory:
            root = Path(directory)
            for name in ('Ui', 'Commons'):
                (root / name).symlink_to(SHELL / name)
            plugin = root / 'SaveThemAll'
            (plugin / 'bin').mkdir(parents=True)
            for source in [*ROOT.glob('*.qml'), *ROOT.glob('*.js')]:
                shutil.copy2(source, plugin / source.name)
            (plugin / 'bin' / 'cards').write_text(CARDS_STUB)
            (plugin / 'bin' / 'restore-them-all-at-login').write_text('#!/bin/sh\nexit 0\n')
            for stub in (plugin / 'bin').iterdir():
                stub.chmod(0o755)
            shutil.copy2(ROOT / 'tests/render-service.qml', root / 'shell.qml')
            helper = root / 'helper'
            helper.mkdir()
            shutil.copy2(ROOT / 'tests/render-helper.py', root / 'control.py')
            (helper / 'cards.json').write_text(json.dumps([{
                'id': 1, 'kind': 'container', 'key': 'container:1', 'token': 't1', 'current': '0x5', 'active': 0,
                'unfolded': False, 'floating': False, 'workspace': 3, 'name': '',
                'faces': [{'index': 0, 'axis': 'horizontal', 'panes': [{'address': '0x5', 'label': 'e'}]},
                          {'index': 1, 'axis': 'horizontal', 'panes': [{'address': '0x6', 'label': 'f'}]}]}]))
            hypr = root / 'hypr.json'
            hypr.write_text(json.dumps({'active_workspace': 3, 'clients': [
                {'address': f'0x{n}', 'class': f'app{n}', 'initialClass': f'app{n}', 'title': f'app{n}',
                 'at': [n * 100, 0], 'size': [100, 100], 'floating': False, 'workspace': {'id': 3, 'name': '3'},
                 'mapped': True, 'hidden': False, 'grouped': [], 'fullscreen': 0, 'pinned': False,
                 'focusHistoryID': n, 'monitor': 0} for n in range(1, 7)]}))
            for name in ('runtime', 'config', 'cache', 'state'):
                (root / name).mkdir(mode=0o700)
            env = {k: v for k, v in os.environ.items()
                   if k not in ('WAYLAND_DISPLAY', 'DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE')}
            env.update(PATH=f'{FAKES}:{os.environ["PATH"]}', XDG_RUNTIME_DIR=str(root / 'runtime'),
                       XDG_CONFIG_HOME=str(root / 'config'), XDG_CACHE_HOME=str(root / 'cache'),
                       HOME=str(root), SAVE_THEM_ALL_STATE=str(root / 'state'),
                       SAVE_THEM_ALL_RUNTIME=str(root / 'runtime' / 'save-them-all'),
                       SAVE_THEM_ALL_HYPRFLIP_HELPER=str(root / 'control.py'),
                       RENDER_HELPER_DIR=str(helper), FAKE_HYPR_STATE=str(hypr),
                       QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='', QT_QUICK_BACKEND='software',
                       LIBGL_ALWAYS_SOFTWARE='1', LANG='C.UTF-8', LC_ALL='', LC_MESSAGES='')
            # Workspace switches go to hyprctl: never the real one.
            assert shutil.which('hyprctl', path=env['PATH']) == str(FAKES / 'hyprctl')
            try:
                done = subprocess.run([QUICKSHELL, '-p', str(root), '--no-color'], env=env,
                                      capture_output=True, text=True, timeout=300)
                cls.returncode, cls.log = done.returncode, done.stdout + done.stderr
            except subprocess.TimeoutExpired as late:
                text = lambda b: b.decode(errors='replace') if isinstance(b, bytes) else (b or '')
                cls.returncode, cls.log = 'timeout', text(late.stdout) + text(late.stderr)
        if os.environ.get('SAVE_THEM_ALL_SERVICE_LOG'):
            Path(os.environ['SAVE_THEM_ALL_SERVICE_LOG']).write_text(cls.log)
        cls.results = {}
        for line in cls.log.splitlines():
            if 'SERVICE_RESULT ' in line:
                name, value = line.split('SERVICE_RESULT ', 1)[1].split(' ', 1)
                cls.results[name] = json.loads(value)

    def result(self, name):
        self.assertIn(name, self.results, self.log)
        return self.results[name]

    def test_every_scenario_runs_without_qml_errors(self):
        self.assertEqual(self.returncode, 0, self.log)
        self.assertIn('SERVICE_DONE', self.log)
        self.assertNotIn('SERVICE_STUCK', self.log)
        self.assertNotIn('SERVICE_STEP_FAILED', self.log)
        problems = [line for line in self.log.splitlines()
                    if any(p in line for p in PROBLEMS) and not any(a in line for a in ALLOWED)]
        self.assertEqual(problems, [])
        self.assertEqual(self.result('settle'), {'settled': True, 'available': True, 'cards': 1})

    def test_pick_on_screen(self):
        r = self.result('pick')
        # The overlay refused to come up: the builder is back, and says why.
        self.assertEqual(r['refused'], {'picking': False, 'builderNotice': 'Could not open pick on screen.',
                                        'revealed': 1, 'opened': True})
        # Picking: the panel steps aside, its notice waits for the way back.
        self.assertEqual(r['started'], {'picking': True, 'builderNotice': '', 'dismissed': 1,
                                        'faces': [['0x1'], ['0x2']]})
        # Enter: the picks (a click on a picked window takes it out) go back.
        self.assertEqual(r['applied'], {'picking': False, 'faces': [['0x1', '0x3'], ['0x4']],
                                        'builderNotice': '', 'revealed': 1})
        # Esc: the builder as it was, notice included.
        self.assertEqual(r['cancelled'], {'picking': False, 'faces': [['0x1', '0x3'], ['0x4']],
                                          'builderNotice': 'kept'})

    def test_a_refresh_that_closes_nothing_leaves_the_pick_alone(self):
        self.assertEqual(self.result('prune-quiet'), {'picking': True, 'changes': 0})

    def test_a_draft_alone_watches_nothing(self):
        self.assertEqual(self.result('watchers'), {'closed': False, 'pictures': False, 'open': True, 'picking': True,
                                                   'back': True, 'none': False})

    def test_a_handoff_lets_go_of_every_open_panel(self):
        r = self.result('multi-panel')
        self.assertTrue(r['started'])
        self.assertGreaterEqual(r['aDismissed'], 1)
        self.assertGreaterEqual(r['bDismissed'], 1)

    def test_helper_messages_follow_the_language(self):
        r = self.result('english')
        self.assertEqual(r['error'], {'busy': False, 'failed': True, 'notice': 'Wait for the flip to finish and try again.'})
        self.assertEqual(r['unknown'], {'busy': False, 'failed': False, 'notice': 'Algo que el asistente dice ahora.'})
        self.assertEqual(r['spanish'], {'busy': False, 'failed': False,
                                        'notice': 'Animación actualizada para todas las tarjetas.'})

    def test_each_page_gets_its_own_notice(self):
        r = self.result('notices')
        self.assertEqual(r['card'], {'cardsNotice': 'The card changed. Refresh the list before changing it.',
                                     'cardsFailed': True, 'optionUntouched': True})
        self.assertEqual(r['option'], {'cardsNotice': 'The card changed. Refresh the list before changing it.',
                                       'cardsFailed': True, 'optionNotice': 'Animation updated for every card.',
                                       'optionFailed': False, 'optionAction': 'duration'})

    def test_a_hung_helper_is_stopped(self):
        r = self.result('watchdog-operation')
        self.assertTrue(r['started'])
        stopped = r['stopped']
        self.assertEqual((stopped['busy'], stopped['failed']), (False, True))
        self.assertEqual(stopped['notice'], 'Hyprflip did not answer in time; the action was stopped.')
        self.assertLess(stopped['seconds'], 3)
        self.assertEqual(r['after'], {'busy': False, 'failed': False, 'notice': 'Animation updated for every card.'})

    def test_a_retry_after_the_watchdog_is_not_killed(self):
        r = self.result('watchdog-retry')
        self.assertTrue(r['started'])
        after = r['after']
        self.assertEqual((after['busy'], after['failed'], after['notice']),
                         (False, False, 'Animation updated for every card.'))
        self.assertGreater(after['seconds'], 3.5)

    def test_the_watchdog_lets_the_helper_wind_down(self):
        r = self.result('watchdog-grace')
        self.assertTrue(r['stopping'])
        self.assertEqual(r['refused'], {'optionNotice': 'Hyprflip is still stopping the last action; try again in a moment.',
                                        'optionFailed': True})
        signals = r['signals']
        self.assertEqual([what for _, what in signals], ['start', '{"cancel":true}', 'SIGTERM'])
        cancel, term = signals[1][0], signals[2][0]
        # {cancel} when the watchdog gives up; SIGTERM after stopGrace (1 s);
        # SIGKILL after killGrace (1.5 s) more.
        self.assertLess(abs(cancel - r['gaveUp']), 400)
        self.assertGreater(term - cancel, 800)
        self.assertGreater(r['gone'] - term, 1300)

    def test_a_partial_success_shows_the_helpers_warning(self):
        r = self.result('unplaced')
        self.assertEqual(r['create'], {'notice': 'Card created, but it could not go back where it was. Move it by hand.',
                                       'failed': False})
        self.assertEqual(r['unpair'], {
            'notice': 'Card taken apart. Its apps stay open, but they could not go back where they were.',
            'failed': False})

    def test_a_name_only_edit_of_a_card_gone_renames_nothing(self):
        self.assertEqual(self.result('name-only-gone'), {
            'editing': True, 'names': [], 'open': True, 'builderNotice': 'That card changed; look at it again.'})

    def test_a_hung_snapshot_is_stopped(self):
        r = self.result('watchdog-snapshot')
        self.assertTrue(r['started'])
        stopped = r['stopped']
        self.assertEqual((stopped['busy'], stopped['failed']), (False, True))
        self.assertEqual(stopped['notice'], 'Hyprflip did not answer in time; the action was stopped.')
        self.assertLess(stopped['seconds'], 3)
        self.assertEqual(r['after'], {'busy': False, 'failed': False, 'notice': 'Animation updated for every card.',
                                      'available': True})

    def test_a_helper_that_cannot_start_does_not_stay_busy(self):
        r = self.result('spawn-failure')
        self.assertTrue(r['started'])
        stopped = r['stopped']
        self.assertEqual((stopped['busy'], stopped['failed']), (False, True))
        self.assertEqual(stopped['notice'], 'Could not start the Hyprflip helper.')
        self.assertLess(stopped['seconds'], 3)
        self.assertEqual(r['after'], {'busy': False, 'failed': False, 'notice': 'Animation updated for every card.'})

    def test_a_run_that_cannot_start_does_not_stay_busy(self):
        r = self.result('spawn-failure-run')
        self.assertTrue(r['started'])
        stopped = r['stopped']
        self.assertEqual((stopped['busy'], stopped['failed']), (False, True))
        self.assertEqual(stopped['notice'], 'Could not start the Hyprflip helper.')
        # After the (slow) snapshot answered: it was the run that failed.
        self.assertGreaterEqual(stopped['seconds'], 0.45)
        self.assertLess(stopped['seconds'], 3)

    def test_a_helper_crash_logs_its_whole_stderr(self):
        r = self.result('crash')
        self.assertEqual(r['stopped'], {'busy': False, 'failed': True, 'notice': 'The Hyprflip helper stopped. Try again.'})
        self.assertIn('helper exit 3: BOOM-MARKER the helper fell over', self.log)

    def test_show_both_faces_says_how_it_went(self):
        r = self.result('ungroup')
        self.assertEqual(r['ok'], {'notice': 'Every window on this workspace is out of its group.', 'failed': False})
        self.assertEqual(r['failed'], {'notice': 'Algunas ventanas siguen en un grupo; probá de nuevo', 'failed': True})

    def test_a_new_card_gets_its_name_once_and_only_soon(self):
        r = self.result('names')
        self.assertEqual(r['made'], ['--id 2 --name Work'])
        # The second create's card never showed up in time; when the same
        # windows became a card later, it did not get "Late".
        self.assertEqual(r['late'], ['--id 2 --name Work'])

    def test_a_name_only_edit_renames_without_rebuilding(self):
        r = self.result('name-only')
        self.assertTrue(r['editing'])
        self.assertEqual(r['sent'], 0)
        self.assertEqual(r['names'], ['--id 2 --name Renamed'])
        self.assertEqual((r['draft'], r['notice'], r['page']), (None, 'Changes saved.', 'cards'))

    def test_fast_language_changes_end_on_the_last_one(self):
        r = self.result('language')
        self.assertEqual(r['history'], ['es', 'en', 'es', 'en'])
        self.assertEqual(r['file'].get('language'), 'en')
        self.assertEqual(r['now'], 'en')
