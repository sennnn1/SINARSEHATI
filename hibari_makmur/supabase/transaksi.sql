create table if not exists public.transaksi (
  kode        text primary key,                       -- PJ00001 / PB00001
  jenis       text not null check (jenis in ('penjualan', 'pembelian')),
  tanggal     date not null,
  pihak       text not null,                          -- nama pelanggan / supplier
  status      text not null default 'Lunas' check (status in ('Lunas', 'Piutang', 'Hutang')),
  catatan     text not null default '',
  daerah      text not null default '',               -- mis. Banda Aceh, Medan
  dibuat_oleh uuid default auth.uid() references auth.users (id) on delete set null,
  dibuat_pada timestamptz not null default now(),
  diubah_pada timestamptz not null default now()
);

-- Untuk tabel yang dibuat sebelum kolom daerah ada.
alter table public.transaksi add column if not exists daerah text not null default '';

create index if not exists transaksi_jenis_tanggal_idx on public.transaksi (jenis, tanggal);

create table if not exists public.transaksi_item (
  id             bigint generated always as identity primary key,
  kode_transaksi text not null references public.transaksi (kode) on delete cascade on update cascade,
  urutan         integer not null default 0,
  kode_barang    text not null,
  nama_barang    text not null,
  satuan         text not null,
  qty            integer not null check (qty > 0),
  harga          numeric(14, 2) not null,
  harga_pokok    numeric(14, 2) not null default 0   -- harga beli saat dijual (untuk laba kotor)
);

create index if not exists transaksi_item_kode_idx on public.transaksi_item (kode_transaksi);

-- Kartu stok: setiap perubahan stok dari transaksi atau penyesuaian manual.
create table if not exists public.mutasi_stok (
  id          bigint generated always as identity primary key,
  tanggal     timestamptz not null default now(),
  kode_barang text not null,
  nama_barang text not null,
  perubahan   integer not null,
  stok_akhir  integer not null,
  keterangan  text not null default '',
  dibuat_oleh uuid default auth.uid() references auth.users (id) on delete set null
);

create index if not exists mutasi_stok_barang_idx on public.mutasi_stok (kode_barang);

create or replace function public.set_diubah_pada()
returns trigger language plpgsql as $$
begin
  new.diubah_pada = now();
  return new;
end $$;

drop trigger if exists transaksi_diubah_pada on public.transaksi;
create trigger transaksi_diubah_pada before update on public.transaksi
  for each row execute function public.set_diubah_pada();

-- -------------------------------------------------------------- Keamanan
alter table public.transaksi enable row level security;
alter table public.transaksi_item enable row level security;
alter table public.mutasi_stok enable row level security;

drop policy if exists "transaksi_akses" on public.transaksi;
create policy "transaksi_akses" on public.transaksi
  for all to authenticated using (true) with check (true);

drop policy if exists "transaksi_item_akses" on public.transaksi_item;
create policy "transaksi_item_akses" on public.transaksi_item
  for all to authenticated using (true) with check (true);

drop policy if exists "mutasi_stok_akses" on public.mutasi_stok;
create policy "mutasi_stok_akses" on public.mutasi_stok
  for all to authenticated using (true) with check (true);

-- ------------------------------------------------------- simpan_transaksi
-- p_items: [{"kode_barang": "...", "nama_barang": "...", "satuan": "...", "qty": 1, "harga": 1000}, ...]
-- Mengembalikan nomor faktur yang dibuat.
-- Versi lama (tanpa p_daerah) dihapus supaya tidak ada dua fungsi bernama sama.
drop function if exists public.simpan_transaksi(text, date, text, text, text, jsonb);
create or replace function public.simpan_transaksi(
  p_jenis   text,
  p_tanggal date,
  p_pihak   text,
  p_status  text,
  p_catatan text,
  p_items   jsonb,
  p_daerah  text default ''
) returns text
language plpgsql as $$
declare
  v_prefix text := case p_jenis when 'penjualan' then 'PJ' when 'pembelian' then 'PB' end;
  v_kode   text;
  v_n      integer;
  v_it     jsonb;
  v_qty    integer;
  v_harga  numeric;
  v_pokok  numeric;
  v_stok   integer;
  r        record;
  b        public.barang;
