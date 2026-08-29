#!/usr/bin/env python3
"""Compact PC/GEOS helper for coding agents.

aihelp get SYMBOL      Return a small, useful source slice.
aihelp build [PATH]    Build EC+NC and return only failures.
"""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

SOURCE_SUFFIXES = {".c", ".h", ".goc", ".goh", ".asm", ".def", ".gp", ".ui", ".uih"}
MAX_CALLERS = 3
MAX_BLOCK_LINES = 220
ERROR_RE = re.compile(
    r"(?:\b(?:fatal|error)\b|Error!\s*[A-Z]?\d+|\*\*\*|undefined|unresolved)",
    re.IGNORECASE,
)


def run(cmd, cwd=None):
    return subprocess.run(
        cmd,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        errors="replace",
    )


def looks_like_pcgeos(path):
    return path.is_dir() and all((path / name).exists() for name in ("Appl", "Library", "CInclude"))


def git_root(path):
    p = run(["git", "-C", str(path), "rev-parse", "--show-toplevel"])
    if p.returncode:
        return None
    return Path(p.stdout.strip()).resolve()


def find_repo(explicit=None):
    candidates = []
    if explicit:
        candidates.append(Path(explicit).expanduser())
    elif os.environ.get("PCGEOS_SRC"):
        candidates.append(Path(os.environ["PCGEOS_SRC"]).expanduser())
    else:
        candidates.extend((Path.cwd(), Path.home() / "pcgeos"))

    for candidate in candidates:
        root = git_root(candidate) if candidate.exists() else None
        if root and looks_like_pcgeos(root):
            return root
        candidate = candidate.resolve() if candidate.exists() else candidate
        if looks_like_pcgeos(candidate):
            return candidate
    raise RuntimeError("no PC/GEOS source tree found (use --repo or PCGEOS_SRC)")


def symbol_pattern(symbol):
    return re.compile(r"(?<![A-Za-z0-9_])" + re.escape(symbol) + r"(?![A-Za-z0-9_])")


def grep_hits(repo, symbol):
    cmd = ["git", "-C", str(repo), "grep", "-n", "-I", "-F", symbol, "--"]
    p = run(cmd)
    if p.returncode not in (0, 1):
        raise RuntimeError("git grep failed")

    exact = symbol_pattern(symbol)
    hits = []
    for raw in p.stdout.splitlines():
        try:
            path, line, text = raw.split(":", 2)
            line_no = int(line)
        except ValueError:
            continue
        if path.startswith("Installed/") or Path(path).suffix.lower() not in SOURCE_SUFFIXES:
            continue
        if exact.search(text):
            hits.append((path, line_no, text.rstrip()))
    return hits


def read_lines(repo, relpath):
    try:
        return (repo / relpath).read_text(encoding="latin-1").splitlines()
    except (OSError, UnicodeError):
        return []


def find_brace_block(lines, hit_line):
    start = hit_line - 1
    brace_line = None
    for i in range(start, min(len(lines), start + 16)):
        if "{" in lines[i]:
            brace_line = i
            break
        if ";" in lines[i]:
            return None
    if brace_line is None:
        return None

    depth = 0
    seen = False
    end = brace_line
    for i in range(brace_line, min(len(lines), brace_line + MAX_BLOCK_LINES)):
        line = lines[i]
        depth += line.count("{")
        if "{" in line:
            seen = True
        depth -= line.count("}")
        end = i
        if seen and depth <= 0:
            return start, end
    return None


def find_asm_block(lines, symbol, hit_line):
    proc_re = re.compile(
        r"^\s*" + re.escape(symbol) + r"\s+(?:proc|procedure)\b", re.IGNORECASE
    )
    end_re = re.compile(
        r"^\s*" + re.escape(symbol) + r"\s+(?:endp|endproc)\b", re.IGNORECASE
    )
    start = hit_line - 1
    if not proc_re.search(lines[start]):
        return None
    for i in range(start + 1, min(len(lines), start + MAX_BLOCK_LINES)):
        if end_re.search(lines[i]):
            return start, i
    return None


def likely_definition_line(symbol, text):
    """Cheap conservative filter before brace-block extraction."""
    m = symbol_pattern(symbol).search(text)
    if not m:
        return False
    before = text[: m.start()].strip()
    after = text[m.end() :]
    if not re.match(r"\s*\(", after):
        return False
    if any(ch in before for ch in "=.;{}"):
        return False
    if re.search(r"\b(?:return|if|while|for|switch|case)\b", before):
        return False
    return True


def classify(repo, symbol, hit):
    path, line_no, text = hit
    low = text.lower()
    suffix = Path(path).suffix.lower()

    if suffix in (".gp", ".def") and re.search(r"\bexport\b", low):
        return "EXPORT"
    if suffix == ".asm":
        if re.search(r"^\s*" + re.escape(symbol) + r"\s+(?:proc|procedure)\b", text, re.I):
            return "DEF"
        if re.search(r"\bcall\s+" + re.escape(symbol) + r"\b", text, re.I):
            return "CALL"
    if suffix in (".h", ".goh"):
        return "DECL"

    if likely_definition_line(symbol, text):
        lines = read_lines(repo, path)
        if lines and find_brace_block(lines, line_no):
            return "DEF"

    if re.search(r"\bcall\s+" + re.escape(symbol) + r"\b", text, re.I):
        return "CALL"
    if re.search(re.escape(symbol) + r"\s*\(", text):
        return "CALL"
    return "REF"

