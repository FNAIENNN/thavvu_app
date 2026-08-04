-- ============================================================
-- Migration 00021: Stock module — real workflow tables, seed
-- data, RLS and realtime for the stock module.
--
-- 1. Ensures the master tables (stock_items, stock_batch_balances,
--    stock_movements) exist with every column the app reads/writes
--    and seeds real construction stock data.
-- 2. Creates stock_orders (HOD places), stock_gin_bills (received
--    order review), stock_consumption (batch qty + photo proof) and
--    stock_transfers (internal transfer deliver/receive flow).
-- 3. RLS: authenticated users can read/write stock workflow data.
-- 4. Adds every stock table to the supabase_realtime publication.
-- ============================================================

-- ---------------------------------------------------------------------------
-- 1. stock_items master catalog
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.stock_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text,
  item_code text,
  name text,
  item_name text,
  group_name text,
  category text,
  uom text,
  primary_uom text,
  brand text,
  batch_required boolean DEFAULT true,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.stock_items ADD COLUMN IF NOT EXISTS code text;
ALTER TABLE public.stock_items ADD COLUMN IF NOT EXISTS item_code text;
ALTER TABLE public.stock_items ADD COLUMN IF NOT EXISTS name text;
ALTER TABLE public.stock_items ADD COLUMN IF NOT EXISTS item_name text;
ALTER TABLE public.stock_items ADD COLUMN IF NOT EXISTS group_name text;
ALTER TABLE public.stock_items ADD COLUMN IF NOT EXISTS category text;
ALTER TABLE public.stock_items ADD COLUMN IF NOT EXISTS uom text;
ALTER TABLE public.stock_items ADD COLUMN IF NOT EXISTS primary_uom text;
ALTER TABLE public.stock_items ADD COLUMN IF NOT EXISTS brand text;
ALTER TABLE public.stock_items ADD COLUMN IF NOT EXISTS batch_required boolean DEFAULT true;
ALTER TABLE public.stock_items ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;

INSERT INTO public.stock_items (id, code, item_code, name, item_name, group_name, category, uom, primary_uom, brand, batch_required, is_active)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'CEM-OPC53', 'CEM-OPC53', 'Cement OPC 53 Grade', 'Cement OPC 53 Grade', 'Binding Material', 'Cement', 'BAG', 'BAG', 'ACC', true, true),
  ('00000000-0000-0000-0000-000000000002', 'STL-TMT8', 'STL-TMT8', 'TMT Steel Bar 8mm', 'TMT Steel Bar 8mm', 'Steel', 'Reinforcement', 'KG', 'KG', 'Tata Tiscon', true, true),
  ('00000000-0000-0000-0000-000000000003', 'STL-TMT12', 'STL-TMT12', 'TMT Steel Bar 12mm', 'TMT Steel Bar 12mm', 'Steel', 'Reinforcement', 'KG', 'KG', 'Tata Tiscon', true, true),
  ('00000000-0000-0000-0000-000000000004', 'SND-RVR', 'SND-RVR', 'River Sand', 'River Sand', 'Aggregate', 'Sand', 'CUM', 'CUM', '', false, true),
  ('00000000-0000-0000-0000-000000000005', 'MET-20MM', 'MET-20MM', 'Blue Metal 20mm', 'Blue Metal 20mm', 'Aggregate', 'Metal', 'CUM', 'CUM', '', false, true),
  ('00000000-0000-0000-0000-000000000006', 'DSL-HSD', 'DSL-HSD', 'Diesel (HSD)', 'Diesel (HSD)', 'Fuel', 'Diesel', 'LITRE', 'LITRE', '', true, true),
  ('00000000-0000-0000-0000-000000000007', 'OIL-ENG', 'OIL-ENG', 'Engine Oil 20W50', 'Engine Oil 20W50', 'Fuel', 'Lubricant', 'LITRE', 'LITRE', 'Servo', true, true),
  ('00000000-0000-0000-0000-000000000008', 'BRK-CLAY', 'BRK-CLAY', 'Clay Bricks', 'Clay Bricks', 'Masonry', 'Bricks', 'NOS', 'NOS', '', false, true),
  ('00000000-0000-0000-0000-000000000009', 'WIR-BND', 'WIR-BND', 'Binding Wire 1.2mm', 'Binding Wire 1.2mm', 'Steel', 'Binding', 'KG', 'KG', '', true, true),
  ('00000000-0000-0000-0000-000000000010', 'PLY-SHT', 'PLY-SHT', 'Shuttering Plywood 12mm', 'Shuttering Plywood 12mm', 'Formwork', 'Plywood', 'NOS', 'NOS', '', false, true),
  ('00000000-0000-0000-0000-000000000011', 'PNT-WHT', 'PNT-WHT', 'White Paint 20L', 'White Paint 20L', 'Finishing', 'Paint', 'CAN', 'CAN', 'Asian Paints', true, true),
  ('00000000-0000-0000-0000-000000000012', 'PVC-1IN', 'PVC-1IN', 'PVC Pipe 1 inch', 'PVC Pipe 1 inch', 'Plumbing', 'Pipes', 'NOS', 'NOS', 'Astral', false, true),
  ('00000000-0000-0000-0000-000000000013', 'WIR-2.5', 'WIR-2.5', 'Electrical Wire 2.5 sq mm', 'Electrical Wire 2.5 sq mm', 'Electrical', 'Wire', 'COIL', 'COIL', 'Polycab', true, true),
  ('00000000-0000-0000-0000-000000000014', 'NIL-45MM', 'NIL-45MM', 'Nails 45mm', 'Nails 45mm', 'Steel', 'Nails', 'KG', 'KG', '', true, true)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. stock_batch_balances — stock on hand per point per batch
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.stock_batch_balances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid,
  item_name text,
  item_code text,
  stock_point_id text,
  stock_point_name text,
  location text,
  batch_id text,
  batch_code text,
  available_qty numeric(14, 2) DEFAULT 0,
  loose_qty numeric(14, 2) DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.stock_batch_balances ADD COLUMN IF NOT EXISTS item_id uuid;
