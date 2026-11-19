#!/usr/bin/env python3
"""Disposable real Core API + PostgreSQL; fixture auth, loopback only, no .env.
Run with --check to stop after HTTP integration tests, or without it to serve.
"""
from pathlib import Path
import argparse, base64, hashlib, hmac, json, os, secrets, shlex, shutil
import signal, socket, subprocess, tempfile, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.request import Request, build_opener, ProxyHandler
from urllib.error import HTTPError
from urllib.parse import quote

HERE = Path(__file__).resolve().parent
BACKEND = HERE.parents[2] / 'core.api'
BIN = Path('/opt/homebrew/opt/postgresql@17/bin')
NODE = shutil.which('node')
USER_ID = '00000000-0000-4000-8000-000000000001'
EMAIL = 'local-test@example.invalid'
PASSWORD = 'Solo-local-2026!'
parser = argparse.ArgumentParser()
parser.add_argument('--check', action='store_true')
parser.add_argument('--demo-account', action='store_true',
    help='Use the demo email in the isolated fixture; keep the fictional local password')
args = parser.parse_args()
if args.demo_account:
    EMAIL = 'hello@rituo.io'
work = Path(tempfile.mkdtemp(prefix='rituo-local-stack-', dir='/tmp')).resolve()
data, sock, build = work/'data', work/'socket', work/'build'
sock.mkdir(mode=0o700)
env = {'PATH': '/opt/homebrew/bin:/usr/bin:/bin', 'HOME': os.environ['HOME'], 'LC_ALL': 'C'}
secret = secrets.token_hex(32)
refresh = secrets.token_urlsafe(32)
api = None
auth = None
started = False
opener = build_opener(ProxyHandler({}))

def run(command, **kwargs):
    return subprocess.run([str(x) for x in command], env=env, cwd=work,
        capture_output=True, text=True, check=True, **kwargs)

def sql(query):
    return run([BIN/'psql', '-X', '-h', sock, '-p', '55439', '-U', 'rituo_local_test',
        '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-A', '-t'], input=query).stdout.strip()

def token():
    encode = lambda value: base64.urlsafe_b64encode(json.dumps(value).encode()).decode().rstrip('=')
    body = encode({'alg':'HS256','typ':'JWT'}) + '.' + encode({
        'sub':USER_ID, 'sessionId':'00000000-0000-4000-8000-000000000002', 'email':EMAIL, 'status':'active',
        'exp':int(time.time()) + 3600})
    signature = base64.urlsafe_b64encode(hmac.new(secret.encode(), body.encode(), hashlib.sha256).digest()).decode().rstrip('=')
    return body + '.' + signature

class AuthFixture(BaseHTTPRequestHandler):
    def log_message(self, fmt, *values):
        print('Local auth:', fmt % values, flush=True)
    def do_GET(self): self.handle_request()
    def do_POST(self): self.handle_request()
    def handle_request(self):
        payload = json.loads(self.rfile.read(int(self.headers.get('Content-Length', '0'))) or '{}')
        user = dict(id=USER_ID, email=EMAIL, displayName='Prueba local', emailVerified=True, status='active')
        status, result = 404, {'message':'Unsupported local fixture endpoint'}
        if self.path == '/health':
            status, result = 200, {'status':'ok', 'service':'rituo-local-auth-fixture'}
        elif self.path == '/auth/email/login':
            status, result = 401, {'message':'Use the fictional local test account'}
            if payload.get('email') == EMAIL and payload.get('password') == PASSWORD:
                status, result = 200, dict(accessToken=token(), refreshToken=refresh, user=user)
        elif self.path == '/auth/refresh' and payload.get('refreshToken') == refresh:
            status, result = 200, dict(accessToken=token(), refreshToken=refresh)
        elif self.path == '/auth/me':
            received = self.headers.get('Authorization', '').removeprefix('Bearer ')
            parts = received.split('.')
            valid = len(parts) == 3 and hmac.compare_digest(parts[2], base64.urlsafe_b64encode(
                hmac.new(secret.encode(), '.'.join(parts[:2]).encode(), hashlib.sha256).digest()).decode().rstrip('='))
            status, result = (200, user) if valid else (401, {'message':'Invalid local token'})
        elif self.path == '/auth/logout':
            status, result = 200, {'ok':True}
        encoded = json.dumps(result).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

def request(path, payload=None, bearer=True):
    headers = {'Content-Type':'application/json'}
    if bearer: headers['Authorization'] = 'Bearer ' + token()
    req = Request('http://127.0.0.1:3000' + path,
        data=None if payload is None else json.dumps(payload).encode(), headers=headers)
    with opener.open(req, timeout=5) as response:
        return json.load(response)

def stop_signal(*_): raise KeyboardInterrupt()

