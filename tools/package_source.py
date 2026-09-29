#!/usr/bin/env python3
"""Make deterministic source archives. Does NOT invoke R CMD build/check.
Usage: python3 tools/package_source.py /path/to/output_directory
The output directory must be outside the package source tree.
"""
from pathlib import Path
import gzip
import hashlib
import io
import json
import sys
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
EPOCH = 1790640000  # 2026-09-29 00:00:00 UTC, fixed archive metadata, not a test time.


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    output = Path(sys.argv[1]).expanduser().resolve() if len(sys.argv) > 1 else ROOT.parent
    if output == ROOT or ROOT in output.parents:
        raise ValueError('Output directory must be outside the package tree.')
    output.mkdir(parents=True, exist_ok=True)
    files = [p for p in sorted(ROOT.rglob('*')) if p.is_file()
             and '.git' not in p.relative_to(ROOT).parts
             and not any(part.startswith('local-') for part in p.relative_to(ROOT).parts)
             and '__pycache__' not in p.parts and p.name != 'source_sha256.tsv']
    manifest = ROOT / 'validation/source_sha256.tsv'
    manifest.write_text('sha256\tpath\n' + ''.join(
        f'{digest(p)}\t{p.relative_to(ROOT).as_posix()}\n' for p in files), encoding='utf-8')
    files = sorted(files + [manifest])
    version = next(line.split(':', 1)[1].strip() for line in (ROOT/'DESCRIPTION').read_text().splitlines()
                   if line.startswith('Version:'))
    archive = output / f'evanxlsx_{version}.tar.gz'
    full_zip = output / f'evanxlsx_source_{version}.zip'
    for path in (archive, full_zip):
        if path.exists():
            raise FileExistsError(f'Refusing to overwrite {path}; choose a new output directory.')
    top_level = {'DESCRIPTION', 'NAMESPACE', 'LICENSE', 'README.md', 'NEWS.md', '.Rbuildignore'}
    package_files = [p for p in files if p.relative_to(ROOT).as_posix() in top_level
                     or p.relative_to(ROOT).parts[0] in {'R', 'man', 'tests'}]
    with archive.open('xb') as raw:
        with gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=EPOCH) as zipped:
            with tarfile.open(mode='w', fileobj=zipped, format=tarfile.PAX_FORMAT) as tar:
                for p in package_files:
                    data = p.read_bytes()
                    info = tarfile.TarInfo('evanxlsx/' + p.relative_to(ROOT).as_posix())
                    info.size, info.mtime, info.mode = len(data), EPOCH, 0o644
                    tar.addfile(info, io.BytesIO(data))
    with zipfile.ZipFile(full_zip, 'x', compression=zipfile.ZIP_DEFLATED) as z:
        for p in files:
            info = zipfile.ZipInfo('evanxlsx/' + p.relative_to(ROOT).as_posix(), (2026, 9, 29, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            z.writestr(info, p.read_bytes())
    with zipfile.ZipFile(full_zip) as z:
        assert z.testzip() is None
        for p in files:
            assert z.read('evanxlsx/' + p.relative_to(ROOT).as_posix()) == p.read_bytes()
    with tarfile.open(archive, 'r:gz') as tar:
        for p in package_files:
            assert tar.extractfile('evanxlsx/' + p.relative_to(ROOT).as_posix()).read() == p.read_bytes()
    report = {'version': version, 'R_CMD_build': 'NOT_RUN', 'R_CMD_check': 'NOT_RUN',
              'testthat': 'NOT_RUN', 'GitHub_publication': 'NOT_RUN',
              'archive_validation': 'CRC/content comparison completed; this is not an R package test',
              'files': [{'name': p.name, 'size_bytes': p.stat().st_size, 'sha256': digest(p)}
                        for p in (archive, full_zip)],
              'source_tar_file_count': len(package_files), 'source_zip_file_count': len(files)}
    (output / 'evanxlsx_delivery_manifest.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
