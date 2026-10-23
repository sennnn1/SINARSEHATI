-- ------------------------------------------------------------------ Tabel
create table if not exists public.pengguna (
  id          uuid primary key references auth.users (id) on delete cascade,
  email       text not null default '',
  nama        text not null default '',
  role        text not null default 'Sales' check (role in ('Owner', 'Admin', 'Sales')),
  aktif       boolean not null default false,
  dibuat_pada timestamptz not null default now(),
  diubah_pada timestamptz not null default now()
);

create index if not exists pengguna_role_idx on public.pengguna (role);

create or replace function public.set_diubah_pada()
returns trigger language plpgsql as $$
begin
  new.diubah_pada = now();
  return new;
end $$;

drop trigger if exists pengguna_diubah_pada on public.pengguna;
create trigger pengguna_diubah_pada before update on public.pengguna
  for each row execute function public.set_diubah_pada();

-- ------------------------------------------- Isi untuk akun yang sudah ada
insert into public.pengguna (id, email, nama, role, aktif, dibuat_pada)
select u.id,
       coalesce(u.email, ''),
       coalesce(nullif(trim(u.raw_user_meta_data ->> 'nama'), ''), split_part(coalesce(u.email, ''), '@', 1)),
       case u.raw_user_meta_data ->> 'role'
         when 'Owner'  then 'Owner'
         when 'Admin'  then 'Admin'
         when 'Gudang' then 'Admin'
         else 'Sales'
       end,
       true,
       u.created_at
from auth.users u
on conflict (id) do nothing;

-- ------------------------------------------- Akun baru → baris pengguna
-- Role dari user metadata SENGAJA diabaikan: siapa pun bisa mengisi metadata
-- saat mendaftar lewat API, jadi akun baru selalu Sales dan menunggu persetujuan.
create or replace function public.buat_profil_pengguna()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.pengguna (id, email, nama, role, aktif)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'nama'), ''), split_part(coalesce(new.email, ''), '@', 1)),
    'Sales',
    false
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created_pengguna on auth.users;
create trigger on_auth_user_created_pengguna
  after insert on auth.users
  for each row execute function public.buat_profil_pengguna();

-- ------------------------------------------------------------ Keamanan
create or replace function public.is_owner()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.pengguna
    where id = auth.uid() and role = 'Owner' and aktif
  )
$$;

revoke all on function public.is_owner() from public;
grant execute on function public.is_owner() to authenticated;

alter table public.pengguna enable row level security;

-- Tiap orang boleh membaca barisnya sendiri; Owner boleh membaca semuanya.
drop policy if exists "pengguna_baca" on public.pengguna;
create policy "pengguna_baca" on public.pengguna
  for select to authenticated
  using (id = auth.uid() or public.is_owner());

-- Hanya Owner yang boleh mengubah. Tidak ada policy insert/delete: baris dibuat
-- oleh trigger di atas dan terhapus otomatis bersama akunnya.
drop policy if exists "pengguna_ubah" on public.pengguna;
create policy "pengguna_ubah" on public.pengguna
  for update to authenticated
  using (public.is_owner())
  with check (public.is_owner());

-- Hanya kolom ini yang boleh diubah lewat aplikasi (bukan id / email).
revoke all on public.pengguna from anon;
revoke update on public.pengguna from authenticated;
grant select on public.pengguna to authenticated;
grant update (nama, role, aktif) on public.pengguna to authenticated;

-- ----------------------------------------------- Jaga Owner terakhir
-- Supaya tidak ada yang mengunci dirinya sendiri: harus selalu ada minimal
-- satu Owner aktif.
create or replace function public.jaga_owner_terakhir()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.role = 'Owner' and old.aktif
     and (tg_op = 'DELETE' or new.role <> 'Owner' or not new.aktif) then
    if not exists (
      select 1 from public.pengguna where role = 'Owner' and aktif and id <> old.id
    ) then
      raise exception 'Minimal harus ada satu Owner yang aktif.';
    end if;
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end $$;

drop trigger if exists pengguna_jaga_owner on public.pengguna;
create trigger pengguna_jaga_owner
  before update or delete on public.pengguna
  for each row execute function public.jaga_owner_terakhir();

-- ------------------------------------------------------------ Cek hasil
-- Hasil terakhir ini tampil di SQL Editor: pastikan ada minimal satu Owner.
select email, role, aktif, dibuat_pada
from public.pengguna
order by dibuat_pada;
