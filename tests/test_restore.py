"""Restoring a workspace rebuilds its cards after the windows, and never lets
a card stop the windows from coming back."""
import os
import shutil
import subprocess

from scripttest import BIN, ScriptTest, client, flip, saved_window

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
        # A fourth, ungrouped window keeps the tree with more than one place
        # on the second restore too (with only the card's two windows, the
        # slot is excluded for being grouped and the lone survivor never
        # reaches the park/unpark loop at all, so it could not prove
        # anything about that loop). 0x2's size is changed between runs so
        # that, if the geometry step resized it again, that would be a real,
        # observable dispatch instead of a same-size no-op.
        fourth = saved_window('foot', (0, 600), (960, 480), TERMINAL)
        self.write_saved(3, WINDOWS + [fourth], cards=[CARD])
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip(), clients=[
            client('0x1', 'kitty', at=(0, 0), size=(600, 600)),
            client('0x2', 'org.gnome.Calculator', at=(600, 0), size=(600, 600)),
            client('0x3', 'obsidian', at=(1200, 0), size=(600, 600)),
            client('0x4', 'foot', at=(0, 600), size=(600, 600))])
        self.assertEqual(self.run_script('restore-them-all').returncode, 0)
        state = self.hypr()
        state['clients'] = [dict(c, size=[500, 500]) if c['address'] == '0x2' else c for c in state['clients']]
        self.hypr_state(**state)
        before = len(self.dispatches())
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        second = self.dispatches()[before:]
        self.assertEqual(len(self.helper_requests()), 1)
        # the fourth window proves the park/unpark loop actually ran again
        self.assertTrue([x for x in second if "'address:0x4'" in x], second)
        touched = [x for x in second if ("'address:0x2'" in x or "'address:0x3'" in x)
                   and not x.startswith('hl.dsp.focus(')]   # giving focus back is fine; moving/resizing is not
        self.assertEqual(touched, [])

    def test_two_windows_of_one_class_in_a_card_do_not_swap(self):
        # Both kitties of the card share its place; Hyprland lists windows in
        # an order that changes (focus raises a floating one). Between two
        # windows at one place the shown one comes first, on saving and on
        # restoring, so the card is found as it is and left alone.
        kitty = lambda a, **kw: client(a, 'kitty', at=(960, 0), size=(960, 1080), tags=['terminal'], **kw)
        live = [client('0x1', 'foot', at=(0, 0), size=(960, 1080), tags=['terminal']),
                kitty('0x2', grouped=['0x2', '0x3']), kitty('0x3', hidden=True, grouped=['0x2', '0x3'])]
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip([__import__('scripttest').container(
            1, [['0x2'], ['0x3']], box=(960, 0, 960, 1080))]), clients=live)
        self.assertEqual(self.run_script('save-them-all', '--quiet').returncode, 0)
        state = self.hypr()
        state['clients'] = [live[0], live[2], live[1]]   # 0x3 is listed before 0x2 now
        self.hypr_state(**state)
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.helper_requests(), [])
        self.assertIn('cards: 0 built, 1 already there', r.stdout)
        self.assertEqual(self.notifications()[-1][0], 'Windows restored on workspace 3')

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
        # 0x3 is a plain tile, not a card's other side: parked once, by the
        # tree step, and back on the workspace, in no group.
        self.assertEqual(self.dispatches().count(PARK % '0x3'), 1)
        self.assertEqual(self.clients_by_address()['0x3']['workspace']['id'], 3)
        self.assertEqual(self.clients_by_address()['0x3']['grouped'], [])

    def test_a_floating_slot_of_a_tiled_card_is_tiled_like_its_card(self):
        # Hand-edited: the card is not floating but its slot window says
        # floating. The card decides: the slot takes its place in the tree.
        windows = [dict(w, floating=(n == 1)) for n, w in enumerate(WINDOWS)]
        for with_flip in (True, False):
            with self.subTest(with_flip=with_flip):
                self.log_path.write_text('')
                self.write_saved(3, windows, cards=[CARD])
                self.hypr_state(plugins=['hyprflip'] if with_flip else [], hyprflip=flip() if with_flip else None,
                                clients=[client('0x1', 'kitty', at=(0, 0), size=(600, 600)),
                                         client('0x2', 'org.gnome.Calculator', at=(600, 0), size=(600, 600),
                                                floating=True),
                                         client('0x3', 'obsidian', at=(1200, 0), size=(600, 600))])
                r = self.run_script('restore-them-all', '--quiet')
                self.assertEqual(r.returncode, 0, r.stderr)
                d = self.dispatches()
                unfloat = "hl.dsp.window.float({ window = 'address:0x2', action = 'disable' })"
                self.assertIn(unfloat, d)
                self.assertLess(d.index(unfloat), d.index(PARK % '0x2'))
                self.assertIn("'address:0x2', workspace = '3'", ' '.join(d[d.index(PARK % '0x2'):]))
                self.assertNotIn("hl.dsp.window.float({ window = 'address:0x2', state = 'on' })", d)
                self.assertFalse(self.clients_by_address()['0x2']['floating'])
                self.assertEqual(self.clients_by_address()['0x2']['size'], [960, 1080])

    def test_missing_windows_and_card_notes_are_told_together(self):
        self.write_saved(3, WINDOWS + [saved_window('ghostapp', (0, 600), (960, 480), None)], cards=[{'faces': 'bad'}])
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip(), clients=[
            client('0x1', 'kitty', at=(0, 0), size=(600, 600)),
            client('0x2', 'org.gnome.Calculator', at=(600, 0), size=(600, 600)),
            client('0x3', 'obsidian', at=(1200, 0), size=(600, 600))])
        r = self.run_script('restore-them-all', '--quiet')
        self.assertEqual(r.returncode, 1)
        title, body = self.notifications()[-1]
        self.assertEqual(title, 'Windows: 1 missing, cards with notes')
        self.assertTrue(body.startswith('ghostapp (no launcher)\n'), body)
        self.assertIn('Cards in workspace-3.json were ignored: card 1 needs exactly two sides', body)
        self.assertIn('Cards in workspace-3.json were ignored: card 1 needs exactly two sides', r.stderr)

    def test_a_cards_value_that_is_not_a_list_is_ignored_with_a_note(self):
        for bad in ({}, 'x', 7):
            with self.subTest(cards=bad):
                self.log_path.write_text('')
                (self.state_dir / 'restore.log').unlink(missing_ok=True)
                self.fresh_session()
                data = self.saved(3)
                data['cards'] = bad
                (self.state_dir / 'workspace-3.json').write_text(__import__('json').dumps(data))
                r = self.run_script('restore-them-all', '--quiet')
                self.assertEqual(r.returncode, 0, r.stderr)
                self.assertEqual({a: c['size'] for a, c in self.clients_by_address().items()},
                                 {'0x1': [960, 1080], '0x2': [960, 1080], '0x3': [960, 1080]})
                title, body = self.notifications()[-1]
                self.assertEqual(title, 'Windows restored on workspace 3, cards with notes')
                self.assertIn('Cards in workspace-3.json were ignored: cards must be a list', body)
                self.assertIn('cards must be a list', (self.state_dir / 'restore.log').read_text())
                self.assertEqual(self.helper_requests(), [])

    def test_bin_cards_itself_failing_is_noted(self):
        # A copy of bin/ whose cards answers layout and status but fails at
        # rebuild and fallback, as a crash would.
        copy = self.tmp / 'bin'
        shutil.copytree(BIN, copy)
        (copy / 'cards').rename(copy / 'cards.real')
        (copy / 'cards').write_text('#!/bin/bash\n'
                                    'case $1 in rebuild|fallback) echo "cards: boom" >&2; exit 1 ;; esac\n'
                                    'exec "$(dirname "$0")/cards.real" "$@"\n')
        os.chmod(copy / 'cards', 0o755)
        for with_flip in (True, False):
            with self.subTest(with_flip=with_flip):
                self.log_path.write_text('')
                self.fresh_session(with_flip=with_flip)
                r = subprocess.run([str(copy / 'restore-them-all'), '--quiet'], env=self.env,
                                   capture_output=True, text=True, timeout=120)
                self.assertEqual(r.returncode, 0, r.stderr)
                log = self.state_dir / 'restore.log'
                title, body = self.notifications()[-1]
                self.assertEqual(title, 'Windows restored on workspace 3, cards with notes')
                self.assertIn(f'Cards were not rebuilt: see {log}', body)
                self.assertIn('cards: boom', log.read_text())
                self.assertEqual(self.clients_by_address()['0x3']['workspace']['id'], 3)

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

    def test_focus_back_does_not_flip_the_card_to_its_hidden_side(self):
        # The window focused before restoring is on the card's front, but the
        # card was saved showing its back: giving the focus back to it would
        # flip the card (Hyprflip, or a group's tab) to the wrong side.
        back = dict(CARD, visible=1)
        for with_flip in (True, False):
            with self.subTest(with_flip=with_flip):
                self.fresh_session(with_flip=with_flip, cards=(back,))
                state = self.hypr()
                state['active'] = '0x2'
                self.hypr_state(**state)
                r = self.run_script('restore-them-all', '--quiet')
                self.assertEqual(r.returncode, 0, r.stderr)
                self.assertNotEqual(self.dispatches()[-1], "hl.dsp.focus({ window = 'address:0x2' })")
                if not with_flip:
                    self.assertEqual(self.clients_by_address()['0x3']['hidden'], False)

    def test_focus_goes_back_to_a_window_outside_the_cards(self):
        self.fresh_session(cards=(dict(CARD, visible=1),))
        state = self.hypr()
        state['active'] = '0x1'
        self.hypr_state(**state)
        r = self.run_script('restore-them-all', '--quiet')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.dispatches()[-1], "hl.dsp.focus({ window = 'address:0x1' })")

    def test_cards_step_refocuses_the_saved_workspace_first(self):
        # bin/cards rebuild/fallback act on whatever workspace is active
        # right now (Hyprflip's own context, or active_workspace()); step 1
        # can take a while per window and a window's own workspace rule (or
        # the user) can switch away before step 3 runs. The fake drifts the
        # active workspace to another one right after the first dispatch
        # (well before the cards step), with no real concurrency needed.
        self.fresh_session()
        state = self.hypr()
        state['drift'] = {'after': 1, 'to': 9}
        self.hypr_state(**state)
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("hl.dsp.focus({ workspace = '3' })", self.dispatches())
        [request] = self.helper_requests()
        self.assertEqual(request['context']['workspace'], 3)

    def test_cards_step_is_skipped_when_the_workspace_will_not_focus(self):
        self.fresh_session()
        state = self.hypr()
        state['drift'] = {'after': 1, 'to': 9}
        state['refuse_focus'] = ['3']   # something keeps stealing focus back
        self.hypr_state(**state)
        r = self.run_script('restore-them-all', '--quiet')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.helper_requests(), [])
        self.assertEqual(self.clients_by_address()['0x2']['grouped'], [])   # no fallback group either
        title, body = self.notifications()[-1]
        self.assertEqual(title, 'Windows restored on workspace 3, cards with notes')
        self.assertIn('Cards were not rebuilt: workspace 3 would not stay focused', body)
        self.assertIn('Cards were not rebuilt: workspace 3 would not stay focused',
                      (self.state_dir / 'restore.log').read_text())
        # nothing stays hidden: the back came back to the tree
        self.assertEqual(self.clients_by_address()['0x3']['workspace']['id'], 3)

    def test_a_file_without_cards_never_calls_bin_cards(self):
        self.write_saved(3, WINDOWS[:2])
        self.hypr_state(plugins=['hyprflip'], hyprflip=flip(), clients=[
            client('0x1', 'kitty', size=(600, 600)), client('0x2', 'org.gnome.Calculator', at=(600, 0), size=(600, 600))])
        self.assertEqual(self.run_script('restore-them-all').returncode, 0)
        self.assertEqual(self.helper_requests(), [])
        self.assertFalse((self.state_dir / 'restore.log').exists())
