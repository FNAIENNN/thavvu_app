-- ============================================================================
-- Migration 00051: Remove automated E2E/verification artifacts from the
-- registry + reports runs. Demo project returns to a REAL-WORLD EMPTY state
-- (all registries and transactional modules empty; structural kept).
-- ============================================================================

-- Reports/order E2E movements + balances (GIN batches)
DELETE FROM public.stock_movements
 WHERE reference_id LIKE 'GIN-20260805-%' OR reference_id LIKE 'MAN-20260805-%';
DELETE FROM public.stock_batch_balances
 WHERE batch_id LIKE 'GIN-20260805-%';

-- Order -> GIN E2E
DELETE FROM public.gin_bills
 WHERE bill_number LIKE 'ORD-RPT-%' OR bill_number LIKE 'ORD-E2E-%'
    OR bill_number LIKE 'ORD-MAN-%';
DELETE FROM public.stock_orders
 WHERE order_no LIKE 'ORD-RPT-%' OR order_no LIKE 'ORD-E2E-%'
    OR order_no LIKE 'ORD-MAN-%';

-- Registry E2E rows
DELETE FROM public.suppliers
 WHERE id LIKE 'SUP-E2E-%' OR name LIKE 'E2E Supplier %';
DELETE FROM public.stock_items
 WHERE id LIKE 'ITEM-E2E-%' OR name LIKE 'E2E Material %';
DELETE FROM public.workers
 WHERE name LIKE 'E2E Worker %';
DELETE FROM public.machine_assets
 WHERE id LIKE 'M-E2E-%' OR machine_name LIKE 'E2E Machine %'
    OR machine_name = 'RLS Test JCB';
