"""Verify that task overrides differ from generated code only at sync."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
header = (root/'port/src/task_sync.h').read_text()

def body(text, needle):
    start = text.index('{', text.index(needle))
    end, depth = start+1, 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[start:end]

results = []
for file, address, name in [('111','823011D8','WaitTaskWithSync'),('1','82301238','CompleteTaskWithSync')]:
    original = body((root/f'port/generated/default/rugby2011_recomp.{file}.cpp').read_text(), f'DEFINE_REX_FUNC(sub_{address})')
    patched = body(header, f'static void {name}')
    expected = original.replace('// sync ', '// sync: full PowerPC store/load ordering\n\tstd::atomic_thread_fence(std::memory_order_seq_cst);')
    if original.count('// sync ') != 1 or patched != expected:
        raise RuntimeError(f'Task override {address} needs review against regenerated code')
    results.append({'address':address, 'original_sha256':hashlib.sha256(original.encode()).hexdigest(),
                    'only_change':'implement original sync with std::atomic_thread_fence(seq_cst)',
                    'exact_body_match_except_sync':True})
(root/'analysis/rexglue/task-sync-audit.json').write_text(json.dumps(results,indent=2)+'\n')
print('Both task bodies match generated instructions; only sync barriers differ.')
