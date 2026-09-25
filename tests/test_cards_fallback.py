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