try:
    # Never replace or kill an existing service on either requested port.
    for port in (3000, 3001):
        with socket.socket() as probe: probe.bind(('127.0.0.1', port))
    run([BIN/'initdb', '-D', data, '-U', 'rituo_local_test', '-A', 'trust', '--no-locale', '--encoding=UTF8'])
    run([BIN/'pg_ctl', '-D', data, '-l', work/'postgres.log', '-w', 'start', '-o',
         shlex.join(['-h', '', '-k', str(sock), '-p', '55439'])])
    started = True
    assert sql('SHOW listen_addresses;') == ''
    assert Path(sql('SHOW data_directory;')).resolve() == data
    sql((HERE/'schema.sql').read_text())
    sql((HERE/'nfc-schema.sql').read_text())
    if args.demo_account:
        sql("UPDATE users SET email='hello@rituo.io' WHERE id='00000000-0000-4000-8000-000000000001';")
    run([NODE, BACKEND/'node_modules/typescript/bin/tsc', '-p', BACKEND/'tsconfig.build.json',
         '--outDir', build, '--incremental', 'false'])
    # TypeScript root inference can produce either build/src or build.
    app_module = next(build.rglob('app/modules/app.module.js'))
    compiled = app_module.parents[2]
    shutil.copytree(BACKEND/'src/legal', compiled/'legal', dirs_exist_ok=True)
    api_env = dict(env, NODE_PATH=str(BACKEND/'node_modules'), LOCAL_BUILD=str(compiled),
        DOTENV_CONFIG_PATH=str(work/'absent.env'), NODE_ENV='test', PORT='3000',
        SERVICE_NAME='rituo-isolated-local-test', JWT_ACCESS_SECRET=secret,
        DATABASE_URL='postgresql://rituo_local_test@localhost/postgres?host=' + quote(str(sock), safe='') + '&port=55439',
        INTERNAL_ANALYTICS_API_KEY=secrets.token_hex(32), APP_REVIEW_ACCOUNT_EMAIL=EMAIL)
    log = open(work/'core.log', 'w')
    api = subprocess.Popen([NODE, str(HERE/'bootstrap.cjs')], cwd=work, env=api_env, stdout=log, stderr=log)
    deadline = time.monotonic() + 40
    while True:
        try:
            assert request('/health', bearer=False)['service'] == 'rituo-isolated-local-test'
            break
        except Exception:
            if api.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError((work/'core.log').read_text())
            time.sleep(.2)
    assert request('/health/db', bearer=False)['database'] == 'connected'
    auth = ThreadingHTTPServer(('127.0.0.1', 3001), AuthFixture)
    threading.Thread(target=auth.serve_forever, daemon=True).start()
    modes = request('/modes')
    ritual = request('/rituals', dict(title='Ritual local', icon='book.fill', durationMinutes=30,
        weekdays=[1,2,3,4,5], startTime='09:00', endTime='09:30', appCount=0, categoryCount=0, domainCount=0))
    checks = []
    for kind, identifier in [('modes', modes[0]['id']), ('rituals', ritual['id'])]:
        path = f'/{kind}/{identifier}/breaks'
        for duration in [1,2,3,5,10,15]:
            request(path, dict(breakCount=2, breakDurationMinutes=duration))
            assert request(path)['breakDurationMinutes'] == duration
        for duration in [0,16,1.5]:
            try: request(path, dict(breakCount=2, breakDurationMinutes=duration))
            except HTTPError as error: assert error.code == 400
            else: raise AssertionError('Invalid duration accepted')
        assert request(path)['breakDurationMinutes'] == 15
        checks.append(kind + ': HTTP save/read 1,2,3,5,10,15; rejects 0,16,1.5')
    result = dict(production_access=False, checks=checks, fixture_schema=True, fixture_auth=True)
    (HERE/'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2), flush=True)
    if not args.check:
        print(f'LOCAL READY: Core http://127.0.0.1:3000; auth http://127.0.0.1:3001\n'
              f'Fictional login: {EMAIL} / {PASSWORD}\nLogs: {work}/core.log\nCtrl-C stops and removes the temporary database.', flush=True)
        signal.signal(signal.SIGTERM, stop_signal)
        while api.poll() is None: time.sleep(1)
except KeyboardInterrupt:
    pass
except subprocess.CalledProcessError as error:
    raise RuntimeError(error.stdout + error.stderr) from error
except Exception:
    if (work/'core.log').exists():
        print((work/'core.log').read_text()[-7000:], flush=True)
    raise
finally:
    if auth: auth.shutdown(); auth.server_close()
    if api and api.poll() is None:
        api.terminate()
        try: api.wait(timeout=10)
        except subprocess.TimeoutExpired: api.kill(); api.wait()
    if started: run([BIN/'pg_ctl', '-D', data, '-w', 'stop', '-m', 'fast'])
    if not (data/'postmaster.pid').exists(): shutil.rmtree(work)