ALTER TABLE public.stock_batch_balances ADD COLUMN IF NOT EXISTS item_name text;
ALTER TABLE public.stock_batch_balances ADD COLUMN IF NOT EXISTS item_code text;
ALTER TABLE public.stock_batch_balances ADD COLUMN IF NOT EXISTS stock_point_id text;
ALTER TABLE public.stock_batch_balances ADD COLUMN IF NOT EXISTS stock_point_name text;
ALTER TABLE public.stock_batch_balances ADD COLUMN IF NOT EXISTS location text;
ALTER TABLE public.stock_batch_balances ADD COLUMN IF NOT EXISTS batch_id text;
ALTER TABLE public.stock_batch_balances ADD COLUMN IF NOT EXISTS batch_code text;
ALTER TABLE public.stock_batch_balances ADD COLUMN IF NOT EXISTS available_qty numeric(14, 2) DEFAULT 0;
ALTER TABLE public.stock_batch_balances ADD COLUMN IF NOT EXISTS loose_qty numeric(14, 2) DEFAULT 0;

INSERT INTO public.stock_batch_balances
  (id, item_id, item_name, item_code, stock_point_id, stock_point_name, location, batch_id, batch_code, available_qty, loose_qty)
VALUES
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Cement OPC 53 Grade', 'CEM-OPC53', 'SP-001', 'Site A — North', 'Shed A', 'B-CMT-2401', 'CMT-2401', 240, 0),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'TMT Steel Bar 8mm', 'STL-TMT8', 'SP-001', 'Site A — North', 'Shed A', 'B-TMT-124', 'TMT-124', 3200, 25),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003', 'TMT Steel Bar 12mm', 'STL-TMT12', 'SP-001', 'Site A — North', 'Shed A', 'B-TMT-212', 'TMT-212', 4100, 40),
  ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000006', 'Diesel (HSD)', 'DSL-HSD', 'SP-001', 'Site A — North', 'Fuel Tank', 'B-DSL-2405', 'DSL-2405', 850, 0),
  ('10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000004', 'River Sand', 'SND-RVR', 'SP-002', 'Site B — South', 'Open Yard', 'B-SND-2201', 'SND-2201', 45, 0),
  ('10000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000005', 'Blue Metal 20mm', 'MET-20MM', 'SP-002', 'Site B — South', 'Open Yard', 'B-MET-2203', 'MET-2203', 60, 0),
  ('10000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000008', 'Clay Bricks', 'BRK-CLAY', 'SP-002', 'Site B — South', 'Yard 2', 'B-BRK-3301', 'BRK-3301', 12000, 0),
  ('10000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000007', 'Engine Oil 20W50', 'OIL-ENG', 'SP-003', 'Warehouse Main', 'Rack 2', 'B-OIL-1188', 'OIL-1188', 90, 2),
  ('10000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000010', 'Shuttering Plywood 12mm', 'PLY-SHT', 'SP-003', 'Warehouse Main', 'Rack 4', 'B-PLY-0502', 'PLY-0502', 180, 0),
  ('10000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000009', 'Binding Wire 1.2mm', 'WIR-BND', 'SP-003', 'Warehouse Main', 'Rack 1', 'B-WIR-0901', 'WIR-0901', 350, 8)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. stock_movements — audit trail of every in/out movement
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.stock_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_id text,
  movement_type text,
  item_id uuid,
  batch_balance_id uuid,
  batch_id text,
  from_stock_point_id text,
  to_stock_point_id text,
  quantity numeric(14, 2) DEFAULT 0,
  loose_quantity numeric(14, 2) DEFAULT 0,
  reason text,
  photo_name text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.stock_movements ADD COLUMN IF NOT EXISTS reference_id text;
