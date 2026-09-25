"""The scripts' messages: every msg in bin/ has its Spanish in
bin/messages.es.json, none is left over, the %N match, and msg picks the
language the way the panel does."""
import json
from pathlib import Path
import re
import subprocess

from scripttest import BIN, ScriptTest

TABLE = BIN / 'messages.es.json'
BASH = re.compile(r'\bmsg\s+"((?:[^"\\$]|\\.)*)"')
PYTHON = re.compile(r"\bmsg\(\s*'((?:[^'\\]|\\.)*)'")


def used():
    keys = {}
    for path in sorted(BIN.rglob('*')):
        if not path.is_file() or path.suffix == '.json':
            continue
        text = path.read_text(errors='replace')
        for m in BASH.finditer(text):
            keys[m[1].replace('\\"', '"')] = path.name
        for m in PYTHON.finditer(text):
            keys[m[1].replace("\\'", "'")] = path.name
    return keys


def marks(text):
    return sorted(set(re.findall(r'%\d+', text)))


class MessagesTest(ScriptTest):
    def test_every_message_has_a_translation(self):
        table = json.loads(TABLE.read_text())
        missing = [f'{f}: {k}' for k, f in used().items() if k not in table]
        self.assertEqual(missing, [])

    def test_every_translation_is_used(self):
        keys = used()
        self.assertEqual([k for k in json.loads(TABLE.read_text()) if k not in keys], [])

    def test_translations_keep_their_placeholders(self):
        for key, value in json.loads(TABLE.read_text()).items():
            self.assertEqual(marks(value), marks(key), key)

    def msg(self, *args, **env):
        script = f'source "{BIN}/lib/i18n.sh"; msg "$@"'
        run_env = {**self.env, **env}
        for k in [k for k, v in env.items() if v is None]:
            run_env.pop(k)
        return subprocess.run(['bash', '-c', script, 'msg', *args], env=run_env,
                              capture_output=True, text=True, check=True).stdout.rstrip('\n')

    def test_msg_translates_and_fills_in_one_pass(self):
        self.assertEqual(self.msg('Saved %1 windows from workspace %2', '3', '1', SAVE_THEM_ALL_LANG='es'),
                         'Se guardaron 3 ventanas del escritorio 1')
        self.assertEqual(self.msg('Saved %1 windows from workspace %2', '3', '1'),
                         'Saved 3 windows from workspace 1')
        self.assertEqual(self.msg('%1 opened, %2 already there', '%2', 'x'), '%2 opened, x already there')

    def test_language_comes_from_the_setting_then_the_system(self):
        (self.state_dir / 'settings.json').write_text('{"language": "es"}')
        self.assertEqual(self.msg('Nothing to save', SAVE_THEM_ALL_LANG=None), 'Nada para guardar')
        (self.state_dir / 'settings.json').write_text('{"language": "auto"}')
        self.assertEqual(self.msg('Nothing to save', SAVE_THEM_ALL_LANG=None, LANG='es_AR.UTF-8'), 'Nada para guardar')
        self.assertEqual(self.msg('Nothing to save', SAVE_THEM_ALL_LANG=None, LANG='en_US.UTF-8'), 'Nothing to save')
