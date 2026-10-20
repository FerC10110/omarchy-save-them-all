"""Restoring a workspace that is not on the dwindle layout (scrolling, master)
reopens its windows and leaves the tiles alone; and a restore that dies halfway
never leaves a window parked on the hidden workspace, and says so."""
import json
import signal
import subprocess
import time

from scripttest import BIN, ScriptTest, client, saved_window

TERMINAL = {'kind': 'terminal'}
CALC = {'kind': 'app', 'desktop': 'org.gnome.Calculator.desktop'}
OBSIDIAN = {'kind': 'app', 'desktop': 'obsidian.desktop'}
PARK = "hl.dsp.window.move({ window = 'address:%s', workspace = 'special:savethemall', follow = false })"
BACK = "hl.dsp.window.move({ window = 'address:%s', workspace = '3', follow = false })"
NOTE = 'The arrangement was not rebuilt: workspace 3 is on the %s layout, not dwindle'
CARD = {'name': 'Notes', 'faces': [{'windows': [1], 'axis': 'row', 'ratios': [1.0]},
                                   {'windows': [2], 'axis': 'row', 'ratios': [1.0]}],
        'visible': 0, 'floating': None}


class OtherLayoutTest(ScriptTest):
    def three_open_windows(self, layout, third_floating=False, **state):
        self.write_saved(3, [saved_window('kitty', (0, 0), (960, 1080), TERMINAL),
                             saved_window('org.gnome.Calculator', (960, 0), (960, 540), CALC),
                             saved_window('obsidian', (960, 540), (960, 540), OBSIDIAN, floating=third_floating)])
        self.hypr_state(layouts={'3': layout}, clients=[
            client('0x1', 'kitty', at=(0, 0), size=(500, 500)),
            client('0x2', 'org.gnome.Calculator', at=(500, 0), size=(500, 500)),
            client('0x3', 'obsidian', at=(1000, 0), size=(500, 500))], **state)

    def test_on_another_layout_nothing_is_parked_and_the_tiles_are_left_alone(self):
        for layout in ('scrolling', 'master'):
            with self.subTest(layout=layout):
                self.log_path.write_text('')
                self.three_open_windows(layout)
                r = self.run_script('restore-them-all')
                self.assertEqual(r.returncode, 0, r.stderr)
                d = self.dispatches()
                self.assertFalse([x for x in d if 'special:savethemall' in x or 'preselect' in x
                                  or x.startswith('hl.dsp.window.resize(')], d)
                self.assertEqual({a: c['size'] for a, c in self.clients_by_address().items()},
                                 {'0x1': [500, 500], '0x2': [500, 500], '0x3': [500, 500]})
                self.assertEqual({c['workspace']['id'] for c in self.clients_by_address().values()}, {3})
                self.assertEqual(self.notifications()[-1], ['Workspace 3 restored, not rearranged',
                                                            '0 opened, 3 already there\n' + NOTE % layout])
                self.assertIn(NOTE % layout, r.stderr)
                self.assertIn(layout, r.stdout)

    def test_the_layout_note_is_news_even_when_asked_for_quiet(self):
        self.three_open_windows('scrolling')
        r = self.run_script('restore-them-all', '--quiet')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.notifications()[-1][0], 'Workspace 3 restored, not rearranged')

    def test_on_another_layout_a_floating_window_is_still_placed(self):
        self.three_open_windows('scrolling', third_floating=True)
        r = self.run_script('restore-them-all', '--quiet')
        self.assertEqual(r.returncode, 0, r.stderr)
        d = self.dispatches()
        self.assertEqual([x for x in d if "'address:0x3'" in x], [
            "hl.dsp.window.float({ window = 'address:0x3', state = 'on' })",
            "hl.dsp.window.resize({ window = 'address:0x3', x = 960, y = 540, exact = true })",
            "hl.dsp.window.move({ window = 'address:0x3', x = 960, y = 540, exact = true })"])
        self.assertFalse([x for x in d if "'address:0x1'" in x or "'address:0x2'" in x], d)
        self.assertEqual(self.clients_by_address()['0x3']['at'], [960, 540])

    def test_on_dwindle_the_tree_is_rebuilt_as_before(self):
        self.three_open_windows('dwindle')
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        d = self.dispatches()
        self.assertIn(PARK % '0x1', d)
        self.assertIn("hl.dsp.layout('preselect r')", d)
        self.assertEqual(self.clients_by_address()['0x2']['size'], [960, 540])
        self.assertEqual(self.notifications()[-1], ['Windows restored on workspace 3', '0 opened, 3 already there'])

    def test_with_workspace_option_the_layout_of_the_target_counts(self):
        self.three_open_windows('scrolling', active_workspace=7)
        r = self.run_script('restore-them-all', '--workspace', '3')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse([x for x in self.dispatches() if 'special:savethemall' in x or 'preselect' in x])
        self.assertEqual(self.notifications()[-1][0], 'Workspace 3 restored, not rearranged')

    def test_at_login_the_layout_note_comes_before_the_login_notice(self):
        self.three_open_windows('scrolling')
        data = self.saved(3)
        data['autostart'] = True
        (self.state_dir / 'workspace-3.json').write_text(json.dumps(data))
        r = self.run_script('restore-them-all-at-login')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual([n[0] for n in self.notifications()],
                         ['Workspace 3 restored, not rearranged', 'Windows restored at login'])

    def test_without_hyprflip_cards_are_not_grouped_as_tabs_on_another_layout(self):
        # Tabs are built by putting each window next to the first with
        # preselect: on another layout the cards are left unbuilt, with one
        # note, and no window goes through the hidden workspace.
        self.write_saved(3, [saved_window('kitty', (0, 0), (960, 1080), TERMINAL),
                             saved_window('org.gnome.Calculator', (960, 0), (960, 1080), CALC),
                             saved_window('obsidian', (960, 0), (960, 1080), OBSIDIAN)], cards=[CARD])
        self.hypr_state(layouts={'3': 'scrolling'}, clients=[
            client('0x1', 'kitty', at=(0, 0), size=(600, 600)),
            client('0x2', 'org.gnome.Calculator', at=(600, 0), size=(600, 600)),
            client('0x3', 'obsidian', at=(1200, 0), size=(600, 600))])
        r = self.run_script('restore-them-all', '--quiet')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse([x for x in self.dispatches()
                          if 'special:savethemall' in x or 'preselect' in x or 'group' in x], self.dispatches())
        self.assertEqual(self.clients_by_address()['0x3']['grouped'], [])
        title, body = self.notifications()[-1]
        self.assertEqual(title, 'Workspace 3 restored, not rearranged')
        self.assertIn(NOTE % 'scrolling', body)
        self.assertIn('Cards were not grouped as tabs: workspace 3 is on the scrolling layout, not dwindle', body)
        self.assertEqual(body.count('Cards were not grouped'), 1)

    def test_an_empty_layout_name_is_taken_as_dwindle(self):
        self.three_open_windows('')
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn(PARK % '0x1', self.dispatches())
        self.assertEqual(self.notifications()[-1][0], 'Windows restored on workspace 3')

    def test_a_hyprland_that_does_not_tell_the_layout_is_taken_as_dwindle(self):
        # Before per-workspace layouts, activeworkspace had no tiledLayout: the
        # tree is rebuilt the way it always was.
        self.three_open_windows('dwindle', layout_field=False)
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn(PARK % '0x1', self.dispatches())
        self.assertEqual(self.notifications()[-1][0], 'Windows restored on workspace 3')