begin
  if v_prefix is null then
    raise exception 'Jenis transaksi tidak dikenal: %', p_jenis;
  end if;
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'Tambahkan minimal satu barang.';
  end if;

  -- Cek semua barang ada dan (untuk penjualan) stok cukup, sekaligus mengunci
  -- baris barangnya supaya tidak dijual bersamaan oleh kasir lain.
  for r in
    select x->>'kode_barang' as kode, sum((x->>'qty')::int) as qty
    from jsonb_array_elements(p_items) x
    group by 1
  loop
    select * into b from public.barang where kode = r.kode for update;
    if not found then
      raise exception 'Barang % tidak ditemukan', r.kode;
    end if;
    if p_jenis = 'penjualan' and b.stok < r.qty then
      raise exception 'Stok % tidak cukup (tersedia % %)', b.nama, b.stok, b.satuan;
    end if;
  end loop;

  -- Nomor faktur berikutnya; dikunci agar dua kasir tidak dapat nomor sama.
  perform pg_advisory_xact_lock(hashtext('nomor_' || p_jenis));
  select coalesce(max(substring(kode from 3)::int), 0) + 1 into v_n
  from public.transaksi
  where jenis = p_jenis and kode ~ ('^' || v_prefix || '[0-9]+$');
  v_kode := v_prefix || lpad(v_n::text, 5, '0');

  insert into public.transaksi (kode, jenis, tanggal, pihak, status, catatan, daerah)
  values (v_kode, p_jenis, p_tanggal, p_pihak, p_status, coalesce(p_catatan, ''), coalesce(p_daerah, ''));

  for i in 0 .. jsonb_array_length(p_items) - 1 loop
    v_it    := p_items -> i;
    v_qty   := (v_it->>'qty')::int;
    v_harga := (v_it->>'harga')::numeric;
    select * into b from public.barang where kode = v_it->>'kode_barang';
    v_pokok := case when p_jenis = 'penjualan' then b.harga_beli else v_harga end;

    insert into public.transaksi_item
      (kode_transaksi, urutan, kode_barang, nama_barang, satuan, qty, harga, harga_pokok)
    values
      (v_kode, i, b.kode, coalesce(v_it->>'nama_barang', b.nama), coalesce(v_it->>'satuan', b.satuan),
       v_qty, v_harga, v_pokok);

    if p_jenis = 'penjualan' then
      update public.barang set stok = greatest(0, stok - v_qty)
      where kode = b.kode returning stok into v_stok;
    else
      -- Pembelian menambah stok dan memperbarui harga beli terakhir.
      update public.barang set stok = stok + v_qty, harga_beli = v_harga
      where kode = b.kode returning stok into v_stok;
    end if;

    insert into public.mutasi_stok (tanggal, kode_barang, nama_barang, perubahan, stok_akhir, keterangan)
    values (p_tanggal, b.kode, b.nama,
            case when p_jenis = 'penjualan' then -v_qty else v_qty end, v_stok,
            case when p_jenis = 'penjualan' then 'Penjualan ' else 'Pembelian ' end || v_kode);
  end loop;

  return v_kode;
end $$;

-- -------------------------------------------------------- hapus_transaksi
-- Menghapus transaksi dan mengembalikan stok seperti semula.
create or replace function public.hapus_transaksi(p_kode text)
returns void
language plpgsql as $$
declare
  t      public.transaksi;
  it     public.transaksi_item;
  v_ubah integer;
  v_stok integer;
begin
  select * into t from public.transaksi where kode = p_kode for update;
  if not found then
    raise exception 'Transaksi % tidak ditemukan', p_kode;
  end if;

  for it in select * from public.transaksi_item where kode_transaksi = p_kode order by urutan loop
    v_ubah := case when t.jenis = 'penjualan' then it.qty else -it.qty end;
    update public.barang set stok = greatest(0, stok + v_ubah)
    where kode = it.kode_barang returning stok into v_stok;
    if found then
      insert into public.mutasi_stok (kode_barang, nama_barang, perubahan, stok_akhir, keterangan)
      values (it.kode_barang, it.nama_barang, v_ubah, v_stok, 'Batal ' || p_kode);
    end if;
  end loop;

  delete from public.transaksi where kode = p_kode;
end $$;

-- --------------------------------------------------------- sesuaikan_stok
-- Penyesuaian stok manual (stock opname) beserta catatan di kartu stok.
create or replace function public.sesuaikan_stok(p_kode text, p_stok integer, p_keterangan text)
returns void
language plpgsql as $$
declare
  b public.barang;
  v_baru integer := greatest(0, p_stok);
begin
  select * into b from public.barang where kode = p_kode for update;
  if not found then
    raise exception 'Barang % tidak ditemukan', p_kode;
  end if;
  update public.barang set stok = v_baru where kode = p_kode;
  insert into public.mutasi_stok (kode_barang, nama_barang, perubahan, stok_akhir, keterangan)
  values (b.kode, b.nama, v_baru - b.stok, v_baru, coalesce(p_keterangan, ''));
end $$;
