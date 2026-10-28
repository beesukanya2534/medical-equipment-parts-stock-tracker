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

-- Heartbeat touched by a scheduled ping (.github/workflows/keep-alive.yml) so the free
-- project is not paused for inactivity. Kept apart from stock data so the ledger never gets fake entries.
create table public.heartbeat (
  id integer primary key default 1 check (id = 1),
  last_ping timestamptz not null default now(),
  pings bigint not null default 0
);
alter table public.heartbeat enable row level security;
insert into public.heartbeat (id) values (1);
revoke all on public.heartbeat from anon, authenticated;

create or replace function public.ping() returns timestamptz
language sql volatile security definer set search_path = ''
as $$
  update public.heartbeat set last_ping = now(), pings = pings + 1 where id = 1 returning last_ping
$$;
revoke all on function public.ping() from public;
grant execute on function public.ping() to anon, authenticated;

-- Later change: the owner chose no login. Anyone with the site link can read and record stock.
-- Items still cannot be deleted (only hidden), so history stays intact.
drop policy "staff read items" on public.items;
drop policy "staff add items" on public.items;
drop policy "staff edit items" on public.items;
drop policy "staff read txns" on public.txns;
drop policy "staff add txns" on public.txns;
drop policy "staff delete txns" on public.txns;

create policy "anyone read items" on public.items for select to anon, authenticated using (true);
create policy "anyone add items" on public.items for insert to anon, authenticated with check (true);
create policy "anyone edit items" on public.items for update to anon, authenticated using (true) with check (true);
create policy "anyone read txns" on public.txns for select to anon, authenticated using (true);
create policy "anyone add txns" on public.txns for insert to anon, authenticated with check (true);
create policy "anyone delete txns" on public.txns for delete to anon, authenticated using (true);

grant select, insert, update on public.items to anon;
grant select, insert, delete on public.txns to anon;

-- Free-text name of whoever recorded the movement (no accounts any more)
alter table public.txns add column recorder text not null default '' check (char_length(recorder) <= 60);

-- Departments copied from the ventilator-round project (spelling variants merged),
-- ordered by how often each appears there. Shown as choices when dispensing.
create table public.wards (
  name text primary key check (char_length(name) between 1 and 120),
  sort integer not null default 100,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.wards enable row level security;
create policy "anyone read wards" on public.wards for select to anon, authenticated using (true);
grant select on public.wards to anon;

insert into public.wards (name, sort) values
('Med ญ', 1), ('Med ชาย', 2), ('กจ2', 3), ('กจ3', 4), ('TM', 5),
('ศัลย์ ชาย', 6), ('ศัลย์ หญิง', 7), ('ICU 100', 8), ('ดล', 9), ('PICU', 10),
('Semi ICU', 11), ('ดบ', 12), ('EENT', 13), ('ICU Neuro', 14), ('กจ4', 15),
('ICU S', 16), ('ศัลยกรรมกระดูก', 17), ('ญ7', 18), ('ญ8', 19), ('เด็กล่าง', 20), ('ICU ญสส', 21);