class StillParkedTest(ScriptTest):
    def test_a_window_saved_floating_but_tiled_now_comes_back_and_floats(self):
        # It is parked with every other tile, but the plan has no place for it
        # (it was saved floating): it must come back all the same, and float.
        self.write_saved(3, [saved_window('kitty', (0, 0), (960, 1080), TERMINAL),
                             saved_window('org.gnome.Calculator', (960, 0), (960, 1080), CALC),
                             saved_window('obsidian', (200, 100), (600, 400), OBSIDIAN, floating=True)])
        self.hypr_state(clients=[
            client('0x1', 'kitty', at=(0, 0), size=(500, 500)),
            client('0x2', 'org.gnome.Calculator', at=(500, 0), size=(500, 500)),
            client('0x3', 'obsidian', at=(1000, 0), size=(500, 500))])
        r = self.run_script('restore-them-all', '--quiet')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn(PARK % '0x3', self.dispatches())
        c = self.clients_by_address()['0x3']
        self.assertEqual((c['workspace']['id'], c['floating'], c['at'], c['size']), (3, True, [200, 100], [600, 400]))
        self.assertEqual(self.notifications(), [])


class LeftoversTest(ScriptTest):
    def test_windows_an_earlier_restore_left_hidden_come_back_and_count_as_open(self):
        # A restore that died before this version left windows on the hidden
        # workspace. They come back before anything else, so the saved kitty
        # is found open instead of being launched again.
        self.write_saved(3, [saved_window('kitty', (0, 0), (960, 1080), TERMINAL),
                             saved_window('org.gnome.Calculator', (960, 0), (960, 1080), CALC)])
        self.hypr_state(clients=[
            client('0x1', 'kitty', at=(0, 0), size=(500, 500), workspace={'id': -98, 'name': 'special:savethemall'}),
            client('0x2', 'org.gnome.Calculator', at=(500, 0), size=(500, 500))])
        r = self.run_script('restore-them-all', '--quiet')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.launches(), [])
        self.assertEqual(self.dispatches()[0], BACK % '0x1')
        c = self.clients_by_address()
        self.assertEqual({a: (w['workspace']['id'], w['size']) for a, w in c.items()},
                         {'0x1': (3, [960, 1080]), '0x2': (3, [960, 1080])})
        self.assertEqual(self.notifications()[-1], [
            'Windows restored on workspace 3',
            '0 opened, 2 already there\nWindows an earlier restore had left hidden were brought back: 1'])


