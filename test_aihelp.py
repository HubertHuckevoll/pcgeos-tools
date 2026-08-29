#!/usr/bin/env python3
"""Small regression checks for aihelp's source slicing heuristics."""

import tempfile
from pathlib import Path

import aihelp


def main():
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        (root / "sample.asm").write_bytes(
            b"\x0c\nFoo\tproc\tfar\r\n\tret\r\nFoo\tendp\r\n"
        )
        lines = aihelp.read_lines(root, "sample.asm")
        assert lines[0] == "\x0c"
        assert aihelp.find_asm_block(lines, "Foo", 2) == (1, 3)

        (root / "sample.goc").write_bytes(b"if (buffer = value) {\nMemAlloc(\nsize)) {\n}\n")
        assert aihelp.classify(root, "MemAlloc", ("sample.goc", 2, "MemAlloc(")) == "CALL"

    call_lines = ["if (buffer = value) {", "MemAlloc(", "size)) {", "}"]
    assert not aihelp.likely_definition_line("MemAlloc", call_lines[1], call_lines, 2)

    definition_lines = ["void", "Foo(", "int value) {", "}"]
    assert aihelp.likely_definition_line("Foo", definition_lines[1], definition_lines, 2)

    diagnostics = aihelp.diagnostic_lines(
        "warning: error-prone construct\nError! E123: bad\nError! E123: bad\n"
    )
    assert diagnostics == ["Error! E123: bad", "Error! E123: bad"]


if __name__ == "__main__":
    main()
