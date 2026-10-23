# Sinar Sehati — Aplikasi Toko Perkakas & Kunci Pintu (Flutter)

Satu kode untuk **web** dan **Android**.

## Menjalankan

Mode demo (tanpa internet, data contoh di memori):
```
flutter pub get
flutter run -d chrome
```

Mode Supabase (akun asli, email lupa password dikirim sungguhan):
```
flutter run -d chrome --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_KEY=sb_publishable_xxx
```
URL & key ada di dashboard Supabase → Project Settings → API.

### Akun demo
Semua memakai password `admin123`:

| Email | Role |
|---|---|
| owner@sinarsehati.id | Owner (semua menu) |
| admin@sinarsehati.id | Admin |
| sales@sinarsehati.id | Sales |
| dewi@sinarsehati.id | Sales — nonaktif (untuk menguji akun yang diblokir) |

Hak akses tiap role:
- **Owner**: semua menu, termasuk Laporan Periodik, Laba Kotor, dan Pengguna.
- **Admin**: Home, Pembelian, Penjualan, Stok Barang, Laporan Pembelian/Penjualan/Stok,
  Data Barang, Supplier, Pelanggan, Pengaturan.
- **Sales**: Home, Penjualan, Stok Barang, Laporan Penjualan, Data Pelanggan.
  Stok Barang untuk Sales hanya **lihat saja** (tanpa Tambah Barang, Sesuaikan, atau ubah
  barang), dan di form penjualan harga terkunci ke harga jual dari data barang. Sales tetap
  boleh memberi diskon.

## Satuan, Kotak & Dus
- Setiap barang punya **satuan dasar** (Bh, Lusin, Pasang, Batang, ...). Stok, harga beli, dan
  harga jual di Data Barang dihitung per satuan dasar.
- Untuk barang dari price list, satuan dasar sudah ditentukan otomatis: yang tertulis
  "JUAL PER LUSIN" / "/LSN" menjadi **Lusin**, "HRG/PSG" menjadi **Pasang**, selain itu **Bh**.
- **Isi per Kotak** dan **Isi per Dus** (dalam satuan dasar, opsional) di form Data Barang.
  Dari price list diambil dari kolom **Pack 1** (Kotak) dan **Pack 2** (Dus), yang di Excel
  dalam buah; untuk barang per lusin dibagi 12. Contoh: Water Pas Eurostar 12" Pack 2 = 60 bh
  → **1 Dus = 5 Lusin (60 Bh)**; Batu Grinda 4" x 1mm Pack 2 = 400 → **1 Dus = 400 Bh**.
  Periksa 26 barang per lusin di Data Barang; beberapa isi di Excel tidak jelas satuannya.
- Di form Penjualan/Pembelian, satuan dipilih di kolom Qty (Pcs / Kotak / Dus). Harga otomatis
  menjadi harga per satuan dasar × isi dan masih bisa diubah (kecuali oleh Sales). Contoh: beli
  1 Dus Rp 500.000 → stok +50 Pcs dan harga beli menjadi Rp 10.000 per Pcs.
- Faktur menulis "1 Dus" dengan keterangan isi, kartu stok mencatat "+50 (1 Dus)", dan halaman
  Stok Barang menampilkan stok dalam dus, mis. "120 (2 Dus + 20 Pcs)".

## Diskon
- **Diskon per barang** (kolom *Disc*, dalam persen) di setiap baris form Penjualan/Pembelian.
- **Diskon faktur** untuk seluruh transaksi, diisi dalam persen atau rupiah; disimpan sebagai
  potongan rupiah.
- Total = jumlah subtotal barang setelah diskon − diskon faktur. Rinciannya (subtotal, diskon
  barang, diskon faktur) tampil di detail transaksi dan faktur cetak; laporan penjualan/pembelian
  dan file Excel-nya punya kolom Diskon.
- Laba kotor otomatis berkurang sebesar diskon. Di rekap per barang/kategori/daerah, diskon
  faktur dibagi ke tiap barang sebanding subtotalnya.
- Pembelian: harga beli barang diperbarui ke harga **setelah diskon barang** (diskon faktur
  pembelian tidak mengubah harga beli).

## Fitur login
- **Login** dengan email & password, tombol tampilkan/sembunyikan password.
- **Daftar** akun baru (otomatis role Sales; owner bisa ubah di menu Pengguna).
- **Lupa password** 2 langkah: kirim kode 6 digit ke email → isi kode + password baru.
  Kirim ulang kode tersedia setelah 60 detik. Di mode demo, kode ditampilkan di layar.
- **Hak akses per role**: menu di sidebar menyesuaikan role (lihat `menus` di `lib/shell.dart`).
- **Keluar** dari menu akun di pojok kanan atas.

## Faktur
- Tombol **printer** di daftar Penjualan/Pembelian (atau **Cetak Faktur** di detail transaksi)
  membuka pratinjau faktur, lengkap dengan tombol Cetak dan Bagikan/Simpan PDF.
- Panel **Atur Tampilan Faktur** (juga ada di menu Pengaturan): ukuran kertas A4, A5,
  Continuous Form (dot matrix), Struk 80 mm / 58 mm (thermal); judul; catatan kaki;
  tampilkan logo, terbilang, dan kolom tanda tangan.
