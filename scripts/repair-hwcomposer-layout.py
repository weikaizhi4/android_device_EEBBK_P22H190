import struct
import sys
from pathlib import Path

PT_LOAD = 1
PT_DYNAMIC = 2
DT_STRTAB = 5

LOAD_A_OFFSET = 0xA0000
LOAD_B_OFFSET = 0xB0000
LOAD_A_VADDR = 0xF0000
LOAD_B_VADDR = 0x100000

EHDR = struct.Struct("<16sHHIQQQIHHHHHH")
PHDR = struct.Struct("<IIQQQQQQ")
DYN = struct.Struct("<QQ")

def fail(message: str) -> None:
    raise ValueError(message)

def repair(path: Path) -> bool:
    data = bytearray(path.read_bytes())
    if len(data) < EHDR.size or data[:7] != b"\x7fELF\x02\x01\x01":
        fail("expected a 64-bit little-endian ELF")

    phoff = struct.unpack_from("<Q", data, 32)[0]
    phentsize = struct.unpack_from("<H", data, 54)[0]
    phnum = struct.unpack_from("<H", data, 56)[0]
    if phentsize != PHDR.size or phoff + phentsize * phnum > len(data):
        fail("invalid program-header table")

    program_headers = []
    for index in range(phnum):
        offset = phoff + index * phentsize
        program_headers.append((offset, list(PHDR.unpack_from(data, offset))))

    load_a = load_b = dynamic = None
    repaired_load_a = repaired_load_b = repaired_dynamic = None
    for offset, values in program_headers:
        p_type, _, p_offset, p_vaddr, _, p_filesz, _, _ = values
        if p_type == PT_LOAD and p_offset == LOAD_A_OFFSET and p_vaddr == 0:
            load_a = (offset, values)
        elif p_type == PT_LOAD and p_offset == LOAD_A_OFFSET and p_vaddr == LOAD_A_VADDR:
            repaired_load_a = (offset, values)
        elif p_type == PT_LOAD and p_offset == LOAD_B_OFFSET and p_vaddr == 0:
            load_b = (offset, values)
        elif p_type == PT_LOAD and p_offset == LOAD_B_OFFSET and p_vaddr == LOAD_B_VADDR:
            repaired_load_b = (offset, values)
        elif p_type == PT_DYNAMIC and p_offset == LOAD_B_OFFSET and p_vaddr == 0:
            dynamic = (offset, values)
        elif p_type == PT_DYNAMIC and p_offset == LOAD_B_OFFSET and p_vaddr == LOAD_B_VADDR:
            repaired_dynamic = (offset, values)

    if all((load_a, load_b, dynamic)):
        mappings_need_repair = True
        dynamic_offset, dynamic_header = dynamic
    elif all((repaired_load_a, repaired_load_b, repaired_dynamic)):
        mappings_need_repair = False
        dynamic_offset, dynamic_header = repaired_dynamic
    else:
        fail("unexpected HWC dynamic mapping")

    dynamic_size = dynamic_header[5]
    if dynamic_size % DYN.size or LOAD_B_OFFSET + dynamic_size > len(data):
        fail("invalid dynamic table")

    strtab_seen = False
    for offset in range(LOAD_B_OFFSET, LOAD_B_OFFSET + dynamic_size, DYN.size):
        tag, value = DYN.unpack_from(data, offset)
        if tag == DT_STRTAB:
            if value not in (0x300, LOAD_B_VADDR + 0x300):
                fail("unexpected DT_STRTAB address")
            DYN.pack_into(data, offset, tag, LOAD_B_VADDR + 0x300)
            strtab_seen = True
            break
        if tag == 0:
            break
    if not strtab_seen:
        fail("DT_STRTAB not found")

    if mappings_need_repair:
        for offset, values, vaddr in (
            (load_a[0], load_a[1], LOAD_A_VADDR),
            (load_b[0], load_b[1], LOAD_B_VADDR),
            (dynamic_offset, dynamic_header, LOAD_B_VADDR),
        ):
            values[3] = vaddr
            values[4] = vaddr
            PHDR.pack_into(data, offset, *values)

    path.write_bytes(data)
    return True

def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} <hwcomposer.ums512.so>", file=sys.stderr)
        return 2
    try:
        repair(Path(sys.argv[1]))
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
