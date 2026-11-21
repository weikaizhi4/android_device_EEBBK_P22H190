import struct
import sys
from pathlib import Path

PT_LOAD = 1
PT_DYNAMIC = 2
PT_PHDR = 6

EHDR = struct.Struct("<16sHHIQQQIHHHHHH")
PHDR = struct.Struct("<IIQQQQQQ")


def align_up(value, alignment):
    if alignment <= 1:
        return value
    return (value + alignment - 1) // alignment * alignment


def repair(path):
    data = bytearray(path.read_bytes())
    if len(data) < EHDR.size or data[:7] != b"\x7fELF\x02\x01\x01":
        return False

    phoff = struct.unpack_from("<Q", data, 32)[0]
    phentsize = struct.unpack_from("<H", data, 54)[0]
    phnum = struct.unpack_from("<H", data, 56)[0]
    if phentsize != PHDR.size or phoff + phentsize * phnum > len(data):
        return False

    entries = []
    for index in range(phnum):
        offset = phoff + index * phentsize
        entries.append((offset, list(PHDR.unpack_from(data, offset))))

    loads = [(offset, values) for offset, values in entries if values[0] == PT_LOAD]
    broken = [(offset, values) for offset, values in loads
              if values[3] == 0 and values[2] != 0 and values[5] != 0]
    if not broken:
        return False

    occupied = []
    broken_offsets = {offset for offset, _ in broken}
    for offset, values in loads:
        if offset in broken_offsets:
            continue
        start = values[3]
        occupied.append((start, start + values[6]))

    changes = {}
    for offset, values in sorted(broken, key=lambda item: item[1][2]):
        alignment = values[7] or 0x1000
        candidate = max((end for _, end in occupied), default=0)
        candidate = align_up(candidate, alignment)
        while candidate % alignment != values[2] % alignment:
            candidate += alignment
        if candidate == 0:
            candidate = values[2]
        values[3] = candidate
        values[4] = candidate
        occupied.append((candidate, candidate + values[6]))
        changes[values[2]] = (values[5], candidate)

    for offset, values in entries:
        if values[0] == PT_LOAD:
            for broken_offset, broken_values in broken:
                if offset == broken_offset:
                    PHDR.pack_into(data, offset, *broken_values)
        elif values[0] in (PT_DYNAMIC, PT_PHDR):
            if values[3] != 0:
                continue
            for file_offset, new_vaddr in changes.values():
                if file_offset <= values[2] < file_offset + values[5]:
                    values[3] = new_vaddr + (values[2] - file_offset)
                    values[4] = values[3]
                    PHDR.pack_into(data, offset, *values)
                    break

    path.write_bytes(data)
    return True


def main():
    if len(sys.argv) < 2:
        print(f"usage: {Path(sys.argv[0]).name} ELF...", file=sys.stderr)
        return 2
    changed = 0
    for argument in sys.argv[1:]:
        target = Path(argument)
        candidates = target.rglob("*") if target.is_dir() else [target]
        for candidate in candidates:
            if candidate.is_file() and repair(candidate):
                print(candidate)
                changed += 1
    print(f"repaired {changed} file(s)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
