#!/usr/bin/env python3
"""Check build diagnostics without compiling or running PC/GEOS."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


script = Path(__file__).resolve().parents[1] / "aihelp.py"
with tempfile.TemporaryDirectory(prefix="aihelp-check-") as temporary:
    repo = Path(temporary)
    for name in ("Appl", "Library", "CInclude", "Bin", "Installed/Appl/Demo"):
        (repo / name).mkdir(parents=True)
    (repo / "Installed/Appl/Demo/Makefile").touch()
    pmake = repo / "Bin/pmake"
    pmake.write_text(
        f"#!{sys.executable}\n"
        "import json, os, sys\n"
        "nc = '-n' in sys.argv[1:]\n"
        "assert sys.argv[1:] == (['-n'] if nc else []) + ['-L', '4']\n"
        "code, output = json.loads(os.environ['AIHELP_CHECK_RESULTS'])[nc]\n"
        "sys.stderr.write(output)\n"
        "sys.exit(code)\n",
        encoding="ascii",
    )
    pmake.chmod(0o755)
    env = dict(os.environ, PATH=str(repo / "Bin") + os.pathsep + os.environ["PATH"])

    def build(ec, nc=(0, ""), full=False):
        env["AIHELP_CHECK_RESULTS"] = json.dumps([ec, nc])
        command = [sys.executable, str(script), "--repo", str(repo), "build", "Appl/Demo"]
        if full:
            command.append("--full")
        return subprocess.run(command, cwd=repo, env=env, text=True, capture_output=True)

    ec = (
        "normal EC build output\n"
        'warning: file "demo.asm", line 10: jump can be shortened\n'
        "    jmp target\n"
        "    ^ location\n"
        "    further detail\n"
        "file demo.goc, line 20 Warning: old syntax\n"
        "file demo.ui, line 30: Warning: missing localization\n"
        "demo.goc(40): Warning! W123: unused variable\n"
        "demo.goc(41): Note! N456: declared here\n"
        "demo.c:42: note: related declaration\n"
        "WARN: linker detail\n"
        "NOTES: related information\n"
        "normal EC build end\n"
    )
    nc = "normal NC build output\nWarning: fixed size should be reduced\nNote: NC detail\n"
    result = build((0, ec), (0, nc))
    assert result.returncode == 0, result
    for line in (ec + nc).splitlines():
        if not line.startswith("normal"):
            assert line in result.stdout, (line, result.stdout)
    assert "normal" not in result.stdout, result.stdout
    assert result.stdout.index("=== EC ===") < result.stdout.index("=== NC ===")
    assert "BUILD OK" not in result.stdout

    # Any diagnostic in either variant suppresses the clean-build message.
    for diagnostic in ("Note: detail\n", "Warning: detail\n", "Error: detail\n"):
        for variant in (0, 1):
            outputs = [(0, ""), (0, "")]
            outputs[variant] = (0, diagnostic)
            result = build(*outputs)
            assert result.returncode == 0 and diagnostic in result.stdout
            assert "BUILD OK" not in result.stdout

    # No diagnostic may disappear at the old 80-line limit.
    warnings = "".join(f"warning: message {i}\n" for i in range(100))
    result = build((0, warnings))
    assert result.returncode == 0 and result.stdout.count("warning: message") == 100
    result = build((2, warnings))
    assert result.returncode == 2 and result.stdout.count("warning: message") == 100

    # Stop after an EC failure and keep errors, warnings and independent notes.
    failure = "Warning: before failure\nError! E123: failed\nNote: failure detail\n"
    result = build((2, failure), (0, "Note: NC must not run\n"))
    assert result.returncode == 2 and "BUILD FAILED EC" in result.stdout
    assert failure in result.stdout and "NC must not run" not in result.stdout

    result = build((0, "Note: EC detail\n"), (3, failure))
    assert result.returncode == 3 and "BUILD FAILED NC" in result.stdout
    assert "Note: EC detail" in result.stdout and failure in result.stdout

    # Full output includes each diagnostic once, also when a build fails.
    for code in (0, 2):
        result = build((code, ec), full=True)
        assert result.returncode == code and ec.rstrip() in result.stdout
        assert result.stdout.count("jump can be shortened") == 1

    # Keep the fallback for a failure with no recognized diagnostic.
    unknown = "".join(f"output {i}\n" for i in range(25))
    result = build((4, unknown))
    assert result.returncode == 4 and "BUILD FAILED EC" in result.stdout
    assert "output 4\n" not in result.stdout and "output 5\n" in result.stdout
    assert "output 24\n" in result.stdout

    result = build((0, "normal output\ndemo.ec: 12 lines, included 345, 0 warnings, 0 errors\n"))
    assert result.returncode == 0
    assert result.stdout == "BUILD OK Installed/Appl/Demo\n", result.stdout

print("aihelp build diagnostic checks passed")
