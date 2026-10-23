create table if not exists public.pelanggan (
  kode        text primary key,           -- mis. PLG001 (dibuat otomatis oleh aplikasi)
  nama        text not null,
  telepon     text not null default '',
  alamat      text not null default '',
  daerah      text not null default '',     -- kota / kabupaten, mis. Banda Aceh
  dibuat_pada timestamptz not null default now(),
  diubah_pada timestamptz not null default now()
);

-- Untuk tabel yang dibuat sebelum kolom daerah ada.
alter table public.pelanggan add column if not exists daerah text not null default '';
create index if not exists pelanggan_daerah_idx on public.pelanggan (daerah);

-- Fungsi set_diubah_pada sudah dibuat oleh schema.sql; dibuat ulang di sini
-- supaya file ini juga bisa dijalankan sendiri.
create or replace function public.set_diubah_pada()
returns trigger language plpgsql as $$
begin
  new.diubah_pada = now();
  return new;
end $$;

drop trigger if exists pelanggan_diubah_pada on public.pelanggan;
create trigger pelanggan_diubah_pada before update on public.pelanggan
  for each row execute function public.set_diubah_pada();

-- Keamanan: hanya pengguna yang sudah login di aplikasi yang boleh akses.
alter table public.pelanggan enable row level security;

drop policy if exists "pelanggan_baca" on public.pelanggan;
drop policy if exists "pelanggan_tulis" on public.pelanggan;
create policy "pelanggan_baca" on public.pelanggan
  for select to authenticated using (true);
create policy "pelanggan_tulis" on public.pelanggan
  for all to authenticated using (true) with check (true);

-- Pelanggan "UMUM" untuk pembeli eceran yang tidak dicatat namanya.
insert into public.pelanggan (kode, nama, alamat)
values ('PLG001', 'UMUM', '-')
on conflict (kode) do nothing;
