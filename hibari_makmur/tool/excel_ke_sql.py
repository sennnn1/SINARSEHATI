"""Mengubah PRICE_LIST_tanpa_harga.xlsx menjadi supabase/seed_barang.sql dan
supabase/satuan_barang.sql.

Jalankan dari folder hibari_makmur:
    pip install openpyxl
    python tool/excel_ke_sql.py ../PRICE_LIST_tanpa_harga.xlsx

Kolom Excel: Hal | No | Kategori | Item / Size | Pack 1 | Pack 2 | Harga (SELL) | Catatan
- "Kategori" di Excel adalah grup produk (ratusan jenis), disimpan di kolom `grup`.
  Kolom `kategori` diisi salah satu kategori aplikasi berdasarkan kata kunci.
- Pack 1 / Pack 2 (dalam buah) disimpan apa adanya di `isi_pack_1` / `isi_pack_2`.
- Satuan dasar ditebak dari teks: "JUAL PER LUSIN", "/LSN", dst. -> Lusin; "HRG/PSG" -> Pasang;
  selain itu Bh. `isi_kotak` / `isi_dus` = Pack 1 / Pack 2 dalam satuan dasar itu
  (untuk Lusin dibagi 12, mis. Pack 2 = 60 bh -> 1 Dus = 5 Lusin). Stok awal 0.
- satuan_barang.sql memperbarui satuan & isi barang yang sudah ada di database, hanya untuk
  barang yang satuannya belum pernah diubah (masih 'Pcs' dan belum punya isi).
"""

import re
import sys
from pathlib import Path

import openpyxl

# Urutan penting: aturan pertama yang cocok dipakai.
ATURAN_KATEGORI = [
    ('Kunci & Engsel', ['GEMBOK', 'KUNCI PINTU', 'ENGSEL', 'GRENDEL', 'SLOT', 'HANDLE', 'TARIKAN', 'DOOR']),
    ('Cat', ['CAT ', 'THINNER', 'PLAMIR', 'DEMPUL', 'KUAS', 'ROLL CAT', 'ROLLER']),
    ('Besi & Baja', ['BESI', 'PLAT', 'HOLLOW', 'BAJA', 'KAWAT', 'RANTAI', 'CHAIN', 'SIKU']),
    ('Alat Pertukangan', [
        'TOOLS', 'GERGAJI', 'PALU', 'OBENG', 'TANG', 'KUNCI ', 'BAIS', 'METERAN', 'WATER PAS',
        'BOR', 'MATA ', 'GERINDA', 'POTONG', 'PAHAT', 'KIKIR', 'CUTTER', 'AMPLAS', 'SEKOP',
        'CANGKUL', 'LINGGIS', 'SKRAP', 'CETOK', 'TATAH', 'KAPAK',
    ]),
    ('Perlengkapan Bangunan', [
        'PIPA', 'PVC', 'SEMEN', 'PAKU', 'SEKRUP', 'BAUT', 'MUR', 'FISHER', 'KRAN', 'SELANG',
        'WATERMUR', 'KLEM', 'LEM', 'SEAL', 'KRAMIK', 'KERAMIK', 'TALANG', 'STOP KRAN',
    ]),
]


def tebak_kategori(grup: str, item: str) -> str:
    teks = f' {grup} {item} '.upper()
    for kategori, kata in ATURAN_KATEGORI:
        if any(k in teks for k in kata):
            return kategori
    return 'Lainnya'


POLA_LUSIN = re.compile(r'PER\s*(LUSIN|LSN)|/\s*LSN\b')
POLA_PASANG = re.compile(r'(HRG|HARGA)\s*/\s*PSG|PER\s*(PSG|PASANG)')


def tebak_satuan(grup: str, item: str) -> str:
    teks = f'{grup} {item}'.upper()
    if POLA_LUSIN.search(teks):
        return 'Lusin'
    if POLA_PASANG.search(teks):
        return 'Pasang'
    return 'Bh'


def isi_dalam(satuan: str, pack) -> int:
    """Isi kotak/dus dalam satuan dasar. Pack di Excel dalam buah; untuk Lusin dibagi 12
    (kalau tidak habis dibagi 12, dianggap sudah dalam lusin). 1 atau kosong -> 0 (tidak ada)."""
    if pack is None:
        return 0
    n = int(pack)
    if satuan == 'Lusin' and n % 12 == 0:
        n //= 12
    return n if n > 1 else 0


