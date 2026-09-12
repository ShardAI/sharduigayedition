#!/usr/bin/env python3
"""Keep the single-file loadstring distribution in sync with the standalone module."""
from pathlib import Path
import argparse

root = Path(__file__).resolve().parents[1]
start = '-- BEGIN GENERATED LIQUID GLASS\n'
end = '-- END GENERATED LIQUID GLASS\n'
parser = argparse.ArgumentParser()
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
library = root / 'Library.luau'
text = library.read_text()
source = (root / 'addons/LiquidGlass.luau').read_text()
block = start + 'local LiquidGlass = (function()\n' + source + '\nend)()\n' + end
if start in text:
    a = text.index(start)
    b = text.index(end, a) + len(end)
    updated = text[:a] + block + text[b:]
else:
    updated = block + '\n' + text
if args.check:
    if updated != text:
        raise SystemExit('LiquidGlass bundle is stale; run tools/sync_liquid_glass.py')
else:
    library.write_text(updated)
