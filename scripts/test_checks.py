"""Regression checks for the runner itself; no Flutter/Node/device required."""
import contextlib
import io
import json
import sys
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

import checks


def events(*items):
    return '\n'.join(json.dumps(item) for item in items)


class ChecksTest(unittest.TestCase):
    def test_flutter_counts_real_tests_once_and_ignores_hidden_loader(self):
        done = dict(type='testDone', testID=1, result='success', skipped=False, hidden=False)
        output = events(dict(type='testDone', testID=0, result='success', hidden=True),
                        done, done,
                        dict(type='testDone', testID=2, result='success', skipped=True),
                        dict(type='done', success=True))
        counts, code, _, _ = checks.checked_result('flutter', output, 0)
        self.assertEqual(counts, dict(passed=1, failed=0, skipped=1))
        self.assertEqual(code, 0)

    def test_flutter_failed_test_keeps_name_error_and_stack(self):
        output = events(dict(type='testStart', test=dict(id=7, name='critical claim race')),
                        dict(type='error', testID=7, error='double reward', stackTrace='claim.dart:42'),
                        dict(type='testDone', testID=7, result='failure'),
                        dict(type='done', success=False))
        _, code, details, _ = checks.checked_result('flutter', output, 0)
        self.assertNotEqual(code, 0)
        self.assertIn('critical claim race\ndouble reward\nclaim.dart:42', details)

    def test_incomplete_empty_and_all_skipped_cannot_pass(self):
        for output in ('', 'compiler crashed', events(dict(type='done', success=True)),
                       events(dict(type='testDone', testID=1, skipped=True), dict(type='done', success=True)),
                       events(dict(type='testDone', testID=1, result='success'))):
            with self.subTest(output=output):
                self.assertNotEqual(checks.checked_result('flutter', output, 0)[1], 0)

    def test_node_summary_requires_complete_totals_and_counts_cancellation(self):
        report = '# tests 4\n# pass 1\n# fail 0\n# cancelled 1\n# skipped 1\n# todo 1\n'
        counts, code, _, _ = checks.checked_result('node', report, 0)
        self.assertEqual(counts, dict(passed=1, failed=1, skipped=2))
        self.assertNotEqual(code, 0)
        for bad in ('# pass 1', report.replace('# tests 4', '# tests 99'),
                    '# tests 0\n# pass 0\n# fail 0\n# cancelled 0\n# skipped 0\n# todo 0',
                    '# tests 1\n# pass 0\n# fail 0\n# cancelled 0\n# skipped 1\n# todo 0'):
            self.assertNotEqual(checks.checked_result('node', bad, 0)[1], 0)

    def test_analysis_reports_infos_but_never_ignores_warning_or_error(self):
        info = '   info • Existing lint • lib/a.dart:1:1 • lint\n1 issue found.'
        self.assertEqual(checks.checked_result('analysis', info, 0)[1], 0)
        self.assertEqual(checks.checked_result('analysis', info, 0)[0]['info'], 1)
        for severity in ('warning', 'error'):
            self.assertNotEqual(checks.checked_result('analysis', info.replace('info', severity), 0)[1], 0)
        self.assertNotEqual(checks.checked_result('analysis', 'analyzer stopped', 0)[1], 0)

    def test_real_child_failure_preserves_exit_code_and_full_log(self):
        with tempfile.TemporaryDirectory() as folder, contextlib.redirect_stdout(io.StringIO()) as console:
            path = Path(folder)
            code = checks.run_stage('Fixture', 'syntax',
                                    [sys.executable, '-c', 'print("diagnostic\\n" * 100); raise SystemExit(7)'],
                                    path, path)
            self.assertEqual(code, 7)
            self.assertEqual((path / 'syntax.log').read_text().count('diagnostic'), 100)
            self.assertLess(console.getvalue().count('diagnostic'), 100)

    def test_green_report_cannot_mask_process_failure_or_signal(self):
        output = events(dict(type='testDone', testID=1, result='success'), dict(type='done', success=True))
        self.assertEqual(checks.checked_result('flutter', output, 9)[1], 9)
        self.assertEqual(checks.checked_result('flutter', output, -15)[1], 143)

    def test_main_keeps_first_failure_and_runs_remaining_checks(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'tests').mkdir()
            (root / 'tests' / 'fixture.test.js').touch()
            with patch.object(checks, 'ROOT', root), patch.object(sys, 'argv', ['checks.py']), \
                    patch.object(checks, 'run_stage', side_effect=[7, 0]) as run:
                self.assertEqual(checks.main(), 7)
                self.assertEqual(run.call_count, 2)

    def test_successful_process_with_empty_report_is_failure(self):
        with tempfile.TemporaryDirectory() as folder, contextlib.redirect_stdout(io.StringIO()):
            path = Path(folder)
            self.assertEqual(checks.run_stage('Fixture', 'flutter',
                             [sys.executable, '-c', 'pass'], path, path), 1)

    def test_missing_executable_is_failure_with_log(self):
        with tempfile.TemporaryDirectory() as folder, contextlib.redirect_stdout(io.StringIO()):
            path = Path(folder)
            self.assertEqual(checks.run_stage('Fixture', 'syntax',
                             [str(path / 'missing-executable')], path, path), 127)
            self.assertTrue((path / 'syntax.log').read_text())


if __name__ == '__main__':
    unittest.main()
