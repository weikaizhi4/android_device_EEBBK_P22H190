import hashlib
import pathlib
import sys

EXPECTED_SHA256 = "97f9d8e99787331949b5d145d49b5aae1850f0526efc8f4f580ad3981cb6f50b"
PATCHES = {
    0x3CFF04: (bytes.fromhex("f6 03 1f 2a"), bytes.fromhex("36 00 80 52")),
    0x3CFF38: (bytes.fromhex("61 00 00 54"), bytes.fromhex("01 00 00 14")),
}

def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} LIBGLES_MALI.SO", file=sys.stderr)
        return 2

    path = pathlib.Path(sys.argv[1])
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()

    if digest == EXPECTED_SHA256:
        pass
    else:
        for offset, (original, replacement) in PATCHES.items():
            if data[offset:offset + len(replacement)] not in (original, replacement):
                raise SystemExit(
                    f"unsupported libGLES_mali.so: {path} sha256={digest} "
                    f"offset=0x{offset:x} bytes={data[offset:offset + len(replacement)].hex()}"
                )

    patched = bytearray(data)
    for offset, (original, replacement) in PATCHES.items():
        current = bytes(patched[offset:offset + len(original)])
        if current == original:
            patched[offset:offset + len(replacement)] = replacement
        elif current != replacement:
            raise SystemExit(
                f"unexpected bytes in {path} at 0x{offset:x}: {current.hex()}"
            )

    if patched != data:
        path.write_bytes(patched)

    print(f"patched Mali dataspace fallback: {path}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
