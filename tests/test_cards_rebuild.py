"""With Hyprflip, each saved card is built again with one `create` call to its
helper. A helper that fails or hangs never stops the rest."""
import json
import time

from scripttest import ScriptTest, client, container, flip, pair, saved_window

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

    def test_a_name_with_no_session_to_keep_it_is_noted(self):
        out = self.rebuild([dict(CARD, name='Trading')], env={'HYPRLAND_INSTANCE_SIGNATURE': ''})
        self.assertEqual(out['built'], 1)
        self.assertEqual(out['notes'], ['Card Trading was rebuilt, but its name could not be saved: '
                                        'there is no Hyprland session to keep it for'])

    def test_second_rebuild_keeps_the_card(self):
        self.rebuild()
        self.assertEqual(self.rebuild(), {'built': 0, 'kept': 1, 'notes': []})
        self.assertEqual(len(self.helper_requests()), 1)

    def test_a_live_native_pair_of_the_same_windows_is_kept(self):
        state = self.hypr()
        state['hyprflip']['pairs'] = [pair(9, '0x2', '0x3')]
        for c in state['clients'][1:3]:
            c['grouped'] = ['0x2', '0x3']
        state['clients'][2]['hidden'] = True
        self.hypr_state(**state)
        one = dict(CARD, faces=[{'windows': [1], 'axis': 'row', 'ratios': [1.0]},
                                {'windows': [2], 'axis': 'row', 'ratios': [1.0]}])
        self.assertEqual(self.rebuild([one]), {'built': 0, 'kept': 1, 'notes': []})
        self.assertEqual(self.helper_requests(), [])

    def test_a_saved_pair_is_built_once_and_then_kept(self):
        one = dict(CARD, faces=[{'windows': [1], 'axis': 'row', 'ratios': [1.0]},
                                {'windows': [2], 'axis': 'row', 'ratios': [1.0]}], visible=1)
        self.assertEqual(self.rebuild([one]), {'built': 1, 'kept': 0, 'notes': []})
        self.assertEqual(self.rebuild([one]), {'built': 0, 'kept': 1, 'notes': []})
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

    def test_a_helper_without_a_container_provider_falls_back_to_groups(self):
        # create_faces can be advertised true even with no container
        # provider at all (the fork's own quirk) -- containers=false must
        # gate the create path off on its own, same as create_faces=false.
        self.helper_config(containers=False)
        out = self.rebuild()
        self.assertEqual(out['built'], 1)
        self.assertTrue(out['notes'][0].startswith('Cards were grouped as tabs instead: '), out['notes'])
        self.assertEqual(self.helper_requests(), [])
        self.assertEqual(sorted(self.clients_by_address()['0x2']['grouped']), ['0x2', '0x3', '0x4'])

    def test_a_helper_on_another_protocol_falls_back_to_groups(self):
        self.helper_config(protocol=2)
        out = self.rebuild()
        self.assertEqual(out['built'], 1)
        self.assertTrue(out['notes'][0].startswith('Cards were grouped as tabs instead: '), out['notes'])
        self.assertEqual(self.helper_requests(), [])
        self.assertEqual(sorted(self.clients_by_address()['0x2']['grouped']), ['0x2', '0x3', '0x4'])

    def test_a_card_too_big_for_the_containers_falls_back_only_for_that_card(self):
        # container_max_panes = 1 (e.g. no container provider, just
        # create_faces + containers advertised true): CARD's back (2
        # windows) does not fit, but a plain 1-vs-1 card still does, in the
        # same rebuild call -- the gate is per card, not per file.
        self.helper_config(max_panes=1)
        state = self.hypr()
        state['clients'].append(client('0x5', 'firefox'))
        self.hypr_state(**state)
        windows = W + [saved_window('firefox', (0, 0), (480, 1080), None)]
        small = {'name': '', 'faces': [{'windows': [0], 'axis': 'row', 'ratios': [1.0]},
                                       {'windows': [4], 'axis': 'row', 'ratios': [1.0]}],
                'visible': 0, 'floating': None}
        path = self.write_saved(3, windows, cards=[CARD, small])
        out = self.cards_json('rebuild', '--file', str(path), '--addresses',
                              json.dumps(['0x1', '0x2', '0x3', '0x4', '0x5']))
        self.assertEqual(out['built'], 2)
        [request] = self.helper_requests()
        self.assertEqual(request['faces'], [['address:0x1'], ['address:0x5']])
        self.assertEqual(sorted(self.clients_by_address()['0x2']['grouped']), ['0x2', '0x3', '0x4'])

    def test_a_busy_address_missing_from_clients_does_not_crash(self):
        # 0x2 is a member of an existing (stale) container but has since
        # closed: absent from `clients()`. Finding it "busy" must not
        # KeyError trying to read its class for the note.
        state = self.hypr()
        state['hyprflip']['containers'] = [container(1, [['0x2'], ['0x9']])]
        state['clients'] = [c for c in state['clients'] if c['address'] != '0x2']
        self.hypr_state(**state)
        out = self.rebuild()
        self.assertEqual(out['built'], 0)
        self.assertTrue(out['notes'], out)
        self.assertEqual(self.helper_requests(), [])

    def test_a_naming_failure_does_not_stop_the_rebuild(self):
        # The card itself was built fine; only saving its name fails (e.g.
        # an unwritable runtime dir) -- that must not lose the build, nor
        # stop the next card in the same call.
        state = self.hypr()
        state['clients'].append(client('0x5', 'firefox'))
        self.hypr_state(**state)
        windows = W + [saved_window('firefox', (0, 0), (480, 1080), None)]
        second = {'name': '', 'faces': [{'windows': [0], 'axis': 'row', 'ratios': [1.0]},
                                        {'windows': [4], 'axis': 'row', 'ratios': [1.0]}],
                 'visible': 0, 'floating': None}
        path = self.write_saved(3, windows, cards=[dict(CARD, name='Trading'), second])
        blocked = self.tmp / 'blocked'
        blocked.write_text('not a directory')
        out = self.cards_json('rebuild', '--file', str(path), '--addresses',
                              json.dumps(['0x1', '0x2', '0x3', '0x4', '0x5']),
                              env={'SAVE_THEM_ALL_RUNTIME': str(blocked)})
        self.assertEqual(out['built'], 2)
        self.assertTrue(any('name could not be saved' in n for n in out['notes']), out['notes'])
