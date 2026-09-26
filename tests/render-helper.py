#!/usr/bin/env python3
"""The Hyprflip helper (control.py, protocol 1) as the service harness
(tests/render-service.qml) needs it. RENDER_HELPER_DIR holds cards.json, the
cards `snapshot` lists, and the harness steers it with files there:
  snapshot-hang   `snapshot` never answers
  snapshot-slow   `snapshot` answers after half a second
  run-mode        what `run` does: done (default), done-no-card, hang (and
                  ignore SIGTERM), crash (stderr, exit 3), error:<message>,
                  say:<message> (done with that message)
Every run request is appended to requests.jsonl. Like the real helper, a run
hands the focus off once and waits for {"resume": 1}; it messages in Spanish.
The workspace is FAKE_HYPR_STATE's active_workspace (tests/fakes/hyprctl)."""
import json
import os
from pathlib import Path
import signal
import sys
import time

HERE = Path(os.environ['RENDER_HELPER_DIR'])
AXES = {'row': 'horizontal', 'column': 'vertical'}
DONE = {'create': 'Tarjeta creada.', 'unpair': 'Tarjeta desarmada. Sus apps siguen abiertas.',
        'transition': 'Animación actualizada para todas las tarjetas.',
        'duration': 'Animación actualizada para todas las tarjetas.',
        'appearance': 'Apariencia actualizada para todas las tarjetas.',
        'spacing': 'Espaciado entre apps actualizado para todas las tarjetas.'}


def read(name, default):
    try:
        return (HERE / name).read_text()
    except OSError:
        return default


def workspace():
    try:
        with open(os.environ['FAKE_HYPR_STATE']) as f:
            return json.load(f).get('active_workspace', 0)
    except (KeyError, OSError, ValueError):
        return 0


def send(kind, **payload):
    print(json.dumps({'type': kind, **payload}, ensure_ascii=False), flush=True)


def build(request):
    cards = [c for c in json.loads(read('cards.json', '[]'))
             if not request.get('replace') or c['id'] != request['replace']['id']]
    faces = [[a.removeprefix('address:') for a in face] for face in request['faces']]
    ratios = request.get('ratios') or [[1 / len(f)] * len(f) for f in faces]
    visible = request.get('visible', 0)
    number = max([c['id'] for c in json.loads(read('cards.json', '[]'))], default=0) + 1
    cards.append({'id': number, 'kind': 'container', 'key': f'container:{number}', 'token': f't{number}',
                  'current': faces[visible][0], 'active': visible, 'unfolded': False, 'floating': False,
                  'workspace': workspace(), 'name': '',
                  'faces': [{'index': i, 'axis': AXES[axis], 'ratios': r,
                             'panes': [{'address': a, 'label': a} for a in face]}
                            for i, (face, axis, r) in enumerate(zip(faces, request['axes'], ratios))]})
    (HERE / 'cards.json').write_text(json.dumps(cards))


def snapshot():
    if (HERE / 'snapshot-hang').exists():
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        time.sleep(120)
        return 0
    if (HERE / 'snapshot-slow').exists():
        time.sleep(0.5)
    print(json.dumps({
        'protocol': 1, 'available': True, 'error': '',
        'context': {'instance': 'render', 'workspace': workspace(), 'anchor': None,
                    'anchor_label': None, 'anchor_token': None},
        'capabilities': {'containers': True, 'max_panes': 5, 'create_faces': True, 'unpair': True,
                         'floating': True},
        'cards': json.loads(read('cards.json', '[]')), 'transition': 'flip',
        'transition_modes': ['flip', 'instant'], 'duration_ms': 420, 'appearance': None, 'card_gap': None,
        'shortcuts': {'available': False, 'rows': [], 'occupied': []}}, ensure_ascii=False))
    return 0


def run(request):
    with open(HERE / 'requests.jsonl', 'a') as f:
        f.write(json.dumps(request) + '\n')
    mode = read('run-mode', 'done').strip()
    if mode == 'hang':
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        time.sleep(120)
        return 0
    if mode == 'crash':
        sys.stderr.write('BOOM-MARKER the helper fell over\n')
        return 3
    send('handoff', id=1)
    try:
        answer = json.loads(sys.stdin.readline() or '{}')
    except ValueError:
        answer = {}
    if answer.get('resume') != 1:
        send('cancelled', message='Cancelado. Las apps ya abiertas no se cierran.')
        return 0
    if mode.startswith('error:'):
        send('error', message=mode[len('error:'):])
        return 1
    if mode.startswith('say:'):
        send('done', message=mode[len('say:'):])
        return 0
    action = request.get('action')
    if action == 'create' and mode != 'done-no-card':
        build(request)
    send('done', message='Tarjeta editada.' if action == 'create' and request.get('replace') else DONE.get(action, ''))
    return 0


if __name__ == '__main__':
    if sys.argv[1] == 'snapshot':
        raise SystemExit(snapshot())
    raise SystemExit(run(json.loads(sys.argv[sys.argv.index('--request') + 1])))
