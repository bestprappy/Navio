"""Download a pinned, checksummed Guide maintenance bundle in the Navio VM.

Run from the existing authenticated remote session. Defaults to backup + dry run.
Pass --apply explicitly for backed-up canary and batch updates.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.request

FILES = {'guides.json','expanded-guides.json','upgrade.py','upgrade_test.py','maintain.py'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--revision',required=True)
    parser.add_argument('--apply',action='store_true')
    args = parser.parse_args()
    if not re.fullmatch('[a-f0-9]{40}',args.revision):
        parser.error('Use the full reviewed Git commit SHA, never a moving branch')
    if os.name != 'posix' or not Path('/var/run/docker.sock').exists():
        parser.error('Run in the existing Navio VM session only')
    os.umask(0o077)
    base = ('https://raw.githubusercontent.com/bestprappy/Navio/'+args.revision+
            '/.deploy/scripts/seed-guides/')
    def download(name):
        with urllib.request.urlopen(base+name,timeout=30) as response:
            return response.read()
    checks = json.loads(download('expansion-checksums.json'))
    if set(checks) != FILES or any(not re.fullmatch('[a-f0-9]{64}',v) for v in checks.values()):
        raise RuntimeError('Invalid maintenance bundle manifest')
    folder = Path.home()/'navio-maintenance'/('guide-expansion-'+args.revision[:12])
    folder.mkdir(parents=True,exist_ok=True)
    for name in sorted(FILES):
        path = folder/name
        data = path.read_bytes() if path.exists() else download(name)
        if hashlib.sha256(data).hexdigest() != checks[name]:
            raise RuntimeError('Checksum mismatch for '+name+'; no maintenance executed')
        if not path.exists():
            with path.open('xb') as out:
                out.write(data)
    subprocess.run([sys.executable,'upgrade_test.py'],cwd=folder,check=True)
    command = [sys.executable,'maintain.py']
    if args.apply:
        command.append('--apply')
    subprocess.run(command,cwd=folder,check=True)


if __name__ == '__main__':
    main()
