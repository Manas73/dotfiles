"""Tests for roles/packages/files/pty_run.py."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PTY_RUN = Path(__file__).resolve().parents[1] / "roles" / "packages" / "files" / "pty_run.py"


def run_pty(log: Path, title: str, snippet: str, regex: str = "installing") -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(PTY_RUN), str(log), title, snippet, regex, "20"],
        check=False,
        capture_output=True,
        text=True,
    )


class PtyRunTests(unittest.TestCase):
    def test_changed_when_this_run_matches(self):
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / "ansible-packages.log"
            result = run_pty(log, "t1", "echo installing foo")
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout.strip(), "STREAM_CHANGED")

    def test_ok_ignores_previous_run_in_same_log(self):
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / "ansible-packages.log"
            first = run_pty(log, "t1", "echo installing foo")
            self.assertEqual(first.stdout.strip(), "STREAM_CHANGED")
            second = run_pty(log, "t2", "echo nothing to do")
            self.assertEqual(second.returncode, 0)
            self.assertEqual(second.stdout.strip(), "STREAM_OK")

    def test_failure_dumps_this_run_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / "ansible-packages.log"
            run_pty(log, "t1", "echo installing foo")
            failed = run_pty(log, "t2", "echo boom-line; exit 7")
            self.assertEqual(failed.returncode, 7)
            self.assertIn("STREAM_FAILED", failed.stdout)
            self.assertIn("boom-line", failed.stdout)
            self.assertNotIn("installing foo", failed.stdout)

    def test_exits_when_stdin_stays_open(self):
        # Ansible keeps the module's stdin pipe open; pty.spawn on
        # Python < 3.10 (macOS) then hung after the child exited.
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / "ansible-packages.log"
            with subprocess.Popen(
                [sys.executable, str(PTY_RUN), str(log), "t1", "echo done", "installing", "20"],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                text=True,
            ) as proc:
                self.assertEqual(proc.wait(timeout=10), 0)
                out = proc.stdout.read()
            self.assertEqual(out.strip(), "STREAM_OK")

    def test_exits_when_grandchild_holds_pty(self):
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / "ansible-packages.log"
            result = subprocess.run(
                [sys.executable, str(PTY_RUN), str(log), "t1", "sleep 30 & echo installing foo", "installing", "20"],
                check=False,
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout.strip(), "STREAM_CHANGED")
