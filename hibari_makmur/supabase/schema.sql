create table if not exists public.barang (
  kode        text primary key,
  nama        text not null,
  kategori    text not null default 'Lainnya',
  satuan      text not null default 'Pcs',
  stok        integer not null default 0,
  min_stok    integer not null default 0,
  harga_beli  numeric(14, 2) not null default 0,
  harga_jual  numeric(14, 2) not null default 0,

  -- Kolom asli dari file Excel price list.
  grup        text,     -- kolom "Kategori" di Excel (grup produk)
  item        text,     -- kolom "Item / Size"
  isi_pack_1  integer,  -- kolom "Pack 1"
  isi_pack_2  integer,  -- kolom "Pack 2"
  catatan     text,
  halaman     integer,  -- kolom "Hal"
  no_urut     integer,  -- kolom "No"

  dibuat_pada timestamptz not null default now(),
  diubah_pada timestamptz not null default now()
);

create index if not exists barang_kategori_idx on public.barang (kategori);

create or replace function public.set_diubah_pada()
returns trigger language plpgsql as $$
begin
  new.diubah_pada = now();
  return new;
end $$;

drop trigger if exists barang_diubah_pada on public.barang;
create trigger barang_diubah_pada before update on public.barang
  for each row execute function public.set_diubah_pada();

-- Keamanan: hanya pengguna yang sudah login di aplikasi yang boleh akses.
alter table public.barang enable row level security;

drop policy if exists "barang_baca" on public.barang;
drop policy if exists "barang_tulis" on public.barang;
create policy "barang_baca" on public.barang
  for select to authenticated using (true);
create policy "barang_tulis" on public.barang
  for all to authenticated using (true) with check (true);
