"""bin/cards status, members, capture and name, with a fake Hyprland and a
fake Hyprflip helper."""
import json
from pathlib import Path
import subprocess

from scripttest import BIN, ROOT, ScriptTest, client, container, flip, pair, saved_window

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

    def test_members_of_the_workspace_native_pairs(self):
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip(pairs=[pair(5, '0x2', '0x3'), pair(6, '0x8', '0x9')]),
            clients=[client('0x2', 'a', grouped=['0x2', '0x3']),
                     client('0x3', 'b', hidden=True, grouped=['0x2', '0x3']),
                     client('0x8', 'c', ws=4, grouped=['0x8', '0x9']),
                     client('0x9', 'd', ws=4, hidden=True, grouped=['0x8', '0x9'])])
        self.assertEqual(self.cards_json('members', '--workspace', '3'), ['0x2', '0x3'])

    def test_a_window_titled_like_a_lua_error_does_not_break_hyprctl(self):
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip([container(1, [['0x2'], ['0x3']])]),
            clients=[client('0x2', 'a', title='Lua error in hyprland.lua - a'),
                     client('0x3', 'b', hidden=True)])
        self.assertEqual(self.cards_json('members', '--workspace', '3'), ['0x2', '0x3'])
        out = self.cards_json('capture', '--workspace', '3', '--addresses', json.dumps(['0x2', '0x3']))
        self.assertEqual(out['cards'][0]['faces'], [{'windows': [0], 'axis': 'row', 'ratios': [1.0]},
                                                     {'windows': [1], 'axis': 'row', 'ratios': [1.0]}])

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

    def test_a_floating_card_is_saved_without_its_border(self):
        # Hyprflip's box is the window plus its border; restoring puts the
        # saved place on the window itself, so the border must come off or
        # the card grows by twice the border on every save and restore.
        card = container(1, [['0x2'], ['0x3']], floating=True, box=(98, 118, 804, 604))
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip([card]), border_size=2,
                        clients=[client('0x2', 'a'), client('0x3', 'b')])
        out = self.cards_json('capture', '--workspace', '3', '--addresses', json.dumps(['0x2', '0x3']))
        self.assertEqual(out['cards'][0]['floating'], {'at': [100, 120], 'size': [800, 600]})

    def test_a_floating_native_pair_keeps_its_window_place_with_a_border(self):
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip(pairs=[pair(4, '0x2', '0x3')]), border_size=2,
                        clients=[client('0x2', 'a', at=(100, 120), size=(800, 600), floating=True,
                                        grouped=['0x2', '0x3']),
                                 client('0x3', 'b', floating=True, hidden=True, grouped=['0x2', '0x3'])])
        out = self.cards_json('capture', '--workspace', '3', '--addresses', json.dumps(['0x2', '0x3']))
        self.assertEqual(out['cards'][0]['floating'], {'at': [100, 120], 'size': [800, 600]})

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

    def test_a_native_pair_is_a_one_and_one_card(self):
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip(pairs=[pair(4, '0x2', '0x3', current='0x3')]),
                        clients=[client('0x2', 'a', hidden=True, grouped=['0x2', '0x3']),
                                 client('0x3', 'b', grouped=['0x2', '0x3'])])
        out = self.cards_json('capture', '--workspace', '3', '--addresses', json.dumps(['0x1', '0x3', '0x2']))
        self.assertEqual(out, {'cards': [{
            'name': '', 'faces': [{'windows': [2], 'axis': 'row', 'ratios': [1.0]},
                                  {'windows': [1], 'axis': 'row', 'ratios': [1.0]}],
            'visible': 1, 'floating': None}], 'notes': []})

    def test_a_floating_native_pair_keeps_its_place(self):
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip(pairs=[pair(4, '0x2', '0x3')]),
                        clients=[client('0x2', 'a', at=(100, 120), size=(800, 600), floating=True,
                                        grouped=['0x2', '0x3']),
                                 client('0x3', 'b', floating=True, hidden=True, grouped=['0x2', '0x3'])])
        out = self.cards_json('capture', '--workspace', '3', '--addresses', json.dumps(['0x2', '0x3']))
        self.assertEqual((out['cards'][0]['visible'], out['cards'][0]['floating']),
                         (0, {'at': [100, 120], 'size': [800, 600]}))

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
                n, cards, problem = self.cards_python(
                    "w, c, p = cards.read_file(__import__('pathlib').Path(sys.argv[2]))\n"
                    'print(json.dumps([len(w), c, p]))', path)
                self.assertEqual((n, cards), (2, []))
                self.assertTrue(problem.startswith('card 1 '), problem)
                if out is not None:
                    self.assertEqual(out, {'hide': [], 'slots': []})

    def test_two_cards_sharing_a_window(self):
        windows = [saved_window(c, (0, 0), (10, 10), None) for c in 'abc']
        path = self.write_saved(3, windows, cards=[{'faces': [{'windows': [0]}, {'windows': [1]}]},
                                                   {'faces': [{'windows': [2]}, {'windows': [1]}]}])
        cards, problem = self.cards_python(
            "print(json.dumps(cards.read_file(__import__('pathlib').Path(sys.argv[2]))[1:]))", path)
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
        py = self.cards_python('print(json.dumps([cards.app_name(c) for c in json.loads(sys.argv[2])]))',
                               json.dumps(classes))
        self.assertEqual(py, js)


