"""Regression cases for LOAD alignment and the old-linker RELRO warning."""
import struct
import unittest

from check_android_native import elf_problems


def elf(loads, relro=None, sections=()):
    headers = [(1, start, size, alignment) for start, size, alignment in loads]
    if relro:
        headers.append((0x6474e552, *relro, 1))
    shoff = 64 + 56 * len(headers)
    data = bytearray(shoff + 64 * len(sections))
    data[:6] = b'\x7fELF\x02\x01'
    struct.pack_into('<QQ', data, 32, 64, shoff)
    struct.pack_into('<HHHH', data, 54, 56, len(headers), 64, len(sections))
    for i, (kind, start, size, align) in enumerate(headers):
        struct.pack_into('<IIQQQQQQ', data, 64 + 56 * i,
                         kind, 6, start, start, 0, size, size, align)
    for i, (start, size) in enumerate(sections):
        struct.pack_into('<IIQQQQIIQQ', data, shoff + 64 * i,
                         0, 1, 0, start, 0, size, 0, 0, 1, 0)
    return data


class AlignmentTests(unittest.TestCase):
    def test_rejects_4k_load_even_with_no_relro(self):
        self.assertTrue(elf_problems(elf([(0, 0x8000, 4096)])))

    def test_accepts_flutter_aot_without_relro(self):
        self.assertEqual(elf_problems(elf([(0, 0x8000, 65536)])), [])

    def test_rejects_relro_ending_inside_a_writable_page(self):
        problems = elf_problems(elf([(0x4000, 0x8000, 16384)], (0x4000, 0x1000)))
        self.assertTrue(any('RELRO end' in p for p in problems))

    def test_accepts_relro_covering_whole_load(self):
        self.assertEqual(elf_problems(elf([(0x4320, 0xce0, 16384)], (0x4320, 0xce0))), [])

    def test_accepts_linker_padding_after_last_section(self):
        data = elf([(0x4000, 0x1100, 16384)], (0x4000, 0x2000), [(0x4000, 0x1100)])
        self.assertEqual(elf_problems(data), [])

    def test_rejects_relro_spilling_into_next_load(self):
        data = elf([(0x4000, 0x4000, 16384), (0x8000, 0x4000, 16384)], (0x4000, 0x5000))
        self.assertTrue(any('overlaps' in p for p in elf_problems(data)))

    def test_rejects_truncated_or_non_elf_input(self):
        with self.assertRaises(ValueError):
            elf_problems(b'not an ELF')


if __name__ == '__main__':
    unittest.main()
