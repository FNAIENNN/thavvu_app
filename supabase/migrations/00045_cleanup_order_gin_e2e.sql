-- ============================================================================
-- Migration 00045: Remove the final automated E2E workflow artifacts
-- (multi-item order -> GIN verification run) so the demo project only
-- shows seeded demo data.
-- ============================================================================

-- E2E movements
DELETE FROM public.stock_movements
 WHERE reference_id LIKE 'GIN-20260805-%' AND movement_type = 'gin';

-- E2E stock balances created by approved test bills
DELETE FROM public.stock_batch_balances
 WHERE batch_id LIKE 'GIN-20260805-%';

-- E2E GIN bills (cascades items + documents)
DELETE FROM public.gin_bills
 WHERE bill_number LIKE 'ORD-E2E-%';

-- E2E stock orders
DELETE FROM public.stock_orders
 WHERE order_no LIKE 'ORD-E2E-%';
