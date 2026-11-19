#!/usr/bin/env python3
"""Real PostgreSQL integration test. Creates its own cluster; cannot use production credentials.
No backend startup, .env files, existing database server, TCP or external services.
"""
from pathlib import Path
import json
import os
import re
import shlex
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT.parent / 'core.api'
BIN = Path('/opt/homebrew/opt/postgresql@17/bin')
MIGRATION = BACKEND / 'migrations/manual/20260923-break-duration'
ENV = {'PATH': str(BIN) + ':/usr/bin:/bin', 'LC_ALL': 'C', 'HOME': os.environ['HOME']}
work = Path(tempfile.mkdtemp(prefix='rituo-pg-isolated-', dir='/tmp')).resolve()
data = work / 'data'
socket = work / 'socket'
socket.mkdir(mode=0o700)
port = '55439'
started = False
holders = []
results = []

def run(args, **kwargs):
    return subprocess.run([str(x) for x in args], env=ENV, text=True, capture_output=True, **kwargs)

def psql_args():
    return [BIN/'psql', '-X', '-h', socket, '-p', port, '-U', 'rituo_local_test',
            '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-A', '-t']

def sql(query, success=True):
    result = run(psql_args(), input=query, timeout=40)
    if success and result.returncode:
        raise AssertionError(result.stderr)
    if not success and not result.returncode:
        raise AssertionError('Expected SQL rejection but the statement succeeded')
    return result.stdout.strip() if success else result.stderr

def baseline():
    # This connection always targets the newly created private socket/cluster.
    sql('DROP TABLE IF EXISTS ritual_breaks, mode_breaks, rituals, modes CASCADE;')
    sql('CREATE TABLE rituals(id uuid PRIMARY KEY); CREATE TABLE modes(id uuid PRIMARY KEY);')
    for kind in ['Ritual', 'Mode']:
        path = f'src/app/drivers/repositories/{kind.lower()}Breaks/SQL{kind}BreaksRepository.ts'
        original = run(['/usr/bin/git', '-C', BACKEND, 'show', 'HEAD:' + path], check=True).stdout
        schema = re.search(r'entityManager\.query\(`([\s\S]*?)`\)', original).group(1)
        assert 'break_duration_minutes between 1 and 5' in schema
        sql(schema)
    sql("""
      INSERT INTO rituals VALUES ('00000000-0000-0000-0000-000000000001');
      INSERT INTO modes VALUES ('00000000-0000-0000-0000-000000000002');
      INSERT INTO ritual_breaks(ritual_id,break_count,break_duration_minutes)
        VALUES ('00000000-0000-0000-0000-000000000001',2,5);
      INSERT INTO mode_breaks(mode_id,break_count,break_duration_minutes)
        VALUES ('00000000-0000-0000-0000-000000000002',1,1);
    """)

def rows():
    return sql("SELECT row_to_json(r)::text FROM ritual_breaks r UNION ALL SELECT row_to_json(m)::text FROM mode_breaks m;")

