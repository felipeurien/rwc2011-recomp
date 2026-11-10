"""Compare the vendored tiny-AES and disruptorplus files to pinned Git objects."""
import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
TINY = '23856752fbd139da0b8ca6e471a13d5bcc99a08d'
DISRUPTOR = '5787e9cb7551c8c79cf9ce14f7be860dc907e9a4'
REX = 'f5337cdc947ff6d4c4196737e2c807a48f2a1fc2'
CHANGE = '01d595483ccd043e56e7adaccae454e54f252764'
REX_PATH = 'thirdparty/disruptorplus/include/disruptorplus/'
CHANGED = 'multi_threaded_claim_strategy.hpp'
TINY_FILES = ('aes.c', 'aes.h', 'aes.hpp')
DISRUPTOR_FILES = (
    'blocking_wait_strategy.hpp', 'config.hpp', 'multi_threaded_claim_strategy.hpp',
    'ring_buffer.hpp', 'sequence_barrier_group.hpp', 'sequence_barrier.hpp',
    'sequence_range.hpp', 'sequence.hpp', 'single_threaded_claim_strategy.hpp',
    'spin_wait_strategy.hpp', 'spin_wait.hpp',
)


def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args]).strip()


def require_files(folder, expected):
    actual = {p.relative_to(folder).as_posix() for p in folder.rglob('*') if p.is_file()}
    if actual != set(expected):
        raise ValueError(f'Archivos inesperados o ausentes en {folder}')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', type=Path, required=True)
    p.add_argument('--tiny-repo', type=Path, required=True)
    p.add_argument('--disruptor-repo', type=Path, required=True)
    p.add_argument('--rex-repo', type=Path, required=True)
    a = p.parse_args()
    tiny = a.source/'thirdparty/tiny-aes-c'
    disruptor = a.source/'thirdparty/disruptorplus/include/disruptorplus'
    require_files(tiny, TINY_FILES)
    require_files(disruptor, DISRUPTOR_FILES)
    for name in TINY_FILES:
        if git(a.tiny_repo, 'hash-object', '--no-filters', str(tiny/name)) != git(a.tiny_repo, 'rev-parse', f'{TINY}:{name}'):
            raise ValueError('tiny-AES difiere: '+name)
    for name in DISRUPTOR_FILES:
        local = git(a.disruptor_repo, 'hash-object', '--no-filters', str(disruptor/name))
        upstream = git(a.disruptor_repo, 'rev-parse', f'{DISRUPTOR}:include/disruptorplus/{name}')
        if name != CHANGED and local != upstream:
            raise ValueError('disruptorplus difiere inesperadamente: '+name)
        if name == CHANGED:
            if local != git(a.rex_repo, 'rev-parse', f'{REX}:{REX_PATH+name}'):
                raise ValueError('El archivo modificado difiere de ReXGlue.')
            if upstream != git(a.rex_repo, 'rev-parse', f'{CHANGE}^:{REX_PATH+name}'):
                raise ValueError('La versión anterior no coincide con Xenia.')
            if local != git(a.rex_repo, 'rev-parse', f'{CHANGE}:{REX_PATH+name}'):
                raise ValueError('El cambio no coincide con el commit documentado.')
    subprocess.run(['git', '-C', str(a.rex_repo), 'merge-base', '--is-ancestor', CHANGE, REX], check=True)
    for repo, ref, notice in (
        (a.tiny_repo, f'{TINY}:unlicense.txt', 'TINYAES-UNLICENSE.txt'),
        (a.disruptor_repo, f'{DISRUPTOR}:LICENSE.txt', 'DISRUPTORPLUS-UPSTREAM-LICENSE.txt'),
    ):
        original = subprocess.check_output(['git', '-C', str(repo), 'show', ref])
        if original != (ROOT/'analysis/release-licenses'/notice).read_bytes():
            raise ValueError('El aviso no coincide: '+notice)
    print('Verificados 3 archivos tiny-AES, 10 cabeceras Xenia y un cambio de ReXGlue; avisos iguales a los commits fijados.')
    print('La coincidencia técnica no sustituye la revisión de condiciones de distribución.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print('No se pudo verificar la procedencia:', exc, file=sys.stderr)
        sys.exit(1)
