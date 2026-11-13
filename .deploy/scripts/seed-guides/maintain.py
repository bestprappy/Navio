"""Run the reviewed expansion inside the existing private Navio VM session.

Default: private backup, verified archive and full SQL dry run (ROLLBACK).
--apply: dry run, Kyoto canary, verification, remaining batch, verification.
No network lookups, service/config changes, replacement Guides or migrations.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import upgrade


def run(command, *, data=None):
    result = subprocess.run(command, input=data, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, check=False)
    if result.returncode:
        raise RuntimeError('Maintenance command failed: '+result.stderr.decode('utf-8', errors='replace')[:1600])
    return result.stdout


def verify(before, after, pairs):
    old = {r['id']:r for r in before}
    new = {r['id']:r for r in after}
    if old.keys() != new.keys():
        raise RuntimeError('Guide identities changed during maintenance; inspect the private backup')
    targets = {p['id']:p for p in pairs}
    for gid, original in old.items():
        actual = new[gid]
        if gid not in targets:
            if actual != original:
                raise RuntimeError('A non-target Guide changed during maintenance; inspect before continuing')
            continue
        expected = targets[gid]['after']['content']
        if actual['content'] != expected:
            raise RuntimeError('A target Guide did not contain the reviewed expansion')
        immutable = set(original)-{'content','version','updated_at'}
        if any(actual[k] != original[k] for k in immutable):
            raise RuntimeError('Guide identity, ownership or publication metadata changed')
        increment = 0 if original['content'] == expected else 1
        if actual['version'] != original['version']+increment:
            raise RuntimeError('Guide version did not match the scoped update')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if os.name != 'posix' or not Path('/var/run/docker.sock').exists():
        parser.error('Run only in the already authenticated Navio VM maintenance session')
    os.umask(0o077)
    containers = run(['docker','ps','--filter','label=com.docker.compose.project=navio',
        '--filter','label=com.docker.compose.service=postgres','--format','{{.Names}}']).decode().splitlines()
    if len(containers) != 1:
        parser.error('Expected exactly one running Navio PostgreSQL container')
    container = containers[0]
    psql = ['docker','exec','-i',container,'sh','-c',
            'exec psql -X -A -t -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"']
    def rows():
        return json.loads(run(psql,data=b"SELECT coalesce(jsonb_agg(to_jsonb(g) ORDER BY g.id),'[]'::jsonb) FROM iam.guides g;"))
    pairs = upgrade.validate(json.loads((upgrade.HERE/'guides.json').read_text(encoding='utf-8')),
        json.loads((upgrade.HERE/'expanded-guides.json').read_text(encoding='utf-8')))
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    folder = Path.cwd()/'backups'/stamp
    folder.mkdir(parents=True,exist_ok=False)
    before = rows()
    (folder/'before-guides.json').write_text(json.dumps(before,ensure_ascii=False,indent=2),encoding='utf-8')
    archive = run(['docker','exec',container,'sh','-c',
        'exec pg_dump -Fc --schema=iam -U "$POSTGRES_USER" -d "$POSTGRES_DB"'])
    (folder/'before-iam.dump').write_bytes(archive)
    # Verify archive readability before any data mutation. Never print credentials.
    run(['docker','exec','-i',container,'pg_restore','--list'],data=archive)
    digest = hashlib.sha256(archive).hexdigest()
    (folder/'backup.sha256').write_text(digest+'  before-iam.dump\n',encoding='utf-8')
    dry = upgrade.prepare_sql(pairs)
    (folder/'dry-run.sql').write_text(dry,encoding='utf-8')
    (folder/'dry-run.log').write_bytes(run(psql,data=dry.encode('utf-8')))
    if rows() != before:
        raise RuntimeError('Dry-run state changed; nothing will be applied automatically')
    print('Verified private backup:',folder/'before-iam.dump')
    print('Full twenty-Guide dry run passed; backup SHA256:',digest)
    if not args.apply:
        print('No Guide changes committed. Review dry-run.log, then rerun with --apply.')
        return
    canary = [p for p in pairs if p['slug']=='kyoto']
    for name, batch in [('canary',canary),('batch',pairs)]:
        sql = upgrade.prepare_sql(batch,apply=True,backup_verified=True)
        (folder/(name+'.sql')).write_text(sql,encoding='utf-8')
        (folder/(name+'.log')).write_bytes(run(psql,data=sql.encode('utf-8')))
        verify(before,rows(),batch if name=='canary' else pairs)
        print(name,'verified')
    after = rows()
    (folder/'after-guides.json').write_text(json.dumps(after,ensure_ascii=False,indent=2),encoding='utf-8')
    result = {'passed':True,'backupSha256':digest,'guides':[
        {'slug':p['slug'],'id':p['id'],'places':len(p['after']['content']['places'])} for p in pairs]}
    (folder/'result.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print('All twenty maintained Guides verified; other Guides and publication metadata preserved.')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(str(error),file=sys.stderr)
        sys.exit(1)
