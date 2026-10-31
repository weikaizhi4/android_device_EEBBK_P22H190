import struct
import sys
from pathlib import Path

PT_LOAD = 1
PT_PHDR = 6

def repair(path: Path) -> bool:
    try:
        data = bytearray(path.read_bytes())
    except OSError:
        return False

    if len(data) < 16 or data[:4] != b"\x7fELF":
        return False

    elf_class = data[4]
    if elf_class == 2:
        ehdr = struct.Struct("<16sHHIQQQIHHHHHH")
        phdr = struct.Struct("<IIQQQQQQ")
        phoff_off, phentsize_off, phnum_off = 32, 54, 56
        offset_index, vaddr_index, paddr_index, filesz_index = 2, 3, 4, 5
        vaddr_byte_offset, paddr_byte_offset = 16, 24
    elif elf_class == 1:
        ehdr = struct.Struct("<16sHHIIIIIHHHHHH")
        phdr = struct.Struct("<IIIIIIII")
        phoff_off, phentsize_off, phnum_off = 28, 42, 44
        offset_index, vaddr_index, paddr_index, filesz_index = 1, 2, 3, 4
        vaddr_byte_offset, paddr_byte_offset = 8, 12
    else:
        return False

    if len(data) < ehdr.size:
        return False
    phoff = struct.unpack_from("<Q" if elf_class == 2 else "<I", data, phoff_off)[0]
    phentsize = struct.unpack_from("<H", data, phentsize_off)[0]
    phnum = struct.unpack_from("<H", data, phnum_off)[0]
    if phentsize < phdr.size or phoff + phentsize * phnum > len(data):
        return False

    entries = []
    for index in range(phnum):
        offset = phoff + index * phentsize
        values = phdr.unpack_from(data, offset)
        entries.append((offset, values))

    loads = [values for _, values in entries if values[0] == PT_LOAD]
    changed = False
    for offset, values in entries:
        if values[0] != PT_PHDR:
            continue
        phdr_offset = values[offset_index]
        phdr_filesz = values[filesz_index]
        containing_load = None
        for load in loads:
            load_offset = load[offset_index]
            load_filesz = load[filesz_index]
            if load_offset <= phdr_offset and phdr_offset + phdr_filesz <= load_offset + load_filesz:
                containing_load = load
                break
        if containing_load is None:
            continue

        load_offset = containing_load[offset_index]
        load_vaddr = containing_load[vaddr_index]
        expected = load_vaddr + phdr_offset - load_offset
        current_vaddr = values[vaddr_index]
        current_paddr = values[paddr_index]
        if current_vaddr == expected and current_paddr == expected:
            continue

        integer_format = "<Q" if elf_class == 2 else "<I"
        struct.pack_into(integer_format, data, offset + vaddr_byte_offset, expected)
        struct.pack_into(integer_format, data, offset + paddr_byte_offset, expected)
        changed = True

    if changed:
        path.write_bytes(data)
    return changed

def main() -> int:
    changed = 0
    for root in sys.argv[1:]:
        path = Path(root)
        paths = path.rglob("*") if path.is_dir() else [path]
        for candidate in paths:
            if candidate.is_file() and repair(candidate):
                print(candidate)
                changed += 1
    print(f"fixed {changed} ELF PT_PHDR entr{'y' if changed == 1 else 'ies'}", file=sys.stderr)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
