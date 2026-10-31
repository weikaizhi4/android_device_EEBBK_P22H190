import argparse
import hashlib
import struct
from pathlib import Path

from elftools.elf.elffile import ELFFile

ORIGINAL_SHA256 = "4839f6ed631cfb588f27ef3c2456679b2c5782ba77895dd77db1dd4fe8878b32"
OLD_PATH = b"/mnt/vendor/socko/sprdwl_ng.ko\0"
NEW_PATH = b"/vendor/lib/modules/sprdwl_ng.ko\0"
MODULE_NAME = b"sprdwl_ng\0"
IFACE_PATH = b"/sys/class/net/wlan0\0"

def adrp(reg, pc, target):
    pages = (target >> 12) - (pc >> 12)
    if not -(1 << 20) <= pages < (1 << 20):
        raise ValueError("ADRP target out of range")
    imm = pages & ((1 << 21) - 1)
    return 0x90000000 | ((imm & 3) << 29) | ((imm >> 2) << 5) | reg

def add(reg, offset):
    return 0x91000000 | (offset << 10) | (reg << 5) | reg

def bl(pc, target):
    if (target - pc) % 4:
        raise ValueError("unaligned branch")
    return 0x94000000 | (((target - pc) // 4) & ((1 << 26) - 1))

def patch(path):
    data = bytearray(path.read_bytes())
    digest = hashlib.sha256(data).hexdigest()
    if digest != ORIGINAL_SHA256:
        raise ValueError(f"unexpected Wi-Fi HAL SHA-256: {digest}")

    with path.open("rb") as source:
        elf = ELFFile(source)
        if elf["e_machine"] != "EM_AARCH64":
            raise ValueError("expected AArch64 ELF")
        text = elf.get_section_by_name(".text")
        rodata = elf.get_section_by_name(".rodata")
        symbols = elf.get_section_by_name(".dynsym")
        if not text or not rodata or not symbols:
            raise ValueError("missing ELF sections")
        if text["sh_addr"] != text["sh_offset"] or rodata["sh_addr"] != rodata["sh_offset"]:
            raise ValueError("unexpected ELF section layout")

        def symbol(name, address):
            matches = symbols.get_symbol_by_name(name)
            if not matches or len(matches) != 1 or matches[0]["st_value"] != address:
                raise ValueError(f"unexpected symbol: {name}")
            return matches[0]

        loaded = symbol("is_wifi_driver_loaded", 0x3E1C4)
        loader = symbol("wifi_load_driver", 0x3E3A0)
        unload = symbol("wifi_unload_driver", 0x3E5D4)
        if data[0x161F1:0x161F1 + len(OLD_PATH)] != OLD_PATH:
            raise ValueError("unexpected factory module path")
        if data[0x16210:0x16211] != b"\0" or data[0x16211:0x16211 + len(MODULE_NAME)] != MODULE_NAME:
            raise ValueError("unexpected module name")
        if data[0x161E3:0x161F1] != b"/proc/modules\0":
            raise ValueError("unexpected module status path")
        if data[0x11BDB:0x11BDB + len(IFACE_PATH)] != IFACE_PATH:
            raise ValueError("unexpected WLAN interface path")
        if data[0x11BF0:0x11BF2] != b"r\0":
            raise ValueError("unexpected fopen mode")

        start = loaded["st_value"]
        check = [
            0xA9BF7BFD, 0x910003FD,
            adrp(0, start + 8, 0x11BDB), add(0, 0xBDB),
            adrp(1, start + 16, 0x11BF0), add(1, 0xBF0),
            bl(start + 24, 0x3F030), 0xB40000A0,
            bl(start + 32, 0x3F050), 0x52800020,
            0xA8C17BFD, 0xD65F03C0,
            0x2A1F03E0, 0xA8C17BFD, 0xD65F03C0,
        ]
        check = struct.pack("<" + "I" * len(check), *check)
        if len(check) > loaded["st_size"]:
            raise ValueError("driver status replacement too large")
        data[start:start + len(check)] = check

        data[0x161E3:0x161E3 + len(MODULE_NAME)] = MODULE_NAME
        data[0x161F1:0x161F1 + len(NEW_PATH)] = NEW_PATH
        old_ref = struct.pack("<I", add(0, 0x211))
        new_ref = struct.pack("<I", add(0, 0x1E3))
        first = unload["st_value"]
        last = first + unload["st_size"]
        original_unload = bytes(data[first:last])
        if original_unload.count(old_ref) != 10:
            raise ValueError("unexpected module name references in unload function")
        data[first:last] = original_unload.replace(old_ref, new_ref)
        if data[loader["st_value"] + 0x34:loader["st_value"] + 0x38] != struct.pack("<I", add(19, 0x1F1)):
            raise ValueError("unexpected module path reference in load function")

    path.write_bytes(data)
    print(f"patched {path}: {hashlib.sha256(data).hexdigest()}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    patch(parser.parse_args().path)