- **Rangkap 3**: pilihan *NCR 3 ply* untuk kertas rangkap (putih/merah/kuning) di printer
  dot matrix, sekali cetak jadi 3 dengan keterangan peruntukan tiap lembar di bawah; atau
  *3 lembar* untuk printer biasa (PDF berisi 3 salinan berlabel). Mode *Hitam-putih* membuang
  warna, arsiran, dan logo agar tembusan tetap jelas. Contoh: `docs/faktur_rangkap.png`.
- Template ada di `lib/faktur/faktur_pdf.dart`. Contoh hasil: `docs/faktur_A5.png`, `docs/faktur_Struk.png`.
- pdf.js untuk pratinjau di web disimpan lokal di `web/pdfjs/` dan dimuat langsung oleh
  `web/index.html` (tetap jalan tanpa internet). Jangan pakai variabel `dartPdfJsBaseUrl`:
  package printing 5.14 macet di mode debug saat membacanya.
- Di mode debug (`flutter run`) pembuatan PDF butuh beberapa detik; di build release jauh lebih cepat.

## Persiapan Supabase (sekali saja)
1. Buat project di https://supabase.com.
2. Authentication → Sign In / Providers → Email: aktifkan.
3. Authentication → Emails → **Reset Password**: ubah isi template agar memuat kode, contoh:
   `<p>Kode reset password Sinar Sehati: <b>{{ .Token }}</b></p>`
4. Role dan status akun diatur dari aplikasi: login sebagai **Owner** → menu **Pengguna**.
   Akun baru yang mendaftar mulai sebagai **Sales** dengan status **nonaktif** (menunggu
   persetujuan); Owner mengaktifkannya dan mengubah role-nya di sana. Hanya Owner yang boleh
   mengubah (dijaga RLS di database), dan selalu harus tersisa minimal satu Owner aktif.
   Akun pertama (Owner) cukup dibuat sekali lewat SQL, mis. setelah `pengguna.sql`:
   `update public.pengguna set role = 'Owner', aktif = true where lower(email) = 'emailanda@gmail.com';`

5. **Tabel barang**: SQL Editor → New query → tempel isi `supabase/schema.sql` → Run.
   Lalu query baru → tempel isi `supabase/seed_barang.sql` (1.597 barang dari
   `PRICE_LIST_tanpa_harga.xlsx`) → Run. Cek hasilnya di Table Editor → `barang`.
6. **Tabel pelanggan, transaksi, & pengguna**: jalankan juga `supabase/pelanggan.sql`,
   `supabase/transaksi.sql` (tabel `transaksi`, `transaksi_item`, `mutasi_stok`, dan fungsi
   `simpan_transaksi`, `hapus_transaksi`, `sesuaikan_stok`), lalu `supabase/pengguna.sql`
   (tabel `pengguna` berisi role & status akun). Semuanya aman dijalankan ulang.
7. Salin `supabase.example.json` menjadi `supabase.json`, isi URL & publishable key
   (Project Settings → API). File ini tidak ikut di-commit.
8. Di VS Code: buka folder `D:\SKRIPSI`, menu Run and Debug → pilih
   **Sinar Sehati (Supabase)** → F5. Atau lewat terminal:
   `flutter run -d chrome --dart-define-from-file=supabase.json`

Kalau Excel berubah, buat ulang SQL-nya: `python tool/excel_ke_sql.py ../PRICE_LIST_tanpa_harga.xlsx`.

Yang tersimpan di Supabase setelah login: data barang (`lib/data/barang_repo.dart`), pelanggan
(`lib/data/kontak_repo.dart`), serta penjualan, pembelian, dan kartu stok
(`lib/data/transaksi_repo.dart`). Menyimpan/menghapus transaksi memakai fungsi database, jadi
nomor faktur, stok, dan kartu stok berubah bersamaan dan nomor faktur tidak bentrok walau dua kasir
menyimpan bersamaan. Supplier, pengguna, profil toko, dan pengaturan faktur masih di memori.

Mode demo tidak lagi berisi contoh transaksi; penjualan & pembelian mulai kosong.

Catatan keamanan: status *nonaktif* menolak login di aplikasi (dan dicek ulang tiap sesi
diperbarui). Tabel `barang` dibatasi per role di database (policy di akhir `pengguna.sql`):
semua boleh membaca, hanya Owner/Admin yang boleh menambah, mengubah stok/harga, atau menghapus.
Fungsi `simpan_transaksi` memakai harga jual dari database untuk Sales dan menolak pembelian
dari Sales; `sesuaikan_stok` hanya untuk Owner/Admin. Tabel lain (transaksi, pelanggan) belum
dibatasi per role; pembatasan menu masih di sisi aplikasi.

**Setelah update diskon, hak akses Sales, dan satuan Kotak/Dus**, jalankan di SQL Editor
dengan urutan: `supabase/transaksi.sql`, `supabase/pengguna.sql`, lalu `supabase/satuan_barang.sql`
(mengisi satuan Bh/Lusin dan isi Kotak/Dus untuk barang yang sudah ada; barang yang satuannya
sudah diubah di aplikasi tidak disentuh).

## Struktur
- `lib/main.dart` — entry point, memilih mode demo / Supabase, `AuthGate`
- `lib/auth/` — layanan login (demo & Supabase) dan halaman Login, Daftar, Lupa Password
- `lib/shell.dart` — sidebar, top bar, daftar menu & hak akses role
- `lib/data/app_state.dart` — data & logika toko
- `lib/pages/` — satu file per menu
- `assets/logo.svg` — logo Sinar Sehati (dari desain SIGN/login.html)