ALTER TABLE public.stock_movements ADD COLUMN IF NOT EXISTS movement_type text;
ALTER TABLE public.stock_movements ADD COLUMN IF NOT EXISTS item_id uuid;
ALTER TABLE public.stock_movements ADD COLUMN IF NOT EXISTS batch_balance_id uuid;
ALTER TABLE public.stock_movements ADD COLUMN IF NOT EXISTS batch_id text;
ALTER TABLE public.stock_movements ADD COLUMN IF NOT EXISTS from_stock_point_id text;
ALTER TABLE public.stock_movements ADD COLUMN IF NOT EXISTS to_stock_point_id text;
ALTER TABLE public.stock_movements ADD COLUMN IF NOT EXISTS quantity numeric(14, 2) DEFAULT 0;
ALTER TABLE public.stock_movements ADD COLUMN IF NOT EXISTS loose_quantity numeric(14, 2) DEFAULT 0;
ALTER TABLE public.stock_movements ADD COLUMN IF NOT EXISTS reason text;
ALTER TABLE public.stock_movements ADD COLUMN IF NOT EXISTS photo_name text;

-- ---------------------------------------------------------------------------
-- 4. stock_orders — orders placed by HOD for the supervisor to receive
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.stock_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_no text,
  site_id text REFERENCES public.sites(id) ON DELETE CASCADE,
  stock_point_id text,
  stock_point_name text,
  item_id uuid,
  item_name text,
  batch text,
  quantity numeric(14, 2) DEFAULT 0,
  unit text DEFAULT 'units',
  status text NOT NULL DEFAULT 'placed', -- placed | received | added_to_stock | cancelled
  notes text,
  placed_by text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 5. stock_gin_bills — goods inward created when an order is received
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.stock_gin_bills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  gin_no text,
  site_id text REFERENCES public.sites(id) ON DELETE CASCADE,
  order_id uuid,
  stock_point_id text,
  stock_point_name text,
  item_id uuid,
  item_name text,
  batch text,
  quantity numeric(14, 2) DEFAULT 0,
  unit text DEFAULT 'units',
  status text NOT NULL DEFAULT 'pending_review', -- pending_review | added_to_stock
  photo_name text,
  received_by text,
  reviewed_by text,
  created_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz
);

-- ---------------------------------------------------------------------------
-- 6. stock_consumption — consumption entries with batch quantity + photo proof
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.stock_consumption (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text REFERENCES public.sites(id) ON DELETE CASCADE,
  stock_point_id text,
  stock_point_name text,
  item_id uuid,
  item_name text,
  batch_id text,
  batch_code text,
  quantity numeric(14, 2) DEFAULT 0,
  loose_quantity numeric(14, 2) DEFAULT 0,
  uom text,
  reason text,
  photo_name text,
  consumed_by text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 7. stock_transfers — internal transfer deliver/receive flow
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.stock_transfers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transfer_no text,
  site_id text REFERENCES public.sites(id) ON DELETE CASCADE,
  from_point_id text,
  from_point text,
  to_point_id text,
  to_point text,
  item_id uuid,
  item_name text,
  batch text,
  quantity numeric(14, 2) DEFAULT 0,
  loose_quantity numeric(14, 2) DEFAULT 0,
  unit text DEFAULT 'units',
  status text NOT NULL DEFAULT 'initiated', -- initiated | delivered | received | cancelled
  notes text,
  photo_name text,
  initiated_by text,
  delivered_by text,
  received_by text,
  initiated_at timestamptz NOT NULL DEFAULT now(),
  delivered_at timestamptz,
  received_at timestamptz
);

-- ---------------------------------------------------------------------------
-- 8. RLS — authenticated users can read/write stock workflow data
-- ---------------------------------------------------------------------------
ALTER TABLE public.stock_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_batch_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_gin_bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_consumption ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_transfers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stock_authenticated_all" ON public.stock_items;
CREATE POLICY "stock_authenticated_all" ON public.stock_items FOR ALL
  USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "stock_batches_authenticated_all" ON public.stock_batch_balances;
CREATE POLICY "stock_batches_authenticated_all" ON public.stock_batch_balances FOR ALL
  USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "stock_movements_authenticated_all" ON public.stock_movements;
CREATE POLICY "stock_movements_authenticated_all" ON public.stock_movements FOR ALL
  USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "stock_orders_authenticated_all" ON public.stock_orders;
CREATE POLICY "stock_orders_authenticated_all" ON public.stock_orders FOR ALL
  USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "stock_gin_authenticated_all" ON public.stock_gin_bills;
CREATE POLICY "stock_gin_authenticated_all" ON public.stock_gin_bills FOR ALL
  USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "stock_consumption_authenticated_all" ON public.stock_consumption;
CREATE POLICY "stock_consumption_authenticated_all" ON public.stock_consumption FOR ALL
  USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "stock_transfers_authenticated_all" ON public.stock_transfers;
CREATE POLICY "stock_transfers_authenticated_all" ON public.stock_transfers FOR ALL
  USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- ---------------------------------------------------------------------------
-- 9. Realtime — publish every stock table (idempotent)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'stock_items') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.stock_items;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'stock_batch_balances') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.stock_batch_balances;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'stock_movements') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.stock_movements;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'stock_orders') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.stock_orders;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'stock_gin_bills') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.stock_gin_bills;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'stock_consumption') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.stock_consumption;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'stock_transfers') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.stock_transfers;
  END IF;
END $$;
