"""Build a local source-and-rebuild kit for the experimental MinGW SDK."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

import create_candidate

ROOT = Path(__file__).resolve().parents[2]
FILES = (
    'scripts/get_build_components.ps1', 'scripts/apply_exact_patch.ps1',
    'scripts/verify_shadow_plugin.ps1', 'scripts/experimental/get_llvm_mingw.py',
    'scripts/experimental/build_mingw_graphics.ps1', 'scripts/experimental/build_relink_kit.ps1',
    'patches/shadow-integer-r16-fetch.patch',
)
README = '''KIT LOCAL DE FUENTES Y RECONSTRUCCIÓN — NO PUBLICAR

Contiene una copia de las fuentes usadas para el SDK experimental MinGW,
incluidas las fuentes modificadas de FFmpeg y libmspack, y la receta de
compilación. No contiene la ISO ni el juego. Se puede editar la fuente y
reconstruir el SDK sin usar el disco del juego.

En Windows x64, extraer este ZIP en una ruta sin espacios y ejecutar:
  powershell -ExecutionPolicy Bypass -File scripts/experimental/build_relink_kit.ps1 -Toolset C:\\rugby-tools -Destination C:\\rugby-rebuilt

La receta obtiene CMake, Ninja, Python y LLVM/MinGW fijados si faltan. El
resultado queda en C:\\rugby-rebuilt\\sdk. La ruta de herramientas y el
destino también deben estar libres de espacios; no usar un destino existente.
Se requiere conexión para obtener herramientas ausentes. El shader ya está
incluido y se verifica. Se conservan los objetos en la carpeta de destino.

Para cambiar FFmpeg o libmspack después de la primera compilación, editar la
fuente en src y ejecutar desde PowerShell (adaptar las rutas si corresponde):
  $env:PATH = 'C:\\rugby-tools\\mingw\\bin;' + $env:PATH
  & 'C:\\rugby-tools\\cmake\\bin\\cmake.exe' --build 'C:\\rugby-rebuilt\\build' --target rexruntime --parallel 4
  & 'C:\\rugby-tools\\cmake\\bin\\cmake.exe' --install 'C:\\rugby-rebuilt\\build' --prefix 'C:\\rugby-rebuilt\\sdk'

La DLL resultante está en C:\\rugby-rebuilt\\sdk\\bin\\librexruntime.dll.
Comprobar que los dos comandos terminen correctamente antes de sustituirla.

Este kit es una prueba local, no una afirmación de cumplimiento de licencias.
Faltan revisión jurídica, verificación independiente de todas las fuentes y
prueba de sustitución del runtime en una build de release.
'''.encode('utf-8')


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--toolset', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    work, tool, output = args.work.resolve(), args.toolset.resolve(), args.output.resolve()
    if output.exists() or output.is_relative_to(ROOT) or output.is_relative_to(work) or output.is_relative_to(tool):
        raise ValueError('La salida debe ser nueva y estar fuera de las entradas.')
    subprocess.run([sys.executable, str(ROOT/'scripts/experimental/sdk_build_state.py'),
                    'verify', '--work', str(work), '--toolset', str(tool)], check=True)
    state = json.loads((work/'sdk-build-inputs.json').read_text(encoding='utf-8'))
    sources = state['sources']
    entries = {}
    for rel, expected in sources.items():
        create_candidate.archive_name(rel)
        path = work/'src'/rel
        if path.is_symlink() or path.is_junction() or digest(path) != expected:
            raise ValueError('Fuente ausente o alterada: '+rel)
        create_candidate.add_entry(entries, 'src/'+rel, path)
    for rel in (*FILES, *create_candidate.LICENSE_HASHES):
        create_candidate.add_entry(entries, rel, ROOT/rel)
    for name in ('resolve-full32-signed.dxbc', 'resolve_full_32bpp_cs.h'):
        create_candidate.add_entry(entries, 'shader/'+name, tool/'shader'/name)
    create_candidate.add_entry(entries, 'LEEME_NO_PUBLICAR.txt', README)
    game = json.loads((ROOT/'analysis/baseline/game-manifest.json').read_text(encoding='utf-8-sig'))
    forbidden = {(x['size'], x['sha256'].lower()) for x in game['files']}
    inventory = []
    temporary = output.with_name('.'+output.name+'.partial')
    if temporary.exists():
        raise ValueError('Ya existe la salida temporal: '+str(temporary))
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(temporary, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as z:
        for index, (name, source) in enumerate(sorted(entries.values(), key=lambda x:x[0].casefold()), 1):
            data = source if isinstance(source, bytes) else source.read_bytes()
            value = hashlib.sha256(data).hexdigest()
            if (len(data), value) in forbidden:
                raise ValueError('Coincide con contenido del disco: '+name)
            z.writestr(create_candidate.zip_info(name), data)
            inventory.append({'path':name, 'size':len(data), 'sha256':value})
            if index % 3000 == 0: print(f'Empaquetados {index}/{len(entries)} archivos...', flush=True)
        z.writestr(create_candidate.zip_info('MANIFIESTO.json'), json.dumps({'status':'local-test-only','files':inventory}, indent=2).encode('utf-8'))
    with zipfile.ZipFile(temporary) as z:
        for item in inventory:
            with z.open(item['path']) as stream:
                if hashlib.file_digest(stream, 'sha256').hexdigest() != item['sha256']:
                    raise ValueError('Contenido incorrecto en ZIP: '+item['path'])
    checksum = digest(temporary)
    temporary.rename(output)
    Path(str(output)+'.sha256').write_text(checksum+'  '+output.name+'\n', encoding='ascii')
    print(f'Kit local: {output}\nSHA-256: {checksum}\nArchivos: {len(inventory)}')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError, zipfile.BadZipFile) as exc:
        print('No se pudo construir el kit:', exc, file=sys.stderr)
        sys.exit(1)