def extract_definition(repo, symbol, hit):
    path, line_no, _ = hit
    lines = read_lines(repo, path)
    if not lines:
        return None
    if Path(path).suffix.lower() == ".asm":
        span = find_asm_block(lines, symbol, line_no)
    else:
        span = find_brace_block(lines, line_no)
    if not span:
        return None
    start, end = span
    return path, start + 1, end + 1, lines[start : end + 1]


def print_location(hit):
    path, line_no, text = hit
    print(f"{path}:{line_no}")
    print("  " + text.strip())


def cmd_get(repo, symbol):
    hits = grep_hits(repo, symbol)
    if not hits:
        print(f"ERROR: symbol not found: {symbol}")
        return 1

    groups = {"DEF": [], "DECL": [], "EXPORT": [], "CALL": [], "REF": []}
    for hit in hits:
        groups[classify(repo, symbol, hit)].append(hit)

    definition = None
    for hit in groups["DEF"]:
        definition = extract_definition(repo, symbol, hit)
        if definition:
            break

    print(f"TARGET {symbol}")

    if definition:
        path, start, end, lines = definition
        print(f"\nDEF {path}:{start}-{end}")
        print("\n".join(lines))
    elif groups["DEF"]:
        print("\nDEF")
        for hit in groups["DEF"][:2]:
            print_location(hit)

    if groups["DECL"]:
        print("\nDECL")
        for hit in groups["DECL"][:3]:
            print_location(hit)

    if groups["EXPORT"]:
        print("\nEXPORT")
        for hit in groups["EXPORT"][:3]:
            print_location(hit)

    if groups["CALL"]:
        print("\nCALLERS")
        for hit in groups["CALL"][:MAX_CALLERS]:
            print_location(hit)
        omitted = len(groups["CALL"]) - MAX_CALLERS
        if omitted > 0:
            print(f"... {omitted} more callers omitted")

    if not definition and not groups["DECL"] and not groups["EXPORT"]:
        print("\nREFERENCES")
        for hit in hits[:12]:
            print_location(hit)
        if len(hits) > 12:
            print(f"... {len(hits) - 12} more references omitted")

    return 0


def resolve_input(repo, value):
    if value is None:
        p = Path.cwd().resolve()
    else:
        raw = Path(value).expanduser()
        if raw.is_absolute():
            p = raw.resolve()
        elif Path.cwd().resolve().is_relative_to(repo):
            p = (Path.cwd() / raw).resolve()
        else:
            p = (repo / raw).resolve()
    return p


def find_build_dir(repo, value):
    p = resolve_input(repo, value)
    installed = (repo / "Installed").resolve()

    if p.is_file():
        p = p.parent

    try:
        rel = p.relative_to(repo)
    except ValueError:
        raise RuntimeError("build path is outside the PC/GEOS tree")

    if not str(rel).startswith("Installed"):
        p = installed / rel

    stop = installed.parent
    while p != stop:
        if p.is_dir() and ((p / "Makefile").exists() or (p / "makefile").exists()):
            return p
        if p == installed:
            break
        p = p.parent

    raise RuntimeError("no matching Installed build directory with Makefile found")


def build_once(build_dir, nc):
    cmd = ["pmake"]
    if nc:
        cmd.append("-n")
    cmd += ["-L", "4"]
    try:
        return run(cmd, cwd=build_dir), "NC" if nc else "EC"
    except FileNotFoundError:
        raise RuntimeError("pmake not found")


def diagnostic_lines(output):
    lines = output.splitlines()
    selected = []
    for i, line in enumerate(lines):
        if ERROR_RE.search(line):
            # Keep a continuation line when the compiler prints source/detail below it.
            selected.append(line.rstrip())
            if i + 1 < len(lines):
                nxt = lines[i + 1].rstrip()
                if nxt and (nxt.startswith((" ", "\t", "^")) or ERROR_RE.search(nxt)):
                    selected.append(nxt)
    # Stable deduplication.
    return list(dict.fromkeys(selected))


def cmd_build(repo, value, full=False):
    build_dir = find_build_dir(repo, value)
    rel = build_dir.relative_to(repo)

    for nc in (False, True):
        result, variant = build_once(build_dir, nc)
        if full:
            print(f"=== {variant} ===")
            print(result.stdout.rstrip())
        if result.returncode:
            print(f"BUILD FAILED {variant} {rel}")
            diagnostics = diagnostic_lines(result.stdout)
            if diagnostics:
                print("\n".join(diagnostics))
            else:
                tail = result.stdout.splitlines()[-20:]
                print("\n".join(tail))
            return result.returncode or 1

    if not full:
        print(f"BUILD OK {rel}")
    return 0


def parser():
    p = argparse.ArgumentParser(
        prog="aihelp",
        description="Compact PC/GEOS source/build context for coding agents.",
    )
    p.add_argument("--repo", help="PC/GEOS source tree (or use PCGEOS_SRC)")
    sub = p.add_subparsers(dest="command", required=True)

    get = sub.add_parser("get", help="return compact context for a symbol")
    get.add_argument("symbol")

    build = sub.add_parser("build", help="build EC+NC and suppress normal build noise")
    build.add_argument("path", nargs="?", help="source/build path; default: current directory")
    build.add_argument("--full", action="store_true", help="show complete build output")
    return p


def main():
    args = parser().parse_args()
    try:
        repo = find_repo(args.repo)
        if args.command == "get":
            return cmd_get(repo, args.symbol)
        if args.command == "build":
            return cmd_build(repo, args.path, args.full)
    except RuntimeError as exc:
        print(f"ERROR: {exc}")
        return 3
    return 2


if __name__ == "__main__":
    sys.exit(main())
