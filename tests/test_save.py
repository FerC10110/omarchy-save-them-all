"""Saving a workspace saves its cards: from Hyprflip when it is there, kept from
the previous save when it is not."""
import json
import time

from scripttest import ScriptTest, client, container, flip, pair, saved_window

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

    def test_save_keeps_both_windows_of_a_native_pair_as_a_card(self):
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip(pairs=[pair(3, '0x2', '0x3')]), clients=[
            client('0x1', 'kitty', at=(0, 0), size=(960, 1080), tags=['terminal']),
            client('0x2', 'org.gnome.Calculator', at=(960, 0), size=(960, 1080), grouped=['0x2', '0x3']),
            client('0x3', 'obsidian', at=(960, 0), size=(960, 1080), hidden=True, grouped=['0x2', '0x3'])])
        r = self.run_script('save-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        saved = self.saved(3)
        self.assertEqual([w['class'] for w in saved['windows']], ['kitty', 'org.gnome.Calculator', 'obsidian'])
        self.assertEqual(saved['cards'], [{
            'name': '', 'faces': [{'windows': [1], 'axis': 'row', 'ratios': [1.0]},
                                  {'windows': [2], 'axis': 'row', 'ratios': [1.0]}],
            'visible': 0, 'floating': None}])

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

    def hidden_kitty_after_a_card_of(self, launch):
        windows = [saved_window('org.gnome.Calculator', (0, 0), (960, 1080), CALC),
                   saved_window('kitty', (0, 0), (960, 1080), launch)]
        self.write_saved(3, windows, cards=[{'faces': [{'windows': [0]}, {'windows': [1]}]}])
        self.hypr_state(clients=[   # no Hyprflip; the card is a native group
            client('0x2', 'org.gnome.Calculator', size=(960, 1080), grouped=['0x2', '0x3']),
            client('0x3', 'kitty', size=(960, 1080), hidden=True, grouped=['0x2', '0x3'], tags=['terminal'])])
        r = self.run_script('save-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        return [w['class'] for w in self.saved(3)['windows']]

    def test_without_hyprflip_a_hidden_member_matches_class_and_launcher(self):
        self.assertEqual(self.hidden_kitty_after_a_card_of(TERMINAL), ['org.gnome.Calculator', 'kitty'])
        # The card's kitty ran tmux; this hidden one is a plain terminal.
        self.assertEqual(self.hidden_kitty_after_a_card_of({'kind': 'terminal', 'session': 'tmux'}),
                         ['org.gnome.Calculator'])

    def test_without_hyprflip_or_a_previous_file_a_hidden_window_is_not_saved(self):
        self.hypr_state(clients=[
            client('0x2', 'org.gnome.Calculator', size=(960, 1080), grouped=['0x2', '0x3']),
            client('0x3', 'obsidian', size=(960, 1080), hidden=True, grouped=['0x2', '0x3'])])
        r = self.run_script('save-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual([w['class'] for w in self.saved(3)['windows']], ['org.gnome.Calculator'])
        self.assertNotIn('cards', self.saved(3))

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

    def hyprflip_stops_answering(self, clients):
        # status and members still get their answer; capture does not.
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip(), clients=clients)
        self.run_script('save-them-all', '--quiet', env={'SAVE_THEM_ALL_STATE': str(self.tmp / 'probe')})
        answers = self.queries().count('hyprflip status')
        self.log_path.write_text('')
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip(), clients=clients, hyprflip_answers=answers - 1)

    def test_hyprflip_not_answering_with_nothing_saved_before_says_nothing_was_kept(self):
        self.hyprflip_stops_answering([client('0x1', 'kitty', tags=['terminal'])])
        r = self.run_script('save-them-all', '--quiet')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn('cards', self.saved(3))
        self.assertNotIn('saved before were kept', r.stderr)
        self.assertEqual(self.notifications(), [])

    def test_hyprflip_not_answering_keeps_the_cards_saved_before(self):
        windows = [saved_window('kitty', (0, 0), (960, 1080), TERMINAL),
                   saved_window('org.gnome.Calculator', (960, 0), (960, 1080), CALC),
                   saved_window('obsidian', (960, 0), (960, 1080), OBSIDIAN)]
        card = {'name': '', 'faces': [{'windows': [1], 'axis': 'row', 'ratios': [1.0]},
                                      {'windows': [2], 'axis': 'row', 'ratios': [1.0]}],
                'visible': 0, 'floating': None}
        self.write_saved(3, windows, cards=[card])
        self.hyprflip_stops_answering([
            client('0x1', 'kitty', at=(0, 0), size=(960, 1080), tags=['terminal']),
            client('0x2', 'org.gnome.Calculator', at=(960, 0), size=(960, 1080)),
            client('0x3', 'obsidian', at=(1920, 0), size=(960, 1080))])
        r = self.run_script('save-them-all', '--quiet')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.saved(3)['cards'], [card])
        self.assertIn('Hyprflip did not answer; the cards saved before were kept', self.notifications()[-1][1])

    def test_a_broken_previous_file_is_quiet_under_quiet(self):
        windows = [saved_window('kitty', (0, 0), (960, 1080), TERMINAL)]
        self.write_saved(3, windows, cards=[{'faces': 'bad'}])
        self.hypr_state(clients=[client('0x1', 'kitty', tags=['terminal'])])
        r = self.run_script('save-them-all', '--quiet')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.notifications(), [])
        self.assertIn('The cards saved before were ignored: card 1 needs exactly two sides', r.stderr)
        self.assertIn('The cards saved before were ignored', (self.state_dir / 'restore.log').read_text())
        self.write_saved(3, windows, cards=[{'faces': 'bad'}])
        r = self.run_script('save-them-all')
        self.assertIn('The cards saved before were ignored: card 1 needs exactly two sides', self.notifications()[-1][1])

    def test_saving_without_hyprflip_never_asks_its_helper(self):
        self.hypr_state(clients=[client('0x1', 'kitty', tags=['terminal'])])
        self.assertEqual(self.run_script('save-them-all').returncode, 0)
        self.assertEqual(self.helper_snapshots(), 0)

    def test_saving_a_workspace_with_no_cards_never_asks_the_helper(self):
        # Every save used to wait on a helper snapshot (15 s when it hangs)
        # even with no card to save; Hyprflip's own status says there is none.
        self.helper_config(snapshot='hang')
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip([container(1, [['0x8'], ['0x9']])]), clients=[
            client('0x1', 'kitty', tags=['terminal']),
            client('0x8', 'a', ws=4), client('0x9', 'b', ws=4, hidden=True)])
        started = time.monotonic()
        r = self.run_script('save-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertLess(time.monotonic() - started, 10)
        self.assertEqual(self.helper_snapshots(), 0)
        self.assertEqual([w['class'] for w in self.saved(3)['windows']], ['kitty'])
        self.assertNotIn('cards', self.saved(3))

    def test_saving_a_workspace_with_cards_still_checks_the_helper(self):
        self.with_card([container(7, [['0x2'], ['0x3', '0x4']])])
        self.assertEqual(self.run_script('save-them-all').returncode, 0)
        self.assertEqual(self.helper_snapshots(), 1)
        self.assertEqual(len(self.saved(3)['cards']), 1)

    def test_login_list_counts_cards(self):
        card = {'faces': [{'windows': [0]}, {'windows': [1]}]}
        self.write_saved(3, [saved_window('a', (0, 0), (1, 1), None), saved_window('b', (1, 0), (1, 1), None)],
                         cards=[card])
        self.write_saved(4, [saved_window('a', (0, 0), (1, 1), None)])
        rows = json.loads(self.run_script('restore-them-all-at-login', '--list').stdout)
        self.assertEqual([(x['workspace'], x['cards']) for x in rows], [(3, 1), (4, 0)])
