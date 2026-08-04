-- ============================================================================
-- Migration 00032: Enterprise suppliers + machine catalog (demo & real).
--
-- 1. `suppliers` — HOD-created suppliers now live in Supabase so they flow
--    to the supervisor automatically (previously only local prefs).
--    - is_demo=true rows are visible to demo logins AND real site members
--      (demo seeds), is_demo=false rows are the "real world" catalog.
-- 2. `machine_assets` gains is_demo and two more machines so newly added
--    machines appear in the supervisor's Machine Entry screen.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. SUPPLIERS (enterprise shared catalog)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.suppliers (
  id text PRIMARY KEY,
  group_name text,
  name text NOT NULL,
  contact_person text,
  phone text,
  address text,
  site_name text,
  site_id text,
  thavvu_point_id text,
  default_commission_percent numeric(8, 2) DEFAULT 0,
  payment_upi text,
  payment_account_holder text,
  payment_bank text,
  payment_account_number text,
  payment_ifsc text,
  payment_note text,
  notes text,
  active boolean DEFAULT true,
  is_demo boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_suppliers_site ON public.suppliers(site_id);
CREATE INDEX IF NOT EXISTS idx_suppliers_demo ON public.suppliers(is_demo);

ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "suppliers_auth_all" ON public.suppliers;
CREATE POLICY "suppliers_auth_all" ON public.suppliers FOR ALL
  USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- Realtime for the suppliers table (idempotent).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'suppliers') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.suppliers;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 2. SEED — real suppliers (visible to real logins)
-- ---------------------------------------------------------------------------
INSERT INTO public.suppliers
  (id, group_name, name, contact_person, phone, address, site_name, site_id, thavvu_point_id,
   default_commission_percent, payment_upi, payment_account_holder, payment_bank,
   payment_account_number, payment_ifsc, notes, active, is_demo)
VALUES
  ('SUP-REAL-001', 'Machinery', 'Vijay Concrete Mixers', 'Vijay', '9848012345',
   'RTC Complex Road, Vijayawada', 'Vijayawada River Bed', 'SITE-VJA-001', 'TP-VJA-001',
   5, 'vijaycm@upi', 'Vijay Kumar', 'SBI', '602345678901', 'SBIN0001234',
   'Concrete mixer + transit mixers. Billed monthly.', true, false),
  ('SUP-REAL-002', 'Material', 'Andhra Steel Traders', 'Srinivas', '9848023456',
   'Besant Road, Vijayawada', 'Vijayawada River Bed', 'SITE-VJA-001', 'TP-VJA-002',
   3, 'andhrasteel@upi', 'Srinivas Rao', 'HDFC', '50123456789012', 'HDFC0005678',
   'TMT steel, binding wire, nails.', true, false),
  ('SUP-REAL-003', 'Transport', 'Prakash Earth Movers', 'Prakash', '9848034567',
   'Auto Nagar, Vijayawada', 'Vijayawada River Bed', 'SITE-VJA-001', 'TP-VJA-001',
   7, 'prakashem@upi', 'Prakash Babu', 'ICICI', '012345678901', 'ICIC0009012',
   'JCB, excavator, tippers on hourly basis.', true, false)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. SEED — demo suppliers (visible to the demo logins)
-- ---------------------------------------------------------------------------
INSERT INTO public.suppliers
  (id, group_name, name, contact_person, phone, address, site_name, site_id, thavvu_point_id,
   default_commission_percent, payment_upi, payment_account_holder, payment_bank,
   payment_account_number, payment_ifsc, notes, active, is_demo)
VALUES
  ('SUP-DEMO-001', 'Machinery', 'Demo JCB Services', 'Demo Owner', '9848011111',
   'Demo Yard, Vijayawada', 'Vijayawada River Bed', 'SITE-VJA-001', 'TP-VJA-001',
   8, 'demojcb@upi', 'Demo Account', 'SBI', '602300000001', 'SBIN0000001',
   'Demo supplier for JCB hourly hire.', true, true),
  ('SUP-DEMO-002', 'Material', 'Demo Cement Distributors', 'Demo Sales', '9848022222',
   'Demo Godown, Vijayawada', 'Vijayawada River Bed', 'SITE-VJA-001', 'TP-VJA-002',
   4, 'democement@upi', 'Demo Cement', 'HDFC', '501200000002', 'HDFC0000002',
   'Demo cement + sand supplier.', true, true),
  ('SUP-DEMO-003', 'Fuel', 'Demo Fuel Depot', 'Demo Fuel', '9848033333',
   'Demo Tank Road, Vijayawada', 'Vijayawada River Bed', 'SITE-VJA-001', 'TP-VJA-001',
   0, 'demofuel@upi', 'Demo Fuel', 'ICICI', '012300000003', 'ICIC0000003',
   'Demo diesel / engine oil supplier.', true, true)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. MACHINES — is_demo + newly added machines appear in supervisor entry
-- ---------------------------------------------------------------------------
ALTER TABLE public.machine_assets ADD COLUMN IF NOT EXISTS is_demo boolean DEFAULT false;

INSERT INTO public.machine_assets
  (id, site_id, machine_name, vehicle_number, vehicle_type, operator_name, created_by, is_demo)
VALUES
  ('MCH-004', 'SITE-VJA-001', 'Air Compressor 5HP', 'TN-77-AB-1204', 'Compressor',
   'Ravi Kumar', 'aaaaaaaa-0000-0000-0000-000000000001', false),
  ('MCH-005', 'SITE-VJA-001', 'Concrete Mixer 10/7', 'AP-16-CD-3305', 'Mixer',
   'Suresh Babu', 'aaaaaaaa-0000-0000-0000-000000000001', true),
  ('MCH-006', 'SITE-VJA-001', 'Tractor Trailer 8T', 'AP-39-EF-7788', 'Trailer',
   'Venkatesh', 'aaaaaaaa-0000-0000-0000-000000000001', true)
ON CONFLICT (id) DO NOTHING;
