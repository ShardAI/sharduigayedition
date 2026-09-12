#!/usr/bin/env python3
"""Run with: python3 tests/run.py /path/to/luau. Does not claim to emulate Roblox."""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
code = (root / 'tests/RobloxMock.luau').read_text()
code += '\nlocal Glass = (function()\n' + (root / 'addons/LiquidGlass.luau').read_text() + '\nend)()\n'
code += (root / 'tests/LiquidGlass.spec.luau').read_text()
library = (root / 'Library.luau').read_text()
start = library.index('local function getGlassManager()')
end = library.index('function Library:ApplyTextStroke', start)
code += "\nlocal LiquidGlass = Glass\nlocal ScreenGui = Instance.new('ScreenGui')\n"
code += "local Library = {_CreatedGuiObjects = setmetatable({}, {__mode = 'k'})}\n"
code += library[start:end]
code += (root / 'tests/LibraryGlass.spec.luau').read_text()
with tempfile.TemporaryDirectory(prefix='shardui-tests-') as temporary:
    suite = Path(temporary) / 'suite.luau'
    suite.write_text(code)
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else 'luau', str(suite)], check=True)
