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


def container(cid, faces, current=None, active=0, floating=False, box=(960, 0, 960, 1080), layouts=None):
    """One card of `hyprctl hyprflip status`."""
    return {'id': cid, 'faces': faces, 'current': current or faces[active][0], 'active': active,
            'unfolded': False, 'floating': floating, 'box': list(box), 'native_group': True,
            'layouts': layouts or [{'axis': 'horizontal', 'focused': 0, 'ratios': [1 / len(f)] * len(f)}
                                   for f in faces]}


def pair(pid, front, back, current=None):
    """One native pair of `hyprctl hyprflip status` (Controller::status): two
    windows in a native Hyprland group, no layouts, no box."""
    return {'id': pid, 'front': front, 'back': back, 'current': current or front}


def flip(containers=(), pairs=()):
    """`hyprctl hyprflip status` of Hyprflip 0.3.0."""
    return {'version': '0.3.0', 'native_cards': True, 'container_provider': 'native',
            'container_max_panes': 5, 'floating_cards': True, 'workspace_protection': True,
            'transition': 'flip', 'transition_modes': ['flip', 'instant'], 'card_frame': False,
            'card_gap': -1, 'pairs': list(pairs), 'containers': list(containers)}


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

    def cards(self, *args, env=None):
        return subprocess.run([str(BIN / 'cards'), *args], env={**self.env, **(env or {})},
                              capture_output=True, text=True, timeout=60)

    def cards_json(self, *args, env=None):
        r = self.cards(*args, env=env)
        self.assertEqual(r.returncode, 0, r.stderr)
        return json.loads(r.stdout)
