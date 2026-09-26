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
            'workspace-unsettled-es': ['Escritorio 3'],
            'workspace-cards-notice-es': ['Algunas ventanas siguen en un grupo; probá de nuevo'],
            'builder-new-en': ['New card', 'Front', 'Back', 'Create card', 'Windows', 'kitty · left', 'Pick on screen'],
            'builder-edit-es': ['Editar tarjeta', 'Frente', 'Reverso', 'Guardar cambios', 'Cancelar'],
            'builder-notice-es': ['Una cara admite hasta 5 ventanas.', 'Nueva tarjeta', '＋ soltá acá', 'Escritorio 3 · 1 ventana'],
            'cards-en': ['Notes', 'Tiled', 'Front: Calculator', 'Back: Obsidian', 'Flip', 'New card'],
            'cards-es': ['Mosaico', 'Frente: Calculator', 'Reverso: Obsidian', 'Voltear', 'Desarmar', 'Tarjeta creada.'],
            'cards-unavailable-es': ['Las tarjetas necesitan Hyprflip', 'El asistente de Hyprflip no está instalado'],
            'cards-unsettled-es': ['Revisando Hyprflip…'],
            'cards-empty-en': ['No cards yet. Press n to make one.'],
            'settings-en': ['Language', 'Automatic', 'Classic tabs', 'Flip', 'Normal', 'Keyboard shortcuts',
                            'Hyprflip 0.3.0 on Hyprland 0.56.2', 'Close the browser cleanly'],
            'settings-es': ['Idioma', 'Automático', 'Pestañas clásicas', 'Voltear', 'Atajos de teclado',
                            'Cerrar el navegador limpio'],
            'settings-unavailable-es': ['Hyprflip no está disponible', 'Hyprflip no cargó', 'Idioma'],
            'shortcuts-es': ['Atajos de teclado', 'Voltear la tarjeta', 'Super+Ctrl+Alt+F'],
            'settings-failed-es': ['Hyprflip está ocupado; probá de nuevo en un momento.'],
            'shortcuts-busy-en': ['Working…'],
            'pick-es': ['Sumando a: Frente', '2 elegidas', 'Clic en una ventana', 'Reverso'],
        }
        for name, shown in expected.items():
            texts = self.pages[name][1]
            for text in shown:
                self.assertTrue(any(text in t for t in texts), f'{name}: {text!r} not in {texts}')

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
            'workspace-card-notice-es': ['Tarjeta creada.'],
            'builder-notice-es': ['1 ventanas'],
        }
        for name, unshown in hidden.items():
            texts = self.pages[name][1]
            for text in unshown:
                self.assertFalse(any(text in t for t in texts), f'{name}: {text!r} found in {texts}')
