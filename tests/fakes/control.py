#!/usr/bin/env python3
"""A stand-in for Hyprflip's control.py helper (protocol 1).

FAKE_HELPER_STATE (JSON, optional) sets how it behaves:
  protocol (1), available (true), error (""), create_faces (true),
  outcome: "done" | "error" | "hang" | "garbage" (default "done"), message.
Every run request is appended to FAKE_LOG as {"helper": request}. A done
create adds the card to the fake Hyprland state, as Hyprflip would: one
container whose windows share one native group, the visible side's first
window shown."""
import json
import os
import sys
import time

AXES = {'row': 'horizontal', 'column': 'vertical'}


def config():
    try:
        with open(os.environ['FAKE_HELPER_STATE']) as f:
            return json.load(f)
    except (KeyError, OSError, ValueError):
        return {}


def load_hypr():
    with open(os.environ['FAKE_HYPR_STATE']) as f:
        return json.load(f)


def save_hypr(state):
    path = os.environ['FAKE_HYPR_STATE']
    with open(path + '.tmp', 'w') as f:
        json.dump(state, f)
    os.replace(path + '.tmp', path)


def send(kind, **payload):
    print(json.dumps({'type': kind, **payload}), flush=True)


def build(request):
    state = load_hypr()
    clients = {c['address']: c for c in state['clients']}
    faces = [[a.removeprefix('address:') for a in face] for face in request['faces']]
    members = [a for face in faces for a in face]
    if any(a not in clients for a in members):
        return 'Una de las apps elegidas se cerró.'
    flip = state['hyprflip']
    visible = request.get('visible', 0)
    current = faces[visible][0]
    floating = request.get('floating')
    flip['containers'].append({
        'id': max([c['id'] for c in flip['containers']], default=0) + 1,
        'faces': faces, 'current': current, 'active': visible, 'unfolded': False,
        'floating': floating is not None, 'native_group': True,
        'box': floating['at'] + floating['size'] if floating else [0, 0, 0, 0],
        'layouts': [{'axis': AXES[axis], 'focused': 0, 'ratios': ratios}
                    for axis, ratios in zip(request['axes'], request['ratios'])]})
    for a in members:
        clients[a]['grouped'] = list(members)
        clients[a]['hidden'] = a != current
    save_hypr(state)
    return ''


def main():
    cfg = config()
    if sys.argv[1] == 'snapshot':
        state = load_hypr()
        print(json.dumps({
            'protocol': cfg.get('protocol', 1), 'available': cfg.get('available', True),
            'error': cfg.get('error', ''),
            'context': {'instance': 'save-them-all-test', 'workspace': state.get('active_workspace'),
                        'anchor': None, 'anchor_label': None, 'anchor_token': None},
            'capabilities': {'create_faces': cfg.get('create_faces', True), 'unpair': True,
                             'containers': True, 'max_panes': 5},
            'cards': [], 'shortcuts': {'available': False, 'rows': [], 'occupied': []}}))
        return 0
    request = json.loads(sys.argv[sys.argv.index('--request') + 1])
    with open(os.environ['FAKE_LOG'], 'a') as f:
        f.write(json.dumps({'helper': request}) + '\n')
    send('handoff', id=1)
    line = sys.stdin.readline()
    if (json.loads(line) if line.strip() else {}).get('resume') != 1:
        send('cancelled', message='Cancelado.')
        return 0
    outcome = cfg.get('outcome', 'done')
    if outcome == 'hang':
        time.sleep(60)
    if outcome == 'garbage':
        print('this is not json', flush=True)
        return 3
    if outcome == 'error':
        send('error', message=cfg.get('message', 'Fake failure'))
        return 1
    problem = build(request) if request.get('action') == 'create' else ''
    if problem:
        send('error', message=problem)
        return 1
    send('done', message='')
    return 0


if __name__ == '__main__':
    sys.exit(main())
