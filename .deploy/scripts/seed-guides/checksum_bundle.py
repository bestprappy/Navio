"""Build bundle checksums from staged Git bytes, never Windows CRLF copies.

Stage the five bundle files first, run this, then stage the resulting manifest.
The raw pinned download must match the committed bytes exactly.
"""
import hashlib
import json
from pathlib import Path
import subprocess

FILES = ('guides.json','expanded-guides.json','upgrade.py','upgrade_test.py','maintain.py')


def main():
    here = Path(__file__).resolve().parent
    root = Path(subprocess.check_output(['git','rev-parse','--show-toplevel'],cwd=here,text=True).strip())
    checks = {}
    for name in FILES:
        relative = (here/name).relative_to(root).as_posix()
        data = subprocess.check_output(['git','show',':'+relative],cwd=root)
        checks[name] = hashlib.sha256(data).hexdigest()
    (here/'expansion-checksums.json').write_text(json.dumps(checks,indent=2)+'\n',encoding='utf-8')


if __name__ == '__main__':
    main()
