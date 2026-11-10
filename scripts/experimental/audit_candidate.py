"""Verify a local candidate and compare upstream tool files with pinned archives."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import sys
import zipfile
import create_candidate as candidate_recipe

PACKAGES = (
    ('cmake.zip', 'd163cd3ab4959b0a53fa8988f2ddbd2e6c501658201e6a154386bad9dbe4f836', 'cmake-3.31.6-windows-x86_64/', 'cmake/'),
    ('ninja.zip', 'f550fec705b6d6ff58f2db3c374c2277a37691678d6aba463adcbb129108467a', '', 'ninja/'),
    ('python.zip', '8d4d3590c10449d78aa4375f534e6d5f3027d67fdc362dd1a882279db6f90fdf', '', 'python/'),
    ('llvm-mingw-20251021.zip', '0a0ce4733b54de8c4858ecfc2a08447de57728dccf9fbf7fcba3ce7e0d0c6af8', 'llvm-mingw-20251021-ucrt-x86_64/', 'mingw/'),
)
TOOLSET = 'tools/rugby-dependencies/mingw-toolset/'


def digest(stream):
    return hashlib.file_digest(stream, 'sha256').hexdigest()


def digest_and_find(stream, patterns):
    h=hashlib.sha256(); tail=b''; found=False
    while chunk:=stream.read(1024*1024):
        h.update(chunk)
        data=(tail+chunk).lower()
        found = found or any(pattern in data for pattern in patterns)
        tail=data[-256:]
    return h.hexdigest(), found


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--zip', type=Path, required=True)
    p.add_argument('--source-cache', type=Path, required=True)
    args=p.parse_args()
    candidate=args.zip.resolve()
    expected=(Path(str(candidate)+'.sha256')).read_text(encoding='ascii').split()[0].lower()
    with candidate.open('rb') as f:
        actual=digest(f)
    if len(expected)!=64 or expected!=actual:
        raise ValueError('El SHA-256 externo del ZIP no coincide.')
    with zipfile.ZipFile(candidate) as z:
        names=z.namelist()
        if len(names)!=len({n.casefold() for n in names}):
            raise ValueError('Hay rutas duplicadas en el ZIP.')
        for n in names:
            parts=PurePosixPath(n).parts
            if not parts or n.startswith('/') or any(x in ('','.','..') or ':' in x or '\\' in x for x in n.split('/')):
                raise ValueError('Ruta inválida en ZIP: '+n)
        manifest=json.loads(z.read('MANIFIESTO.json'))
        if manifest.get('status')!='local-test-only':
            raise ValueError('El ZIP no está identificado como candidato local.')
        entries=manifest['files']
        lookup={e['path'].casefold():e for e in entries}
        if len(lookup)!=len(entries) or {n.casefold() for n in names} != set(lookup)|{'manifiesto.json'}:
            raise ValueError('El inventario no coincide con el contenido.')
        pinned=dict(candidate_recipe.LICENSE_HASHES)
        pinned['tools/extract-xiso-portable/artifacts/extract-xiso.exe']=candidate_recipe.EXTRACTOR_HASH
        pinned['tools/extract-xiso-portable/artifacts/LICENSE.TXT']=candidate_recipe.EXTRACTOR_LICENSE_HASH
        pinned[TOOLSET+'shader/resolve-full32-signed.dxbc']=candidate_recipe.SHADER_HASH
        for name, expected_hash in pinned.items():
            if name.casefold() not in lookup or lookup[name.casefold()]['sha256'] != expected_hash:
                raise ValueError('Componente fijado ausente o alterado: '+name)
        if z.read(TOOLSET+'shader/resolve-full32-signed.dxbc') not in z.read(TOOLSET+'rexglue/bin/librexgpu-xenos.dll'):
            raise ValueError('El complemento no contiene el shader fijado.')
        game=json.loads(z.read('analysis/baseline/game-manifest.json'))
        if set(game) != {'schema_version','file_count','files'} or game['file_count']!=len(game['files']):
            raise ValueError('El manifiesto de juego no está saneado o está incompleto.')
        forbidden={}
        for e in game['files']:
            forbidden.setdefault(e['size'],set()).add(e['sha256'].lower())
        fixed = {n.casefold() for n in (*candidate_recipe.APP_FILES, *candidate_recipe.LICENSE_HASHES)} | {
            'analysis/baseline/game-manifest.json', 'candidato_local_no_publicar.txt',
            'tools/extract-xiso-portable/artifacts/extract-xiso.exe',
            'tools/extract-xiso-portable/artifacts/license.txt',
            (TOOLSET+'shader/resolve-full32-signed.dxbc').casefold(),
        }
        home=str(Path.home()).lower()
        paths={home.replace('\\','/'), home.replace('/','\\')}
        patterns=[value.encode(encoding) for value in paths for encoding in ('utf-8','utf-16le')]
        local_paths=[]
        for index,e in enumerate(entries,1):
            name=e['path']; lower=name.casefold(); suffix=PurePosixPath(lower).suffix
            source = lower.startswith('port/src/') and suffix in ('.cpp','.h','.hpp')
            component = any(lower.startswith((TOOLSET+folder+'/').casefold()) for folder in candidate_recipe.TOOL_FOLDERS)
            if not (lower in fixed or source or component):
                raise ValueError('Archivo fuera de la lista permitida: '+name)
            if component and (suffix in ('.iso','.xex','.xbe','.xzp','.sav') or 'rugby' in PurePosixPath(lower).name or '.git' in PurePosixPath(lower).parts):
                raise ValueError('Archivo no permitido en herramientas: '+name)
            info=z.getinfo(e['path'])
            if info.file_size!=e['size']:
                raise ValueError('Tamaño incorrecto: '+e['path'])
            with z.open(info) as f:
                h, contains_path=digest_and_find(f,patterns)
            if contains_path:
                local_paths.append(e['path'])
            if h!=e['sha256'] or h in forbidden.get(e['size'],set()):
                raise ValueError('Contenido inesperado o procedente del juego: '+e['path'])
            if index%3000==0:
                print(f'Auditados {index}/{len(entries)} archivos...',flush=True)
        for filename, expected_hash, prefix, component in PACKAGES:
            src=args.source_cache/filename
            with src.open('rb') as f:
                if digest(f)!=expected_hash:
                    raise ValueError('El paquete original no coincide: '+filename)
            with zipfile.ZipFile(src) as origin:
                source_files=[i for i in origin.infolist() if not i.is_dir()]
                package_prefix=(TOOLSET+component).casefold()
                dest_names={n for n in lookup if n.startswith(package_prefix)}
                mapped=set()
                for item in source_files:
                    if not item.filename.startswith(prefix):
                        raise ValueError('Raíz inesperada en '+filename)
                    rel=item.filename[len(prefix):]
                    target=(TOOLSET+component+rel).casefold()
                    if target in mapped or target not in lookup:
                        raise ValueError('Archivo ausente o duplicado: '+target)
                    mapped.add(target)
                    with origin.open(item) as f:
                        if digest(f)!=lookup[target]['sha256']:
                            raise ValueError('Archivo alterado respecto de '+filename+': '+rel)
                if mapped!=dest_names:
                    raise ValueError('Hay archivos adicionales en '+component)
                print(f'{component}: {len(mapped)} archivos iguales al paquete fijado.',flush=True)
    if local_paths:
        print('ATENCIÓN: hay rutas del perfil local en los siguientes archivos; no publicar:')
        for name in local_paths: print('  '+name)
    print('Integridad y cuatro componentes de origen verificados. ReXGlue compilado y licencias siguen pendientes de revisión.')
    if local_paths:
        raise ValueError('El candidato contiene rutas del perfil local.')


if __name__=='__main__':
    try: main()
    except (OSError,ValueError,KeyError,zipfile.BadZipFile) as e:
        print('Auditoría fallida:',e,file=sys.stderr); sys.exit(1)
