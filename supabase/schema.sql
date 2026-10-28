-- Schema for the Supabase project "medical-equipment-parts-stock" (ap-southeast-1).
-- Already applied to the live project; kept here for reference and for rebuilding.

-- Staff allowlist: only these emails may read or write stock data
create table public.staff (
  email text primary key check (email = lower(email)),
  created_at timestamptz not null default now()
);
alter table public.staff enable row level security;

create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.staff s
    where s.email = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
$$;
revoke all on function public.is_staff() from public, anon;
grant execute on function public.is_staff() to authenticated;

create table public.items (
  id text primary key default gen_random_uuid()::text,
  no integer not null,
  name text not null check (char_length(name) between 1 and 120),
  category text not null default 'ไม่ระบุหมวด',
  unit text not null default 'ชิ้น',
  min integer not null default 0 check (min >= 0),
  archived boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.txns (
  id text primary key default gen_random_uuid()::text,
  item_id text not null references public.items(id) on delete restrict,
  type text not null check (type in ('in', 'out', 'adj')),
  qty integer not null,
  counted integer,
  ward text not null default '' check (char_length(ward) <= 120),
  note text not null default '' check (char_length(note) <= 300),
  by_user uuid default auth.uid() references auth.users(id) on delete set null,
  by_email text default (auth.jwt() ->> 'email'),
  at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  check (type = 'adj' or qty > 0)
);
create index txns_item_id_idx on public.txns (item_id);
create index txns_by_user_idx on public.txns (by_user);
create index txns_at_idx on public.txns (at desc);

alter table public.items enable row level security;
alter table public.txns enable row level security;

create policy "staff read items" on public.items for select to authenticated using ((select public.is_staff()));
create policy "staff add items" on public.items for insert to authenticated with check ((select public.is_staff()));
create policy "staff edit items" on public.items for update to authenticated using ((select public.is_staff())) with check ((select public.is_staff()));

create policy "staff read txns" on public.txns for select to authenticated using ((select public.is_staff()));
create policy "staff add txns" on public.txns for insert to authenticated
  with check ((select public.is_staff()) and by_user = (select auth.uid()) and by_email is not distinct from (select auth.jwt() ->> 'email'));
create policy "staff delete txns" on public.txns for delete to authenticated using ((select public.is_staff()));

revoke all on public.items, public.txns, public.staff from anon;

alter publication supabase_realtime add table public.items, public.txns;

-- Starting parts list
insert into public.items (id, no, name, category, unit) values
('i01', 1, 'Cuff ผู้ใหญ่ (สายเดี่ยว)', 'Cuff วัดความดัน', 'ชิ้น'),
('i02', 2, 'Cuff ผู้ใหญ่ (สายคู่)', 'Cuff วัดความดัน', 'ชิ้น'),
('i03', 3, 'Cuff ผู้ใหญ่อ้วน (สายเดี่ยว)', 'Cuff วัดความดัน', 'ชิ้น'),
('i04', 4, 'Cuff ผู้ใหญ่อ้วน (สายคู่)', 'Cuff วัดความดัน', 'ชิ้น'),
('i05', 5, 'Cuff เด็กโต (สายเดี่ยว)', 'Cuff วัดความดัน', 'ชิ้น'),
('i06', 6, 'Cuff เด็กโต (สายคู่)', 'Cuff วัดความดัน', 'ชิ้น'),
('i07', 7, 'Cuff เด็กเล็ก (สายเดี่ยว)', 'Cuff วัดความดัน', 'ชิ้น'),
('i08', 8, 'Cuff เด็กเล็ก (สายคู่)', 'Cuff วัดความดัน', 'ชิ้น'),
('i09', 9, 'Water trap', 'อุปกรณ์อื่น ๆ', 'ชิ้น'),
('i10', 10, 'Flexible tube', 'อุปกรณ์อื่น ๆ', 'เส้น'),
('i11', 11, 'หม้อ AirVo2', 'High Flow (AirVo2 / BMC)', 'ใบ'),
('i12', 12, 'หม้อ BMC', 'High Flow (AirVo2 / BMC)', 'ใบ'),
('i13', 13, 'สาย AirVo2', 'High Flow (AirVo2 / BMC)', 'เส้น'),
('i14', 14, 'จมูกผู้ใหญ่', 'High Flow (AirVo2 / BMC)', 'ชิ้น'),
('i15', 15, 'จมูกเด็ก เขียว', 'High Flow (AirVo2 / BMC)', 'ชิ้น'),
('i16', 16, 'จมูกเด็ก ม่วง', 'High Flow (AirVo2 / BMC)', 'ชิ้น'),
('i17', 17, 'Y-piece C2', 'เครื่องช่วยหายใจ C2', 'ชิ้น'),
('i18', 18, 'Flow sensor', 'เครื่องช่วยหายใจ C2', 'ชิ้น'),
('i19', 19, 'Chamber C2', 'เครื่องช่วยหายใจ C2', 'ชิ้น'),
('i20', 20, 'Corrugate C2 สายสั้น', 'เครื่องช่วยหายใจ C2', 'เส้น'),
('i21', 21, 'Corrugate C2 สายยาว', 'เครื่องช่วยหายใจ C2', 'เส้น');

-- Add staff: insert into public.staff (email) values ('someone@example.com');
