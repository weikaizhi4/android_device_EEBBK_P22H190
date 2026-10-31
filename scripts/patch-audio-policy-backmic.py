import pathlib
import sys

ITEM = "<item>Built-In Back Mic</item>"
MARKER = f"<!-- APERTUREFIX {ITEM} -->"

def scan_comment_state(line: str, in_comment: bool) -> bool:
    i = 0
    while i < len(line):
        if in_comment:
            end = line.find("-->", i)
            if end < 0:
                return True
            in_comment = False
            i = end + 3
        else:
            start = line.find("<!--", i)
            if start < 0:
                return False
            in_comment = True
            i = start + 4
    return in_comment

def patch_text(text: str) -> tuple[str, int, int]:
    kept, detached, already = [], 0, 0
    in_comment = False

    for line in text.splitlines(keepends=True):
        if line.strip() == ITEM:
            if in_comment:
                already += 1
            else:
                indent = line[: len(line) - len(line.lstrip())]
                line = f"{indent}{MARKER}\n"
                detached += 1
        kept.append(line)
        in_comment = scan_comment_state(line, in_comment)

    return "".join(kept), detached, already

def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} AUDIO_POLICY_CONFIGURATION.XML", file=sys.stderr)
        return 2

    path = pathlib.Path(sys.argv[1])
    original = path.read_text(encoding="utf-8")

    patched, detached, already = patch_text(original)

    if detached == 0:
        note = f" ({already} already inside a comment)" if already else ""
        print(f"no active {ITEM} to detach: {path}{note}")
        return 0

    path.write_text(patched, encoding="utf-8")
    print(f"detached {ITEM} ({detached}x): {path}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
