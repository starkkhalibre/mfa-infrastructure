"""Run with python3 tests/check_pxc_entrypoint.py; no Docker or database needed."""
from pathlib import Path
import subprocess
import tempfile


with tempfile.TemporaryDirectory() as directory:
    directory = Path(directory)
    upstream = directory / "entrypoint.sh"
    original = '''#!/bin/bash
for i in {120..0}; do
    echo "$i"
    break
done
printf '%s\\n' "$@"
'''
    upstream.write_text(original)
    wrapper = directory / "wrapper.sh"
    source = Path(__file__).resolve().parents[1] / "config/bin/pxc-entrypoint.sh"
    wrapper.write_text(source.read_text().replace("/entrypoint.sh", str(upstream)))
    result = subprocess.run(
        ["bash", str(wrapper), "mysqld", "--option=value with spaces"],
        capture_output=True, text=True, check=True,
        env={"PATH": "/usr/bin:/bin", "TMPDIR": str(directory)},
    )
    assert result.stdout.splitlines() == ["600", "mysqld", "--option=value with spaces"]
    assert upstream.read_text() == original
    print("PXC startup wait extended; arguments and upstream entrypoint preserved")
