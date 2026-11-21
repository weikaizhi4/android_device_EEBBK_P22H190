import struct
import sys
from pathlib import Path

SITE_A_ANCHOR = (0x2A1F03F6, 0x52A20008, 0x6B08029F)
SITE_A_BEFORE = 0x2A1F03F6
SITE_A_AFTER = 0x52800036

SITE_B_ANCHOR = (0x52A10008, 0x6B08029F, None, 0x321002D6)
SITE_B_AFTER = 0x14000001


def find_sequence(data, pattern):
    needle = struct.pack("<I", pattern[0])
    size = len(pattern) * 4
    matches = []
    offset = data.find(needle)
    while offset >= 0:
        if offset % 4 == 0 and offset + size <= len(data):
            window = struct.unpack_from("<" + "I" * len(pattern), data, offset)
            if all(expected is None or expected == actual
                   for expected, actual in zip(pattern, window)):
                matches.append(offset)
        offset = data.find(needle, offset + 4)
    return matches


def patch(path):
    data = bytearray(path.read_bytes())
    if data[:4] != b"\x7fELF":
        raise SystemExit(f"{path}: not an ELF file")

    before_a = find_sequence(data, SITE_A_ANCHOR)
    after_a = find_sequence(data, (SITE_A_AFTER,) + SITE_A_ANCHOR[1:])
    before_b = find_sequence(data, SITE_B_ANCHOR)
    after_b = find_sequence(data, (SITE_B_ANCHOR[0], SITE_B_ANCHOR[1], SITE_B_AFTER, SITE_B_ANCHOR[3]))

    if len(before_a) == 1 and len(before_b) == 1:
        struct.pack_into("<I", data, before_a[0], SITE_A_AFTER)
        struct.pack_into("<I", data, before_b[0] + 8, SITE_B_AFTER)
    elif len(after_a) == 1 and len(after_b) == 1:
        print(f"already patched: {path}")
        return 0
    else:
        raise SystemExit(
            f"{path}: cannot locate patch sites "
            f"(a-before={len(before_a)} a-after={len(after_a)} "
            f"b-before={len(before_b)} b-after={len(after_b)})"
        )

    path.write_bytes(data)
    print(f"patched {path}")
    return 0


def main():
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} LIBGLES_MALI.SO", file=sys.stderr)
        return 2
    return patch(Path(sys.argv[1]))


if __name__ == "__main__":
    raise SystemExit(main())
