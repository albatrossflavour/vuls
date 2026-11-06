"""vuls-mark-complete records the run a scan just finished, for readers on other schedules."""

import os
import subprocess
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "files" / "vuls-mark-complete"


def run(results, marker):
    return subprocess.run([str(SCRIPT), str(results), str(marker)], capture_output=True, text=True)


def test_records_the_newest_run_directory(tmp_path):
    results = tmp_path / "results"
    older, newer = results / "2026-11-01T22-00-00+1100", results / "2026-11-08T22-00-00+1100"
    older.mkdir(parents=True)
    newer.mkdir()
    os.utime(older, (1_000, 1_000))
    os.utime(newer, (2_000, 2_000))
    marker = tmp_path / "last-complete-run"

    proc = run(results, marker)

    assert proc.returncode == 0, proc.stderr
    assert marker.read_text() == f"{newer}\n"
    assert not (tmp_path / "last-complete-run.tmp").exists()


def test_ignores_a_symlink_to_a_run(tmp_path):
    results = tmp_path / "results"
    real = results / "2026-11-01T22-00-00+1100"
    real.mkdir(parents=True)
    os.utime(real, (1_000, 1_000))
    (results / "current").symlink_to(real)
    marker = tmp_path / "last-complete-run"

    assert run(results, marker).returncode == 0
    assert marker.read_text() == f"{real}\n"


def test_with_no_runs_fails_and_keeps_the_previous_record(tmp_path):
    results = tmp_path / "results"
    results.mkdir()
    marker = tmp_path / "last-complete-run"
    marker.write_text("/var/lib/vuls/results/previous\n")

    proc = run(results, marker)

    assert proc.returncode != 0
    assert "no run" in proc.stderr
    assert marker.read_text() == "/var/lib/vuls/results/previous\n"


def test_keeps_a_copy_of_the_configuration_the_run_used(tmp_path):
    results = tmp_path / "results"
    run_dir = results / "2026-11-08T22-00-00+1100"
    run_dir.mkdir(parents=True)
    config = tmp_path / "config.toml"
    config.write_text('[servers."a.example.com"]\nhost = "192.0.2.1"\n')
    windows = tmp_path / "windows.json"
    windows.write_text('[{"certname": "w.example.com"}]')
    marker = tmp_path / "last-complete-run"

    proc = subprocess.run([str(SCRIPT), str(results), str(marker), str(config), str(windows)],
                          capture_output=True, text=True)

    assert proc.returncode == 0, proc.stderr
    assert (run_dir / ".scanned" / "config.toml").read_text() == config.read_text()
    assert (run_dir / ".scanned" / "windows.json").read_text() == windows.read_text()
    assert marker.read_text() == f"{run_dir}\n"
