import sys
from pathlib import Path

DEVICE_TAG = '<speaker device="0x2">'
BLOCK_END = "</speaker>"
ON_ANCHOR = '<ctl name="HPR Mixer DACRHPR Switch" val="1" />'
OFF_ANCHOR = '<ctl name="HPR Mixer DACRHPR Switch" val="0" />'
ON_LINE = '<ctl name="HPR Pin Switch" val="1" />'
OFF_LINE = '<ctl name="HPR Pin Switch" val="0" />'


def indent_of(line):
    return line[: len(line) - len(line.lstrip())]


def insert_after(text, anchor, addition, description):
    index = text.find(anchor)
    if index < 0:
        raise SystemExit(f"cannot locate {description}")
    end = text.index("\n", index) + 1
    line = text[text.rindex("\n", 0, index) + 1:end]
    return text[:end] + indent_of(line) + addition + "\n" + text[end:]


def patch(path):
    text = path.read_text(encoding="utf-8")

    start = text.find(DEVICE_TAG)
    if start < 0:
        raise SystemExit(f"{path}: speaker device block not found")
    end = text.find(BLOCK_END, start)
    if end < 0:
        raise SystemExit(f"{path}: unterminated speaker device block")

    block = text[start:end]
    if "HPR Pin Switch" in block:
        print(f"already patched: {path}")
        return 0

    on_index = block.find("<on>")
    off_index = block.find("<off>")
    if on_index < 0 or off_index < 0 or off_index < on_index:
        raise SystemExit(f"{path}: unexpected speaker block layout")

    on_part = block[:off_index]
    off_part = block[off_index:]

    on_part = insert_after(on_part, ON_ANCHOR, ON_LINE, "speaker on anchor")
    off_part = insert_after(off_part, OFF_ANCHOR, OFF_LINE, "speaker off anchor")

    path.write_text(text[:start] + on_part + off_part + text[end:], encoding="utf-8")
    print(f"patched {path}")
    return 0


def main():
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} AUDIO_ROUTE.XML", file=sys.stderr)
        return 2
    return patch(Path(sys.argv[1]))


if __name__ == "__main__":
    raise SystemExit(main())
