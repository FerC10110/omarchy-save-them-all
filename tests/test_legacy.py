"""What 1.3.0 already does, pinned down before 2.0 changes the scripts. With no
cards anywhere, all of this must stay exactly the same."""
import json

from scripttest import ScriptTest, client, saved_window

TERMINAL = {'kind': 'terminal'}
CALC = {'kind': 'app', 'desktop': 'org.gnome.Calculator.desktop'}


class LegacySaveTest(ScriptTest):
    def test_save_writes_windows_in_screen_order(self):
        self.hypr_state(clients=[
            client('0x2', 'org.gnome.Calculator', at=(960, 0), size=(960, 1080)),
            client('0x1', 'kitty', at=(0, 0), size=(960, 1080), tags=['terminal']),
        ])
        r = self.run_script('save-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        saved = self.saved(3)
        self.assertEqual([w['class'] for w in saved['windows']], ['kitty', 'org.gnome.Calculator'])
        self.assertEqual(saved['windows'][0]['launch'], TERMINAL)
        self.assertEqual(saved['windows'][1]['launch'], CALC)
        self.assertEqual(saved['windows'][1]['at'], [960, 0])
        self.assertNotIn('cards', saved)
        self.assertFalse(saved['autostart'])
        self.assertEqual(self.notifications()[-1][0], 'Saved 2 windows from workspace 3')

    def test_saving_again_keeps_autostart(self):
        self.write_saved(3, [saved_window('kitty', (0, 0), (10, 10), TERMINAL)], autostart=True)
        self.hypr_state(clients=[client('0x1', 'kitty', tags=['terminal'])])
        self.assertEqual(self.run_script('save-them-all', '--quiet').returncode, 0)
        self.assertTrue(self.saved(3)['autostart'])
        self.assertEqual(self.notifications(), [])

    def test_hidden_windows_are_not_saved(self):
        self.hypr_state(clients=[client('0x1', 'kitty', tags=['terminal']),
                                 client('0x2', 'org.gnome.Calculator', hidden=True)])
        self.assertEqual(self.run_script('save-them-all').returncode, 0)
        self.assertEqual([w['class'] for w in self.saved(3)['windows']], ['kitty'])

    def test_nothing_to_save(self):
        r = self.run_script('save-them-all')
        self.assertEqual(r.returncode, 1)
        self.assertEqual(self.notifications()[-1], ['Nothing to save', 'No windows on workspace 3'])


class LegacyRestoreTest(ScriptTest):
    def two_windows(self):
        self.write_saved(3, [saved_window('kitty', (0, 0), (960, 1080), TERMINAL),
                             saved_window('org.gnome.Calculator', (960, 0), (960, 1080), CALC)])
        self.hypr_state(clients=[client('0x1', 'kitty', at=(0, 0), size=(500, 500)),
                                 client('0x2', 'org.gnome.Calculator', at=(500, 0), size=(500, 500))])

    def test_restore_rebuilds_the_tree_and_the_sizes(self):
        self.two_windows()
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)
        d = self.dispatches()
        park = "hl.dsp.window.move({ window = 'address:%s', workspace = 'special:savethemall', follow = false })"
        self.assertIn(park % '0x1', d)
        self.assertIn(park % '0x2', d)
        self.assertIn("hl.dsp.layout('preselect r')", d)
        sizes = {a: c['size'] for a, c in self.clients_by_address().items()}
        self.assertEqual(sizes, {'0x1': [960, 1080], '0x2': [960, 1080]})
        self.assertEqual(self.notifications()[-1], ['Windows restored on workspace 3', '0 opened, 2 already there'])
        self.assertEqual(self.launches(), [])

    def test_a_window_without_launcher_is_reported_missing(self):
        self.write_saved(3, [saved_window('kitty', (0, 0), (960, 1080), TERMINAL),
                             saved_window('ghostapp', (960, 0), (960, 1080), None)])
        self.hypr_state(clients=[client('0x1', 'kitty')])
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 1)
        self.assertEqual(self.notifications()[-1], ['Windows: 1 missing', 'ghostapp (no launcher)'])
        self.assertEqual(self.launches(), [])

    def test_a_missing_app_is_launched_through_setsid(self):
        self.write_saved(3, [saved_window('org.gnome.Calculator', (0, 0), (960, 1080), CALC)])
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 1)   # the fake launcher opens nothing, so it never appears
        self.assertEqual(self.launches(), [['uwsm-app', '--', 'org.gnome.Calculator.desktop']])

    def test_a_file_from_1_2_with_cmd_still_restores(self):
        path = self.state_dir / 'workspace-3.json'
        path.write_text(json.dumps({'workspace': 3, 'windows': [
            {'class': 'kitty', 'cmd': 'omarchy-launch-terminal', 'at': [0, 0], 'size': [960, 1080]}]}))
        self.hypr_state(clients=[client('0x1', 'kitty', size=(500, 500))])
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_nothing_saved(self):
        r = self.run_script('restore-them-all')
        self.assertEqual(r.returncode, 1)
        self.assertEqual(self.notifications()[-1], ['Nothing saved for workspace 3', "Run 'Save them all' first"])


class LegacyLoginTest(ScriptTest):
    def test_list_reports_every_saved_workspace(self):
        self.write_saved(3, [saved_window('kitty', (0, 0), (10, 10), TERMINAL)], autostart=True)
        self.write_saved(1, [saved_window('kitty', (0, 0), (10, 10), TERMINAL)] * 2)
        r = self.run_script('restore-them-all-at-login', '--list')
        rows = json.loads(r.stdout)
        self.assertEqual([(x['workspace'], x['windows'], x['autostart']) for x in rows], [(1, 2, False), (3, 1, True)])
