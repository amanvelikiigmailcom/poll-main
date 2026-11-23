#!/usr/bin/env python3
"""Local full checks with durable logs and bounded console output (stdlib only)."""
import json
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def summarize(kind, output):
    """Return counts, protocol validity and useful failure details."""
    counts = dict(passed=0, failed=0, skipped=0)
    details = []
    valid = False
    if kind == 'flutter':
        finished = {}
        names = {}
        for line in output.splitlines():
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if not isinstance(event, dict):
                continue
            if event.get('type') == 'testStart':
                names[event['test']['id']] = event['test']['name']
            elif event.get('type') == 'error':
                details.append(names.get(event.get('testID'), 'Flutter error') + '\n'
                               + str(event.get('error', '')) + '\n'
                               + str(event.get('stackTrace', '')))
            elif event.get('type') == 'testDone' and not event.get('hidden', False):
                finished[event['testID']] = event
            elif event.get('type') == 'done':
                valid = event.get('success') is True
        for event in finished.values():
            key = ('skipped' if event.get('skipped') else
                   'passed' if event.get('result') == 'success' else 'failed')
            counts[key] += 1
    elif kind == 'node':
        fields = {}
        for line in output.splitlines():
            match = re.fullmatch(r'# (tests|pass|fail|cancelled|skipped|todo) (\d+)', line)
            if match:
                fields[match[1]] = int(match[2])
        valid = all(key in fields for key in ('tests', 'pass', 'fail', 'cancelled', 'skipped', 'todo'))
        counts = dict(passed=fields.get('pass', 0),
                      failed=fields.get('fail', 0) + fields.get('cancelled', 0),
                      skipped=fields.get('skipped', 0) + fields.get('todo', 0))
        valid = valid and fields.get('tests') == sum(counts.values())
        lines = output.splitlines()
        for i, line in enumerate(lines):
            if re.match(r'\s*not ok \d+', line):
                details.append('\n'.join(lines[max(0, i - 1):i + 32]))
    elif kind == 'analysis':
        counts = {key: len(re.findall(r'^\s*' + key + r'\s+•', output, re.M))
                  for key in ('error', 'warning', 'info')}
        valid = 'No issues found!' in output or bool(re.search(r'\d+ issues? found\.', output))
        details = [line for line in output.splitlines()
                   if re.match(r'\s*(error|warning)\s+•', line)]
    elif kind == 'syntax':
        counts = {}
        valid = True  # node --check is intentionally silent on success
    else:
        raise ValueError(kind)
    return counts, valid, details


def checked_result(kind, output, returncode):
    counts, valid, details = summarize(kind, output)
    problem = None
    if not valid:
        problem = 'Missing/incomplete successful report; inspect the full log.'
    elif kind in ('flutter', 'node') and counts['passed'] + counts['failed'] == 0:
        problem = 'Zero executed tests (empty or all skipped); review required.'
    elif counts.get('failed', 0) or counts.get('error', 0) or counts.get('warning', 0):
        problem = 'Checks reported failures.'
    # Never turn an unsuccessful child process into success, even with a green report.
    code = returncode if returncode > 0 else 128 - returncode if returncode < 0 else (1 if problem else 0)
    return counts, code, details, problem


def run_stage(label, kind, command, cwd, directory):
    path = directory / (kind + '.log')
    start = time.monotonic()
    print(f'{label}: running…', flush=True)
    try:
        with path.open('w', encoding='utf-8') as log:
            result = subprocess.run(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT,
                                    encoding='utf-8', check=False)
        returncode = result.returncode
    except FileNotFoundError as error:
        path.write_text(str(error), encoding='utf-8')
        returncode = 127
    except KeyboardInterrupt:
        print(f'Interrupted; partial log: {path}', flush=True)
        raise
    output = path.read_text(encoding='utf-8', errors='replace')
    counts, code, details, problem = checked_result(kind, output, returncode)
    values = ', '.join(f'{value} {key}' for key, value in counts.items())
    print(f'{label}: {values or "syntax check"}; {time.monotonic() - start:.1f}s; '
          f'exit={code} (process={returncode})\nLog: {path}', flush=True)
    if code:
        if problem:
            print(problem)
        excerpt = '\n'.join(details).splitlines() if details else output.splitlines()[-60:]
        print('\n'.join(line[:1000] for line in excerpt[:60]))
        if len(excerpt) > 60:
            print('Excerpt truncated; full diagnostics are in the log.')
    return code


def main():
    if len(sys.argv) != 1:
        print('Usage: python3 scripts/checks.py (runs all local checks)', file=sys.stderr)
        return 2
    directory = Path(tempfile.mkdtemp(prefix='flyprox-checks-'))
    app = ROOT / 'app'
    if (app / 'pubspec.yaml').is_file():
        stages = [
            ('Flutter', 'flutter', ['flutter', 'test', '--no-pub', '--reporter', 'json'], app),
            ('Analysis', 'analysis', ['flutter', 'analyze', '--no-pub', '--no-fatal-infos', 'lib', 'test'], app),
        ]
    else:
        files = sorted(str(path.relative_to(ROOT)) for path in (ROOT / 'tests').glob('*.test.js'))
        if not files:
            print('Zero test files; refusing an empty run.', file=sys.stderr)
            return 1
        stages = [
            ('Backend', 'node', ['node', '--test', '--test-reporter=tap', *files], ROOT),
            ('Server syntax', 'syntax', ['node', '--check', 'src/server.js'], ROOT),
        ]
    first_failure = 0
    try:
        for stage in stages:
            code = run_stage(*stage, directory)
            first_failure = first_failure or code
    except KeyboardInterrupt:
        return 130
    return first_failure


if __name__ == '__main__':
    sys.exit(main())