class ErrorsTest(ScriptTest):
    def fails_in_one_line(self, r, text=''):
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertEqual(r.stdout, '')
        self.assertNotIn('Traceback', r.stderr)
        self.assertEqual(len(r.stderr.strip().splitlines()), 1, r.stderr)
        self.assertTrue(r.stderr.startswith('cards: '), r.stderr)
        self.assertIn(text, r.stderr)

    def test_invalid_arguments_are_one_line(self):
        self.fails_in_one_line(self.cards('members', '--workspace', 'x'), 'workspace number')
        self.fails_in_one_line(self.cards('members', '--workspace', '0'), 'workspace number')
        self.fails_in_one_line(self.cards('capture', '--workspace', '3', '--addresses', '["rm -rf"]'),
                               '--addresses')
        self.fails_in_one_line(self.cards('layout', '--file', 'x', '--addresses', '{}'), '--addresses')
        self.fails_in_one_line(self.cards('name', '--id', '-1', '--name', 'x'), 'card number')
        self.fails_in_one_line(self.cards('preserve', '--previous', 'x', '--windows', '{'), '--windows')
        r = self.cards('nonsense')
        self.assertEqual(r.returncode, 2)   # argparse's own usage error
        self.assertNotIn('Traceback', r.stderr)

    def test_an_unexpected_error_is_one_readable_line(self):
        # The runtime directory is a file: writing a card's name fails with an
        # OSError no command expects, which must not end in a traceback.
        blocked = self.tmp / 'blocked'
        blocked.write_text('not a directory')
        self.fails_in_one_line(self.cards('name', '--id', '7', '--name', 'x',
                                          env={'SAVE_THEM_ALL_RUNTIME': str(blocked)}))

    def test_a_timeout_that_is_not_a_number_falls_back_to_the_default(self):
        for var in ('SAVE_THEM_ALL_HELPER_TIMEOUT', 'SAVE_THEM_ALL_PAUSE'):
            with self.subTest(var=var):
                r = self.cards('status', env={var: 'soon'})
                self.assertEqual(r.returncode, 0, r.stderr)
                self.assertEqual(json.loads(r.stdout)['reason'], 'no-plugin')
        timeout, pause = self.cards_python('print(json.dumps([cards.HELPER_TIMEOUT, cards.PAUSE]))',
                                           env={'SAVE_THEM_ALL_HELPER_TIMEOUT': 'nan',
                                                'SAVE_THEM_ALL_PAUSE': '-1'})
        self.assertEqual((timeout, pause), (30, 0.25))
