import argparse
import hashlib
import struct
from pathlib import Path

from elftools.elf.elffile import ELFFile

ORIGINAL_SHA256 = "4839f6ed631cfb588f27ef3c2456679b2c5782ba77895dd77db1dd4fe8878b32"
LIBRARY = "libeebbk_p22h190_wifi_hal.so"
SYMBOLS = {
    "is_wifi_driver_loaded": 0x3E1C4,
    "wifi_load_driver": 0x3E3A0,
    "wifi_unload_driver": 0x3E5D4,
}
WLAN_PATH = b"/sys/class/net/wlan0\0"

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
        raise ValueError("unaligned BL target")
    return 0x94000000 | (((target - pc) // 4) & ((1 << 26) - 1))

def patch(source, destination):
    data = bytearray(source.read_bytes())
    actual = hashlib.sha256(data).hexdigest()
    if actual != ORIGINAL_SHA256:
        raise ValueError(f"unexpected {source.name} SHA-256: {actual}")

    with source.open("rb") as stream:
        elf = ELFFile(stream)
        if elf["e_machine"] != "EM_AARCH64":
            raise ValueError("expected AArch64 ELF")
        text = elf.get_section_by_name(".text")
        dynsym = elf.get_section_by_name(".dynsym")
        if text is None or dynsym is None:
            raise ValueError("missing ELF sections")
        for name, address in SYMBOLS.items():
            matches = dynsym.get_symbol_by_name(name)
            if not matches or len(matches) != 1 or matches[0]["st_value"] != address:
                raise ValueError(f"unexpected symbol: {name}")
        if data[0x11BDB:0x11BDB + len(WLAN_PATH)] != WLAN_PATH:
            raise ValueError("expected wlan0 path missing")
        if data[0x11BF0:0x11BF2] != b"r\0":
            raise ValueError("expected fopen mode missing")

        def replace(name, words):
            symbol = dynsym.get_symbol_by_name(name)[0]
            address = symbol["st_value"]
            offset = text["sh_offset"] + address - text["sh_addr"]
            payload = struct.pack("<" + "I" * len(words), *words)
            if len(payload) > symbol["st_size"]:
                raise ValueError(f"replacement too large: {name}")
            data[offset:offset + len(payload)] = payload

        start = SYMBOLS["is_wifi_driver_loaded"]
        loaded = [
            0xA9BF7BFD,
            0x910003FD,
            adrp(0, start + 8, 0x11BDB),
            add(0, 0xBDB),
            adrp(1, start + 16, 0x11BF0),
            add(1, 0xBF0),
            bl(start + 24, 0x3F030),
            0xB40000A0,
            bl(start + 32, 0x3F050),
            0x52800020,
            0xA8C17BFD,
            0xD65F03C0,
            0x2A1F03E0,
            0xA8C17BFD,
            0xD65F03C0,
        ]
        replace("is_wifi_driver_loaded", loaded)
        no_module = [0x2A1F03E0, 0xD65F03C0]
        replace("wifi_load_driver", no_module)
        replace("wifi_unload_driver", no_module)

    destination.write_bytes(data)
    print(f"patched {destination} SHA-256 {hashlib.sha256(data).hexdigest()}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    patch(args.source, args.destination)
