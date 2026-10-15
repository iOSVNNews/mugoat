"""Regression tests for the native ABI and index-preserving hook generator."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT/'Scripts'/f'{name}.py')
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module); return module
c = load('prepare_online_c'); w = load('prepare_online_exports')

class OnlineTests(unittest.TestCase):
    def test_typed_calls_use_float_bits_and_reject_wrong_arity(self):
        header = """/* export: 'mp:PlayerPedId' */
u32 w2c_game_mp0x3APlayerPedId(w2c_game*);
/* export: 'mp:SetHeading' */
void w2c_game_mp0x3ASetHeading(w2c_game*, u32, f32);
/* export: 'mugoat:tls-base' */
u64* w2c_game_mugoat0x3Atls0x2Dbase(w2c_game* instance);
/* export: 'emscripten_stack_get_current' */
u64 w2c_game_emscripten_stack_get_current(w2c_game*);
/* export: '_emscripten_stack_alloc' */
u64 w2c_game__emscripten_stack_alloc(w2c_game*, u64);
/* export: '_emscripten_stack_restore' */
void w2c_game__emscripten_stack_restore(w2c_game*, u64);
"""
        source, tls = c.generate(header, {'exports':['mp:PlayerPedId','mp:SetHeading','mugoat:tls-base']})
        self.assertIn('online_f32(a[1].bits)', source)
        self.assertIn('count!=2', source)
        self.assertIn('a[1].type!=3', source)
        self.assertEqual(tls, 'w2c_game_mugoat0x3Atls0x2Dbase')
    def test_dispatch_table_is_sorted_for_binary_search(self):
        header = """/* export: 'mp:Zeta' */
u32 w2c_game_mp0x3AZeta(w2c_game*);
/* export: 'mp:Alpha' */
u32 w2c_game_mp0x3AAlpha(w2c_game*, u32);
/* export: 'mugoat:tls-base' */
u64* w2c_game_mugoat0x3Atls0x2Dbase(w2c_game* instance);
/* export: 'emscripten_stack_get_current' */
u64 w2c_game_emscripten_stack_get_current(w2c_game*);
/* export: '_emscripten_stack_alloc' */
u64 w2c_game__emscripten_stack_alloc(w2c_game*, u64);
/* export: '_emscripten_stack_restore' */
void w2c_game__emscripten_stack_restore(w2c_game*, u64);
"""
        source, _ = c.generate(header, {'exports':['mp:Zeta','mp:Alpha','mugoat:tls-base']})
        table = source.split('mugoat_command_names[]={')[1].split('};')[0]
        names = [n.strip('"') for n in table.split(',')]
        self.assertEqual(names, sorted(names, key=lambda n: n.encode()))
        self.assertEqual(len(names), 5)
        for index, name in enumerate(names):
            self.assertEqual(source.count(f'case {index}:'), 2, name)
        self.assertIn('w2c_game_mp0x3AAlpha((w2c_game*)instance,(u32)a[0].bits)', source)
    def test_hook_is_inserted_in_original_body_not_export_wrapper(self):
        s='\nvoid w2c_game_f42(w2c_game* instance, u64 var_p0) {\n  u64 local;\n  FUNC_PROLOGUE;\n  local=var_p0;\n  FUNC_EPILOGUE;\n}\n'
        patched = c.patch_hook(s,42,'hook(instance,var_p0);')
        self.assertIn('FUNC_PROLOGUE;\n  hook(instance,var_p0);',patched)
        self.assertIsNone(c.patch_hook(s,43,'bad();'))
    def test_leb_and_section_reader_round_trip(self):
        for n in [0,127,128,16384,0xffffffff,0xffffffffffffffff]:
            self.assertEqual(w.Reader(w.leb(n)).uint(),n)
        with self.assertRaises(ValueError): list(w.sections(b'bad'))

if __name__=='__main__': unittest.main()
