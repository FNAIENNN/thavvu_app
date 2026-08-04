-- Supabase schema expected by lib/services/stock_inventory_repository.dart
-- Run this in the Supabase SQL editor, then seed stock_items and
-- stock_batch_balances with your actual farm inventory.

create table if not exists public.stock_items (
  id text primary key,
  code text not null,
  name text not null,
  group_name text not null default '',
  category text not null default '',
  uom text not null,
  brand text not null default '',
  batch_required boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.stock_batch_balances (
  id text primary key,
  item_id text not null references public.stock_items(id),
  item_name text not null,
  item_code text not null,
  stock_point_id text not null,
  stock_point_name text not null,
  location text not null default '',
  batch_id text not null,
  available_qty numeric not null default 0 check (available_qty >= 0),
  loose_qty numeric not null default 0 check (loose_qty >= 0),
  updated_at timestamptz not null default now(),
  unique (item_id, stock_point_id, batch_id)
);

create table if not exists public.stock_movements (
  id bigint generated always as identity primary key,
  reference_id text not null,
  movement_type text not null,
  item_id text not null references public.stock_items(id),
  batch_balance_id text not null references public.stock_batch_balances(id),
  batch_id text not null,
  from_stock_point_id text not null,
  to_stock_point_id text,
  quantity numeric not null check (quantity > 0),
  loose_quantity numeric not null default 0 check (loose_quantity >= 0),
  reason text not null default '',
  photo_name text,
  created_at timestamptz not null default now()
);

alter table public.stock_items enable row level security;
alter table public.stock_batch_balances enable row level security;
alter table public.stock_movements enable row level security;

create policy "stock_items_read_all"
  on public.stock_items for select
  using (true);

create policy "stock_batch_balances_read_all"
  on public.stock_batch_balances for select
  using (true);

create policy "stock_batch_balances_update_all"
  on public.stock_batch_balances for update
  using (true)
  with check (true);

create policy "stock_movements_insert_all"
  on public.stock_movements for insert
  with check (true);

alter publication supabase_realtime add table public.stock_batch_balances;
