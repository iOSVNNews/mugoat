"""Guard libc++abi __dynamic_cast (f91082) against invalid indirect calls.

Scaleform GFx in GTA V evaluates ActionScript components (such as GAME_STREAM or phone HUD).
When a movie clip or Flash object is missing or not yet attached (e.g. during an in-game resolution
switch or fast stream transition), Scaleform executes dynamic_cast on the object. If the object
has an uninitialized or corrupted vtable, calling the typeinfo virtual method yields table index 0
(a null function pointer), which triggers WASM_RT_TRAP_CALL_INDIRECT ("Native trap 6") and kills
the engine.

In standard C++, dynamic_cast on a pointer never traps or throws: if the cast cannot be performed
or the vtable is invalid, it simply returns NULL (0ull). This patch guards every indirect call
in w2c_game_f91082 to return 0ull on index 0 or unmapped slots, allowing Scaleform to gracefully
handle the missing movie clip without crashing the game.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
FUNCTION = '91082'
MARK = '/* dynamic_cast guard */'
PATTERN = re.compile(r'CHECK_CALL_INDIRECT\([^,]+,\s*\([^)]+\)[^,]+,\s*[^,]+,\s*(?P<idx>var_[a-zA-Z0-9]+)\);')

def patch_call(match):
    idx = match.group('idx')
    guard = f'if ({idx} == 0 || {idx} >= instance->w2c_game_T0.size || !instance->w2c_game_T0.data[{idx}].func) return 0ull; {MARK}\n  '
    return guard + match.group(0)

patched = False
for path in sorted((root / 'Generated').glob('game_*.c')):
    s = path.read_text()
    found = re.search(r'^\S.* w2c_game_f' + FUNCTION + r'\(w2c_game\* instance[^;]*\{$', s, re.M)
    if not found:
        continue
    start = found.start()
    end = s.index('\n}\n', start)
    body = s[start:end]
    if MARK in body:
        print(f'dynamic_cast guard: already patched in {path.name}')
        patched = True
        break
    new_body = PATTERN.sub(patch_call, body)
    if new_body != body:
        # Also ensure null `sub` pointer returns immediately at prologue
        if 'if (!var_p0) return 0ull;' not in new_body and 'FUNC_PROLOGUE;\n' in new_body:
            new_body = new_body.replace('FUNC_PROLOGUE;\n', f'FUNC_PROLOGUE;\n  if (!var_p0) return 0ull; {MARK}\n', 1)
        s = s[:start] + new_body + s[end:]
        path.write_text(s)
        print(f'dynamic_cast guard: patched f{FUNCTION} in {path.name}')
        patched = True
        break

if not patched and list((root / 'Generated').glob('game_*.c')):
    print(f'dynamic_cast guard: warning - f{FUNCTION} not found in Generated/game_*.c')