def hold(query):
    env = dict(ENV, PGAPPNAME='rituo_isolated_lock_holder')
    process = subprocess.Popen([str(x) for x in psql_args()] + ['-c', 'BEGIN; ' + query + '; SELECT pg_sleep(4); ROLLBACK;'],
        env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    holders.append(process)
    until = time.monotonic() + 3
    while time.monotonic() < until:
        ready = sql("SELECT count(*) FROM pg_stat_activity WHERE application_name='rituo_isolated_lock_holder' AND wait_event='PgSleep';")
        if ready == '1':
            return process
        if process.poll() is not None:
            raise AssertionError(process.communicate())
        time.sleep(0.03)
    raise AssertionError('Local lock holder did not initialize')

try:
    assert BIN.joinpath('initdb').is_file(), 'Local PostgreSQL 17 installation required'
    expand = (MIGRATION/'01_expand_break_duration.sql').read_text()
    validate = (MIGRATION/'02_validate_break_duration.sql').read_text()
    init = run([BIN/'initdb','-D',data,'-U','rituo_local_test','-A','trust','--no-locale','--encoding=UTF8'],timeout=30)
    if init.returncode: raise RuntimeError(init.stderr)
    options = shlex.join(['-h','', '-k',str(socket),'-p',port])
    startup = run([BIN/'pg_ctl','-D',data,'-l',work/'postgres.log','-w','start','-o',options],timeout=30)
    if startup.returncode:
        raise RuntimeError(startup.stderr + '\n' + (work/'postgres.log').read_text())
    started = True
    assert sql('SHOW listen_addresses;') == '', 'TCP must remain disabled'
    assert Path(sql('SHOW data_directory;')).resolve() == data
    assert sql('SELECT current_user;') == 'rituo_local_test'
    results.append('Private new cluster, Unix socket only; production environment excluded')
    baseline()
    for table in ['ritual_breaks','mode_breaks']:
        assert 'check constraint' in sql(f'UPDATE {table} SET break_duration_minutes=10;',success=False)
    before = rows()
    sql(expand)
    assert rows() == before, 'Migration changed existing data'
    results.append('Existing data unchanged by expansion')
    assert sql("SELECT count(*) FROM pg_constraint WHERE conname IN ('ritual_breaks_duration_1_15_check','mode_breaks_duration_1_15_check') AND NOT convalidated;") == '2'
    for table in ['ritual_breaks','mode_breaks']:
        for duration in [1,3,5,10,15]: sql(f'UPDATE {table} SET break_duration_minutes={duration};')
        for duration in [0,16]:
            assert 'check constraint' in sql(f'UPDATE {table} SET break_duration_minutes={duration};',success=False)
        assert 'check constraint' in sql(f'UPDATE {table} SET break_count=4;',success=False)
    results.append('Old-client durations 1/3/5 and new 10/15 accepted; 0/16 and four breaks rejected')
    before = rows()
    sql(validate)
    assert rows() == before
    assert sql("SELECT count(*) FROM pg_constraint WHERE conname IN ('ritual_breaks_duration_1_15_check','mode_breaks_duration_1_15_check') AND convalidated;") == '2'
    results.append('Validation succeeds without changing rows')
    sql(expand,success=False)
    assert rows() == before, 'Repeated migration altered data'
    results.append('Repeated expansion fails safely without modifying data')
    baseline()
    before = rows()
    holder = hold('LOCK TABLE mode_breaks IN ACCESS EXCLUSIVE MODE')
    begin = time.monotonic()
    error = sql(expand,success=False)
    elapsed = time.monotonic() - begin
    assert 'lock timeout' in error, error
    assert elapsed < 2, elapsed
    holder.communicate(timeout=8)
    assert rows() == before
    assert sql("SELECT count(*) FROM pg_constraint WHERE conname IN ('ritual_breaks_break_duration_minutes_check','mode_breaks_break_duration_minutes_check');") == '2'
    assert sql("SELECT count(*) FROM pg_constraint WHERE conname IN ('ritual_breaks_duration_1_15_check','mode_breaks_duration_1_15_check');") == '0'
    results.append(f'Contended second table: lock timeout in {elapsed:.2f}s; BOTH tables rolled back to 1–5')
    sql(expand)
    holder = hold('UPDATE mode_breaks SET break_count=2')
    sql(validate)
    assert holder.poll() is None, 'Validation unexpectedly waited for writer transaction'
    holder.communicate(timeout=8)
    results.append('Constraint validation completed with a concurrent open writer transaction')
    for message in results: print('PASS:',message)
    (ROOT/'Tests/break_migration_result.json').write_text(json.dumps({'postgres':run([BIN/'postgres','--version']).stdout.strip(),'results':results,'production_access':False},indent=2)+'\n')
finally:
    for holder in holders:
        if holder.poll() is None: holder.terminate(); holder.communicate(timeout=5)
    if started or data.joinpath('postmaster.pid').exists():
        stop = run([BIN/'pg_ctl','-D',data,'-m','fast','-w','stop'],timeout=15)
        if stop.returncode:
            raise RuntimeError('Could not stop local test cluster at '+str(work)+': '+stop.stderr)
    # Only remove the directory this script created; no existing DB is ever targeted.
    if not data.joinpath('postmaster.pid').exists(): shutil.rmtree(work)