class CutShortTest(ScriptTest):
    def four_tiles(self, **state):
        """Three saved windows, open, and a fourth that was never saved: all
        four are parked while the tree is rebuilt."""
        self.write_saved(3, [saved_window('kitty', (0, 0), (960, 1080), TERMINAL),
                             saved_window('org.gnome.Calculator', (960, 0), (960, 540), CALC),
                             saved_window('obsidian', (960, 540), (960, 540), OBSIDIAN)])
        self.hypr_state(clients=[
            client('0x1', 'kitty', at=(0, 0), size=(500, 500)),
            client('0x2', 'org.gnome.Calculator', at=(500, 0), size=(500, 500)),
            client('0x3', 'obsidian', at=(1000, 0), size=(500, 500)),
            client('0x4', 'foot', at=(1500, 0), size=(400, 500))], **state)

    def test_a_dispatch_that_fails_brings_every_parked_window_back(self):
        # The first preselect fails (as it does on a layout that has none):
        # the seed is already back, the other three are still parked.
        self.four_tiles(fail=['preselect'])
        r = self.run_script('restore-them-all')
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual({c['workspace']['id'] for c in self.clients_by_address().values()}, {3})
        d = self.dispatches()
        self.assertEqual(d.count("hl.dsp.layout('preselect r')") + d.count("hl.dsp.layout('preselect d')"), 1)
        title, body = self.notifications()[-1]
        self.assertEqual(title, 'Restoring workspace 3 was cut short')
        self.assertIn("Stopped at: hyprctl dispatch hl.dsp.layout('preselect ", body)
        self.assertIn('error: fake failure', body)
        self.assertIn('3 of 3 windows were brought back from the hidden workspace', body)
        log = (self.state_dir / 'restore.log').read_text()
        self.assertIn('Restoring workspace 3 was cut short', log)
        self.assertIn('3 of 3 windows were brought back from the hidden workspace', log)
        self.assertIn('error: fake failure', r.stderr)
        self.assertIn('3 of 3 windows were brought back from the hidden workspace', r.stderr)

    def test_hyprland_refusing_preselect_midway_is_rescued(self):
        # After the four parks, focus drifts to a workspace on scrolling: the
        # next preselect is refused the way Hyprland does (an error line,
        # exit status 7) and the three windows still parked are brought back.
        self.four_tiles(layouts={'5': 'scrolling'}, drift={'after': 4, 'to': 5})
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 7)
        self.assertEqual({c['workspace']['id'] for c in self.clients_by_address().values()}, {3})
        title, body = self.notifications()[-1]
        self.assertEqual(title, 'Restoring workspace 3 was cut short')
        self.assertIn('no such layoutmsg for scrolling', body)
        self.assertIn('3 of 3 windows were brought back from the hidden workspace', body)

    def test_a_signal_midway_brings_the_parked_windows_back(self):
        # SIGTERM right after the first preselect: bash finishes the unpark it
        # is in, then the trap exits 143 and the rescue brings back the rest.
        self.write_saved(3, [saved_window('kitty', (i * 200, 0), (200, 1080), TERMINAL) for i in range(8)])
        self.hypr_state(clients=[client(hex(i + 1), 'kitty', at=(i * 100, 0), size=(100, 1080)) for i in range(8)])
        proc = subprocess.Popen([str(BIN / 'restore-them-all')], env=self.env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        deadline = time.time() + 60
        while time.time() < deadline and not any('preselect' in d for d in self.dispatches()):
            time.sleep(0.05)
        proc.send_signal(signal.SIGTERM)
        _, err = proc.communicate(timeout=60)
        self.assertEqual(proc.returncode, 143, err)
        self.assertEqual({c['workspace']['id'] for c in self.clients_by_address().values()}, {3})
        title, body = self.notifications()[-1]
        self.assertEqual(title, 'Restoring workspace 3 was cut short')
        self.assertIn('Stopped at: SIGTERM', body)
        self.assertRegex(body, r'\b[1-7] of [1-7] windows were brought back from the hidden workspace')

    def test_a_rescue_that_cannot_move_windows_says_how_many_came_back(self):
        # Every move onto the workspace fails, the rescue's own ones included.
        self.four_tiles(fail=["workspace = '3', follow = false"])
        r = self.run_script('restore-them-all', '--quiet')
        self.assertNotEqual(r.returncode, 0)
        title, body = self.notifications()[-1]
        self.assertEqual(title, 'Restoring workspace 3 was cut short')
        self.assertIn('0 of 4 windows were brought back from the hidden workspace', body)
        self.assertIn('0 of 4 windows were brought back from the hidden workspace',
                      (self.state_dir / 'restore.log').read_text())

    def test_a_deliberate_failure_is_not_a_cut_short_restore(self):
        # A window that cannot be reopened ends the restore with its own
        # notification and exit status; nothing was parked, nothing is logged.
        self.write_saved(3, [saved_window('kitty', (0, 0), (960, 1080), TERMINAL),
                             saved_window('ghostapp', (960, 0), (960, 1080), None)])
        self.hypr_state(clients=[client('0x1', 'kitty', at=(0, 0), size=(500, 500))])
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 1)
        self.assertEqual([n[0] for n in self.notifications()], ['Windows: 1 missing'])
        self.assertFalse((self.state_dir / 'restore.log').exists())
