#!/usr/bin/env python3
"""Verify an OpenNeko.app using isolated settings, history, and a local port.

This launches and terminates only the test process; existing OpenNeko instances
are preserved. CPU/startup values are smoke observations, not benchmark claims.
"""

import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import time
import urllib.error
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('app')
parser.add_argument('--output', required=True)
args = parser.parse_args()
output = Path(args.output).resolve()
output.mkdir(parents=True, exist_ok=True)
with socket.socket() as sock:
    sock.bind(('127.0.0.1', 0))
    port = sock.getsockname()[1]
settings = {
    'hasCompletedFirstLaunch': True, 'launchAtLoginEnabled': False,
    'agentProcessDetectionEnabled': False, 'soundEffectsEnabled': False,
    'neighborSettings': {'enabled': False, 'displayName': ''},
    'languageCode': 'en', 'selectedSkinID': 'black',
}
(output / 'settings.json').write_text(json.dumps(settings))
environment = dict(os.environ, OPENNEKO_PORT=str(port),
    OPENNEKO_SETTINGS_PATH=str(output / 'settings.json'),
    OPENNEKO_CHAT_HISTORY_PATH=str(output / 'chat-history.md'))
for name in ['OPENNEKO_SETTINGS_SNAPSHOT', 'OPENNEKO_OPEN_SETTINGS', 'OPENNEKO_DEBUG_SETTINGS_MUTATION']:
    environment.pop(name, None)

def request(path, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    headers = {'Content-Type': 'application/json'} if data else {}
    req = urllib.request.Request(f'http://127.0.0.1:{port}{path}', data=data, headers=headers)
    with urllib.request.urlopen(req, timeout=5) as response:
        return response.read()

def cpu_seconds(pid):
    raw = subprocess.check_output(['/bin/ps', '-p', str(pid), '-o', 'time='], text=True).strip()
    parts = raw.split(':')
    value = 0.0
    for part in parts:
        value = value * 60 + float(part)
    return value

result = {'checks': [], 'port': port}
log = (output / 'app.log').open('w')
started = time.perf_counter()
process = subprocess.Popen([str(Path(args.app) / 'Contents/MacOS/OpenNeko')], env=environment,
    stdout=log, stderr=subprocess.STDOUT)
try:
    for attempt in range(100):
        if process.poll() is not None:
            raise RuntimeError(f'app exited {process.returncode}; see {output / "app.log"}')
        try:
            assert request('/health') == b'openneko'
            break
        except (urllib.error.URLError, TimeoutError):
            time.sleep(0.1)
    else:
        raise RuntimeError('health endpoint not ready')
    result['startup_health_ms'] = round((time.perf_counter() - started) * 1000, 2)
    result['checks'].append('health')
    for state in ['coding', 'thinking', 'success', 'nap']:
        request('/state', {'state': state, 'source': 'performance-qa'})
        actual = json.loads(request('/anim'))['anim']
        assert actual == state, (state, actual)
        result['checks'].append(f'state:{state}')
    try:
        request('/state', {'state': 'invalid-state', 'source': 'performance-qa'})
        raise AssertionError('invalid state accepted')
    except urllib.error.HTTPError as error:
        assert error.code == 400, error.code
        result['checks'].append('invalid-state:400')
    png = request('/capture')
    assert png.startswith(b'\x89PNG\r\n\x1a\n') and len(png) > 500
    (output / 'cat.png').write_bytes(png)
    result['checks'].append('capture:png')
    # Measure the same fixed state; this is a smoke observation, not a benchmark claim.
    start_cpu = cpu_seconds(process.pid)
    start_wall = time.perf_counter()
    time.sleep(5)
    assert process.poll() is None, f'app exited during observation: {process.returncode}'
    result['resting_cpu_percent'] = round((cpu_seconds(process.pid) - start_cpu) / (time.perf_counter() - start_wall) * 100, 2)
    result['rss_mib'] = round(int(subprocess.check_output(['/bin/ps', '-p', str(process.pid), '-o', 'rss='], text=True)) / 1024, 2)
    before_keys = json.loads(request('/anim'))['keydownCount']
    request('/debug/typing', {})
    time.sleep(0.15)
    after_keys = json.loads(request('/anim'))['keydownCount']
    assert after_keys > before_keys, (before_keys, after_keys)
    result['checks'].append('typing:activity')
    drag = json.loads(request('/debug/drag', {}))
    assert drag['ok'], drag
    time.sleep(1.2)
    position = json.loads(request('/pos'))
    result['position_after_drag'] = position
    result['checks'].append('drag:completed')
    assert request('/health') == b'openneko'
    result['checks'].append('health:after-interactions')
finally:
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)
    log.close()
    (output / 'result.json').write_text(json.dumps(result, indent=2))
print(json.dumps(result, indent=2))
