"""Restoring a workspace that is not on the dwindle layout (scrolling, master)
reopens its windows and leaves the tiles alone; and a restore that dies halfway
never leaves a window parked on the hidden workspace, and says so."""
from scripttest import ScriptTest, client, saved_window

TERMINAL = {'kind': 'terminal'}
CALC = {'kind': 'app', 'desktop': 'org.gnome.Calculator.desktop'}
OBSIDIAN = {'kind': 'app', 'desktop': 'obsidian.desktop'}
PARK = "hl.dsp.window.move({ window = 'address:%s', workspace = 'special:savethemall', follow = false })"
BACK = "hl.dsp.window.move({ window = 'address:%s', workspace = '3', follow = false })"
NOTE = 'The arrangement was not rebuilt: workspace 3 is on the %s layout, not dwindle'


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
                self.assertEqual(self.notifications()[-1], ['Windows reopened on workspace 3, not rearranged',
                                                            '0 opened, 3 already there\n' + NOTE % layout])
                self.assertIn(NOTE % layout, r.stderr)
                self.assertIn(layout, r.stdout)

    def test_the_layout_note_is_news_even_when_asked_for_quiet(self):
        self.three_open_windows('scrolling')
        r = self.run_script('restore-them-all', '--quiet')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.notifications()[-1][0], 'Windows reopened on workspace 3, not rearranged')

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
