import argparse
import struct
from pathlib import Path

from elftools.elf.elffile import ELFFile

NEW_MODULE_PATH = b"/vendor/lib/modules/sprdwl_ng.ko\0"
OLD_MODULE_PATH = b"/mnt/vendor/socko/sprdwl_ng.ko\0"
MODULE_NAME = b"sprdwl_ng\0"
PROC_MODULES = b"/proc/modules\0"
IFACE_PATH = b"/sys/class/net/wlan0\0"
READ_MODE = b"r\0"

STATUS_SYMBOL = "is_wifi_driver_loaded"
LOAD_SYMBOL = "wifi_load_driver"
UNLOAD_SYMBOL = "wifi_unload_driver"
PLT_SYMBOLS = ("fopen", "fclose")


def adrp(reg, pc, target):
    pages = (target >> 12) - (pc >> 12)
    if not -(1 << 20) <= pages < (1 << 20):
        raise SystemExit("ADRP target out of range")
    immediate = pages & ((1 << 21) - 1)
    return 0x90000000 | ((immediate & 3) << 29) | ((immediate >> 2) << 5) | reg


def add_immediate(reg, offset):
    return 0x91000000 | ((offset & 0xFFF) << 10) | (reg << 5) | reg


def branch_link(pc, target):
    if (target - pc) % 4:
        raise SystemExit("unaligned branch target")
    return 0x94000000 | (((target - pc) // 4) & ((1 << 26) - 1))


def scan_adrp_add(data, start, end):
    results = []
    for offset in range(start, end - 4, 4):
        first = struct.unpack_from("<I", data, offset)[0]
        if (first & 0x9F000000) != 0x90000000:
            continue
        second = struct.unpack_from("<I", data, offset + 4)[0]
        if (second & 0xFF800000) != 0x91000000:
            continue
        if (first & 0x1F) != (second & 0x1F):
            continue
        immediate = (((first >> 5) & 0x7FFFF) << 2) | ((first >> 29) & 3)
        if immediate & (1 << 20):
            immediate -= 1 << 21
        page = (offset & ~0xFFF) + (immediate << 12)
        shift = (second >> 22) & 1
        target = page + (((second >> 10) & 0xFFF) << (12 if shift else 0))
        results.append((offset, target))
    return results


def plt_addresses(path):
    addresses = {}
    with path.open("rb") as source:
        elf = ELFFile(source)
        dynsym = elf.get_section_by_name(".dynsym")
        plt = elf.get_section_by_name(".plt")
        rela = elf.get_section_by_name(".rela.plt") or elf.get_section_by_name(".rel.plt")
        if not dynsym or not plt or not rela:
            raise SystemExit(f"{path}: missing PLT metadata")
        for index, relocation in enumerate(rela.iter_relocations()):
            name = dynsym.get_symbol(relocation["r_info_sym"]).name
            if name in PLT_SYMBOLS:
                addresses[name] = plt["sh_addr"] + 32 + 16 * index
    missing = [name for name in PLT_SYMBOLS if name not in addresses]
    if missing:
        raise SystemExit(f"{path}: unresolved PLT symbols {missing}")
    return addresses


def symbol_addresses(path):
    wanted = {STATUS_SYMBOL, LOAD_SYMBOL, UNLOAD_SYMBOL}
    found = {}
    with path.open("rb") as source:
        elf = ELFFile(source)
        dynsym = elf.get_section_by_name(".dynsym")
        if not dynsym:
            raise SystemExit(f"{path}: missing .dynsym")
        for symbol in dynsym.iter_symbols():
            if symbol.name in wanted:
                found[symbol.name] = (symbol["st_value"], symbol["st_size"])
    missing = [name for name in wanted if name not in found]
    if missing:
        raise SystemExit(f"{path}: missing symbols {missing}")
    return found


def locate(data, needle, description):
    offset = data.find(needle)
    if offset < 0:
        raise SystemExit(f"cannot locate {description}")
    return offset


def status_stub(function, fopen, fclose, iface, mode):
    program = [
        0xA9BF7BFD,
        0x910003FD,
        adrp(0, function + 8, iface),
        add_immediate(0, iface),
        adrp(1, function + 16, mode),
        add_immediate(1, mode),
        branch_link(function + 24, fopen),
        0xB40000A0,
        branch_link(function + 32, fclose),
        0x52800020,
        0xA8C17BFD,
        0xD65F03C0,
        0x2A1F03E0,
        0xA8C17BFD,
        0xD65F03C0,
    ]
    return struct.pack("<" + "I" * len(program), *program)


def patch(path):
    data = bytearray(path.read_bytes())
    if data[:4] != b"\x7fELF":
        raise SystemExit(f"{path}: not an ELF file")

    with path.open("rb") as source:
        elf = ELFFile(source)
        text = elf.get_section_by_name(".text")
        if not text:
            raise SystemExit(f"{path}: missing .text")
        if text["sh_addr"] != text["sh_offset"]:
            raise SystemExit(f"{path}: .text is not identity mapped")
        text_start = text["sh_addr"]
        text_end = text_start + text["sh_size"]

    symbols = symbol_addresses(path)
    plt = plt_addresses(path)

    has_new_path = NEW_MODULE_PATH in data
    has_old_path = OLD_MODULE_PATH in data
    has_proc = PROC_MODULES in data

    if has_old_path and has_proc:
        path_offset = data.find(OLD_MODULE_PATH)
        name_offset = data.find(MODULE_NAME)
        status_offset = data.find(PROC_MODULES)
        if name_offset < 0:
            raise SystemExit(f"{path}: cannot locate module name")
        need = path_offset + len(NEW_MODULE_PATH)
        limit = name_offset + len(MODULE_NAME)
        if need > limit:
            raise SystemExit(f"{path}: no room for the new module path")
        if len(MODULE_NAME) > len(PROC_MODULES):
            raise SystemExit(f"{path}: module name does not fit the freed slot")
        if (status_offset >> 12) != (name_offset >> 12):
            raise SystemExit(f"{path}: module name slot is in a different page")
    elif has_new_path and not has_proc:
        print(f"already patched: {path}")
        return 0
    else:
        raise SystemExit(f"{path}: unrecognised module path layout")

    iface_offset = locate(data, IFACE_PATH, "WLAN interface path")
    mode_offset = iface_offset + len(IFACE_PATH)
    if data[mode_offset:mode_offset + len(READ_MODE)] != READ_MODE:
        raise SystemExit(f"{path}: fopen mode does not follow the interface path")

    references = [entry for entry in scan_adrp_add(data, text_start, text_end)
                  if entry[1] == name_offset]
    if not references:
        raise SystemExit(f"{path}: no references to the module name")

    data[status_offset:status_offset + len(MODULE_NAME)] = MODULE_NAME
    data[path_offset:path_offset + len(NEW_MODULE_PATH)] = NEW_MODULE_PATH

    for offset, _ in references:
        instruction = struct.unpack_from("<I", data, offset + 4)[0]
        immediate = status_offset & 0xFFF
        instruction = (instruction & ~(0xFFF << 10)) | (immediate << 10)
        struct.pack_into("<I", data, offset + 4, instruction)

    function, size = symbols[STATUS_SYMBOL]
    stub = status_stub(function, plt["fopen"], plt["fclose"], iface_offset, mode_offset)
    if len(stub) > size:
        raise SystemExit(f"{path}: {STATUS_SYMBOL} is too small for the replacement")
    data[function:function + len(stub)] = stub

    load = symbols[LOAD_SYMBOL]
    unload = symbols[UNLOAD_SYMBOL]
    for name, entry in ((LOAD_SYMBOL, load), (UNLOAD_SYMBOL, unload)):
        for offset, target in scan_adrp_add(data, entry[0], entry[0] + entry[1]):
            if target in (path_offset, status_offset):
                continue
            if target == name_offset:
                raise SystemExit(f"{path}: {name} still points at the old module name")

    path.write_bytes(data)
    print(f"patched {path}")
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    return patch(parser.parse_args().path)


if __name__ == "__main__":
    raise SystemExit(main())
