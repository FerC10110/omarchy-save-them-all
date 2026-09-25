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
