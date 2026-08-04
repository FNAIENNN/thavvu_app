-- ============================================================================
-- Migration 00024: Seed usable fuel balances at every stock point.
--
-- The supervisor modules (Machines, Daily Machine Data) deduct diesel from
-- the live stock_batch_balances via issue_stock_for_module. For those
-- dropdowns to actually work everywhere, each stock point needs a Diesel
-- (HSD) balance; SP-001 additionally gets Engine Oil for the Consumables tab.
-- ============================================================================

INSERT INTO public.stock_batch_balances
  (id, item_id, item_name, item_code, stock_point_id, stock_point_name, location, batch_id, batch_code, available_qty, loose_qty)
VALUES
  ('10000000-0000-0000-0000-000000000011',
   '00000000-0000-0000-0000-000000000006', 'Diesel (HSD)', 'DSL-HSD',
   'SP-002', 'Site B — South', 'Fuel Tank', 'B-DSL-2411', 'DSL-2411', 620, 0),
  ('10000000-0000-0000-0000-000000000012',
   '00000000-0000-0000-0000-000000000006', 'Diesel (HSD)', 'DSL-HSD',
   'SP-003', 'Warehouse Main', 'Fuel Shed', 'B-DSL-2412', 'DSL-2412', 500, 0),
  ('10000000-0000-0000-0000-000000000013',
   '00000000-0000-0000-0000-000000000007', 'Engine Oil 20W50', 'OIL-ENG',
   'SP-001', 'Site A — North', 'Rack 1', 'B-OIL-2401', 'OIL-2401', 45, 2)
ON CONFLICT (id) DO NOTHING;
