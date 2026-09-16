"""Check 64-bit ELF LOAD/RELRO alignment in an AAB or APK (Python stdlib only).

RELRO rules follow Android Studio's PageAlignUtils.kt:
https://android.googlesource.com/platform/tools/base/+/mirror-goog-studio-main/sdk-common/src/main/java/com/android/ide/common/pagealign/PageAlignUtils.kt
For AABs, also inspect bundletool's PAGE_ALIGNMENT_16K setting. ZIP offsets in
an AAB are not the offsets of the APKs Google Play generates from it.
This is a static check, not a replacement for testing on a 16 KB device.
"""

import argparse
from pathlib import Path
import struct
import zipfile

PAGE = 16384


def elf_problems(data):
    if data[:6] != b'\x7fELF\x02\x01':
        raise ValueError('Expected a little-endian ELF64 library')
    phoff, shoff = struct.unpack_from('<QQ', data, 32)
    phsize, phnum, shsize, shnum = struct.unpack_from('<HHHH', data, 54)
    if phsize < 56 or not phnum or (shnum and shsize < 64):
        raise ValueError('Invalid ELF header table')
    headers = [struct.unpack_from('<IIQQQQQQ', data, phoff + i * phsize)
               for i in range(phnum)]
    sections = [struct.unpack_from('<IIQQQQIIQQ', data, shoff + i * shsize)
                for i in range(shnum)]
    loads = sorted((h for h in headers if h[0] == 1), key=lambda h: h[3])
    issues = []
    if not loads:
        return ['No LOAD segments']
    for load in loads:
        if load[7] < PAGE or load[7] % PAGE:
            issues.append(f'LOAD alignment {load[7]} is below/not a multiple of 16 KB')
        if (load[3] - load[2]) % PAGE:
            issues.append('LOAD file offset and virtual address disagree at 16 KB')

    def contained(segment):
        start, end = segment[3], segment[3] + segment[6]
        return sorted((s[3], s[5]) for s in sections
                      if start <= s[3] and s[3] + s[5] <= end)

    for relro in (h for h in headers if h[0] == 0x6474e552):
        candidates = [i for i, load in enumerate(loads) if load[3] <= relro[3]]
        if not candidates:
            issues.append('RELRO has no containing LOAD')
            continue
        index = candidates[-1]
        load = loads[index]
        end = relro[3] + relro[6]
        if index + 1 < len(loads) and end > loads[index + 1][3]:
            issues.append('RELRO overlaps the next LOAD')
            continue
        if sections and contained(relro) == contained(load):
            continue
        if relro[3] % PAGE and relro[3] != load[3]:
            issues.append('RELRO start is neither 16 KB aligned nor the LOAD start')
        if end % PAGE and end != load[3] + load[6]:
            issues.append('RELRO end is neither 16 KB aligned nor the LOAD end')
    return issues


def check(path):
    failed = checked = 0
    with zipfile.ZipFile(path) as archive, path.open('rb') as raw:
        for entry in archive.infolist():
            if not entry.filename.endswith('.so') or not any(
                f'/{abi}/' in '/' + entry.filename for abi in ('arm64-v8a', 'x86_64')
            ):
                continue
            checked += 1
            issues = elf_problems(archive.read(entry))
            if path.suffix.lower() == '.apk' and entry.compress_type == zipfile.ZIP_STORED:
                raw.seek(entry.header_offset + 26)
                name_size, extra_size = struct.unpack('<HH', raw.read(4))
                if (entry.header_offset + 30 + name_size + extra_size) % PAGE:
                    issues.append('Uncompressed APK library is not ZIP-aligned to 16 KB')
            failed += bool(issues)
            print(f"{'FAIL' if issues else 'PASS'} {entry.filename}")
            for issue in issues:
                print(f'  {issue}')
    if not checked:
        raise ValueError('No 64-bit native libraries found')
    print(f'{checked} libraries checked; {failed} failed.')
    if path.suffix.lower() == '.aab':
        print('AAB packaging: additionally verify PAGE_ALIGNMENT_16K with bundletool.')
    return 1 if failed else 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('artifact', type=Path)
    args = parser.parse_args()
    raise SystemExit(check(args.artifact))
