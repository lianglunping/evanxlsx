#!/usr/bin/env python3
"""Limited structural audit, NOT an R parser or an R runtime test.
Run from the package root: python3 tools/static_audit.py
PyYAML is optional; an unavailable YAML parser is reported as NOT_RUN.
"""
from pathlib import Path
import hashlib
import json
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]


def lexical_balance(text: str) -> str:
    """Check delimiters outside R comments/quoted strings; return masked source."""
    stack, quote, comment, escaped = [], None, False, False
    masked = []
    closing = {')': '(', ']': '[', '}': '{'}
    for offset, char in enumerate(text):
        if comment:
            masked.append('\n' if char == '\n' else ' ')
            if char == '\n':
                comment = False
        elif quote:
            masked.append('\n' if char == '\n' else ' ')
            if escaped:
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == quote:
                quote = None
        elif char == '#':
            comment = True
            masked.append(' ')
        elif char in ('"', "'", '`'):
            quote = char
            masked.append(' ')
        else:
            masked.append(char)
            if char in '([{':
                stack.append((char, offset))
            elif char in ')]}':
                if not stack or stack[-1][0] != closing[char]:
                    raise ValueError(f'unmatched delimiter {char!r} at offset {offset}')
                stack.pop()
    if quote or stack:
        raise ValueError(f'unclosed quote or delimiter: quote={quote!r}, stack={stack}')
    return ''.join(masked)


def main() -> None:
    errors, checks = [], {}
    files = [p for p in sorted(ROOT.rglob('*')) if p.is_file()
             and not any(x == '.git' or x.startswith(('local-', 'portable-')) for x in p.parts)]
    texts = {}
    for path in files:
        if path.name in ('static_audit.json', 'source_sha256.tsv'):
            continue
        try:
            texts[path.relative_to(ROOT).as_posix()] = path.read_text(encoding='utf-8')
        except UnicodeDecodeError:
            errors.append(f'Non-UTF8 file: {path.relative_to(ROOT)}')
    checks['utf8_source_files_examined'] = len(texts)
    required = ['DESCRIPTION', 'NAMESPACE', 'LICENSE', 'R/write_xlsx.R',
                'R/validate.R', 'man/write_xlsx.Rd', 'tests/testthat.R',
                'tests/testthat/helper-xml.R', 'tools/check.R', 'README.md']
    errors.extend(f'Missing: {name}' for name in required if name not in texts)
    r_files = {name: text for name, text in texts.items() if name.endswith('.R')}
    masked = {}
    for name, text in r_files.items():
        try:
            masked[name] = lexical_balance(text)
        except ValueError as exc:
            errors.append(f'{name}: {exc}')
    checks['r_files_lexically_examined'] = len(r_files)
    checks['lexical_scope'] = 'Balanced delimiters/comments/quotes only; NOT native R parsing'
    rd = texts.get('man/write_xlsx.Rd', '')
    rd_stack = 0
    for match in re.finditer(r'(?<!\\)[{}]', rd):
        rd_stack += 1 if match[0] == '{' else -1
        if rd_stack < 0:
            errors.append('Unbalanced Rd braces')
            break
    if rd_stack:
        errors.append('Unbalanced Rd braces')
    args = ['x', 'file', 'sheet', 'font', 'font_size', 'align', 'header_align',
            'valign', 'wrap', 'widths', 'max_width', 'freeze', 'freeze_first_col',
            'filter', 'three_line', 'grid_lines', 'overwrite']
    documented = re.findall(r'\\item\{(\w+)\}', rd)
    if documented != args:
        errors.append('Rd argument names/order differ from expected API')
    signature = masked.get('R/write_xlsx.R', '').split('write_xlsx <- function(', 1)[-1].split(') {', 1)[0]
    depth, parts, start = 0, [], 0
    for i, char in enumerate(signature):
        if char == '(':
            depth += 1
        elif char == ')':
            depth -= 1
        elif char == ',' and depth == 0:
            parts.append(signature[start:i]); start = i + 1
    parts.append(signature[start:])
    actual = [p.strip().split('=')[0].strip() for p in parts]
    if actual != args:
        errors.append(f'Source signature differs: {actual}')
    checks['documented_arguments'] = len(args)
    if texts.get('NAMESPACE', '').strip() != 'export(write_xlsx)':
        errors.append('Unexpected NAMESPACE export')
    checks['exported_functions'] = ['write_xlsx']
    description = texts.get('DESCRIPTION', '')
    for field in ('Package', 'Version', 'Title', 'Authors@R', 'Description',
                  'License', 'Encoding', 'Imports', 'Suggests'):
        if not re.search(rf'^{re.escape(field)}:', description, re.M):
            errors.append(f'DESCRIPTION missing {field}')
    tests = {name: len(re.findall(r'\btest_that\s*\(', text))
             for name, text in masked.items() if Path(name).name.startswith('test-')}
    checks['test_scenarios_written_not_run'] = tests
    checks['total_test_scenarios_written_not_run'] = sum(tests.values())
    try:
        import yaml
        workflow = yaml.load(texts['.github/workflows/R-CMD-check.yaml'], Loader=yaml.BaseLoader)
        assert {'push', 'pull_request', 'workflow_dispatch'} <= set(workflow['on'])
        configs = workflow['jobs']['check']['strategy']['matrix']['config']
        assert len(configs) == 6
        assert {c['label'] for c in configs} == {
            'linux-release', 'windows-release', 'macos-arm-release',
            'macos-intel-release', 'linux-oldrel', 'linux-minimum'}
        checks['workflow_yaml'] = 'Parsed with PyYAML ' + yaml.__version__ + '; NOT executed'
    except ImportError:
        checks['workflow_yaml'] = 'NOT_RUN: PyYAML unavailable'
    except Exception as exc:
        errors.append(f'Workflow structure: {exc}')
    report = {
        'audit_status': 'NO_STRUCTURAL_ISSUES_DETECTED' if not errors else 'STRUCTURAL_ISSUES_FOUND',
        'checks': checks, 'errors': errors,
        'R_runtime_found_on_PATH': shutil.which('R'),
        'Rscript_found_on_PATH': shutil.which('Rscript'),
        'native_R_parse': 'NOT_RUN', 'R_CMD_check': 'NOT_RUN',
        'testthat': 'NOT_RUN', 'XLSX_export': 'NOT_RUN', 'GitHub_publication': 'NOT_CHECKED_BY_STATIC_AUDIT',
        'limitations': 'This report cannot establish R syntax correctness, installability, runtime behavior, or Excel rendering.',
        'source_sha256_examined': {name: hashlib.sha256(text.encode('utf-8')).hexdigest()
                                   for name, text in texts.items()}
    }
    (ROOT / 'validation').mkdir(exist_ok=True)
    (ROOT / 'validation/static_audit.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in report.items() if k != 'source_sha256_examined'}, indent=2))
    if errors:
        sys.exit(1)


if __name__ == '__main__':
    main()
