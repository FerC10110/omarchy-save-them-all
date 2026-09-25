"""Saving a workspace saves its cards: from Hyprflip when it is there, kept from
the previous save when it is not."""
import json

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
