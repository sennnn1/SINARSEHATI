"""Mengubah PRICE_LIST_tanpa_harga.xlsx menjadi supabase/seed_barang.sql.

Jalankan dari folder hibari_makmur:
    pip install openpyxl
    python tool/excel_ke_sql.py ../PRICE_LIST_tanpa_harga.xlsx

Kolom Excel: Hal | No | Kategori | Item / Size | Pack 1 | Pack 2 | Harga (SELL) | Catatan
- "Kategori" di Excel adalah grup produk (ratusan jenis), disimpan di kolom `grup`.
  Kolom `kategori` diisi salah satu kategori aplikasi berdasarkan kata kunci.
- Pack 1 / Pack 2 disimpan di `isi_pack_1` / `isi_pack_2`. Stok awal 0.
"""

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


def sql_teks(v) -> str:
    if v is None or str(v).strip() == '':
        return 'null'
    return "'" + str(v).strip().replace("'", "''") + "'"


def sql_angka(v) -> str:
    return 'null' if v is None else str(int(v))


def main():
    sumber = Path(sys.argv[1] if len(sys.argv) > 1 else '../PRICE_LIST_tanpa_harga.xlsx')
    tujuan = Path(__file__).resolve().parent.parent / 'supabase' / 'seed_barang.sql'

    ws = openpyxl.load_workbook(sumber, data_only=True).active
    baris = []
    for hal, no, grup, item, pack1, pack2, _harga, catatan in ws.iter_rows(min_row=4, values_only=True):
        if not grup and not item:
            continue
        grup = str(grup or '').strip()
        item = str(item or '').strip()
        nama = f'{grup} - {item}' if grup and item else (grup or item)
        kode = f'BRG{len(baris) + 1:04d}'
        baris.append(
            f"({sql_teks(kode)}, {sql_teks(nama)}, {sql_teks(tebak_kategori(grup, item))}, {sql_teks(grup)}, "
            f"{sql_teks(item)}, {sql_angka(pack1)}, {sql_angka(pack2)}, {sql_teks(catatan)}, "
            f"{sql_angka(hal)}, {sql_angka(no)})"
        )

    with tujuan.open('w', encoding='utf-8') as f:
        f.write(f'-- Dibuat otomatis oleh tool/excel_ke_sql.py dari {sumber.name} ({len(baris)} barang).\n')
        f.write('-- Jalankan SETELAH schema.sql. Aman dijalankan ulang (kode yang sama di-update).\n\n')
        f.write('insert into public.barang\n')
        f.write('  (kode, nama, kategori, grup, item, isi_pack_1, isi_pack_2, catatan, halaman, no_urut)\nvalues\n')
        f.write(',\n'.join(baris))
        f.write('\non conflict (kode) do update set\n')
        f.write('  nama = excluded.nama, kategori = excluded.kategori, grup = excluded.grup,\n')
        f.write('  item = excluded.item, isi_pack_1 = excluded.isi_pack_1, isi_pack_2 = excluded.isi_pack_2,\n')
        f.write('  catatan = excluded.catatan, halaman = excluded.halaman, no_urut = excluded.no_urut;\n')
    print(f'{len(baris)} barang ditulis ke {tujuan}')


if __name__ == '__main__':
    main()