def sql_teks(v) -> str:
    if v is None or str(v).strip() == '':
        return 'null'
    return "'" + str(v).strip().replace("'", "''") + "'"


def sql_angka(v) -> str:
    return 'null' if v is None else str(int(v))


def main():
    sumber = Path(sys.argv[1] if len(sys.argv) > 1 else '../PRICE_LIST_tanpa_harga.xlsx')
    folder = Path(__file__).resolve().parent.parent / 'supabase'
    tujuan = folder / 'seed_barang.sql'
    perbarui = []

    ws = openpyxl.load_workbook(sumber, data_only=True).active
    baris = []
    for hal, no, grup, item, pack1, pack2, _harga, catatan in ws.iter_rows(min_row=4, values_only=True):
        if not grup and not item:
            continue
        grup = str(grup or '').strip()
        item = str(item or '').strip()
        nama = f'{grup} - {item}' if grup and item else (grup or item)
        kode = f'BRG{len(baris) + 1:04d}'
        satuan = tebak_satuan(grup, item)
        kotak, dus = isi_dalam(satuan, pack1), isi_dalam(satuan, pack2)
        if kotak and dus and kotak >= dus:
            kotak = 0  # tidak masuk akal (kotak >= dus); isi kotak diatur manual di aplikasi

        baris.append(
            f"({sql_teks(kode)}, {sql_teks(nama)}, {sql_teks(tebak_kategori(grup, item))}, {sql_teks(grup)}, "
            f"{sql_teks(item)}, {sql_angka(pack1)}, {sql_angka(pack2)}, {sql_teks(catatan)}, "
            f"{sql_angka(hal)}, {sql_angka(no)}, {sql_teks(satuan)}, {kotak}, {dus})"
        )
        perbarui.append(f"({sql_teks(kode)}, {sql_teks(satuan)}, {kotak}, {dus})")

    with tujuan.open('w', encoding='utf-8') as f:
        f.write(f'-- Dibuat otomatis oleh tool/excel_ke_sql.py dari {sumber.name} ({len(baris)} barang).\n')
        f.write('-- Jalankan SETELAH schema.sql. Aman dijalankan ulang (kode yang sama di-update).\n\n')
        f.write('insert into public.barang\n')
        f.write('  (kode, nama, kategori, grup, item, isi_pack_1, isi_pack_2, catatan, halaman, no_urut,\n')
        f.write('   satuan, isi_kotak, isi_dus)\nvalues\n')
        f.write(',\n'.join(baris))
        f.write('\non conflict (kode) do update set\n')
        f.write('  nama = excluded.nama, kategori = excluded.kategori, grup = excluded.grup,\n')
        f.write('  item = excluded.item, isi_pack_1 = excluded.isi_pack_1, isi_pack_2 = excluded.isi_pack_2,\n')
        f.write('  catatan = excluded.catatan, halaman = excluded.halaman, no_urut = excluded.no_urut;\n')
        f.write('-- Satuan & isi Kotak/Dus tidak ditimpa saat dijalankan ulang (bisa diubah di aplikasi).\n')
    print(f'{len(baris)} barang ditulis ke {tujuan}')

    tujuan2 = folder / 'satuan_barang.sql'
    with tujuan2.open('w', encoding='utf-8') as f:
        f.write(f'-- Dibuat otomatis oleh tool/excel_ke_sql.py dari {sumber.name}.\n')
        f.write('-- Mengisi satuan dasar (Bh / Lusin / Pasang) dan isi Kotak/Dus dari price list untuk\n')
        f.write('-- barang yang sudah ada. Barang yang satuan atau isinya sudah diubah di aplikasi tidak\n')
        f.write('-- disentuh. Jalankan SETELAH transaksi.sql. Aman dijalankan ulang.\n\n')
        f.write('alter table public.barang add column if not exists isi_kotak integer not null default 0;\n')
        f.write('alter table public.barang add column if not exists isi_dus integer not null default 0;\n\n')
        f.write('update public.barang b\nset satuan = v.satuan, isi_kotak = v.isi_kotak, isi_dus = v.isi_dus\n')
        f.write('from (values\n')
        f.write(',\n'.join(perbarui))
        f.write('\n) as v (kode, satuan, isi_kotak, isi_dus)\n')
        f.write("where b.kode = v.kode and b.satuan = 'Pcs' and b.isi_kotak = 0 and b.isi_dus = 0;\n")
    print(f'{len(perbarui)} barang ditulis ke {tujuan2}')


if __name__ == '__main__':
    main()
