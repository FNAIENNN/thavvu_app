-- ============================================================================
-- Migration 00049: Clean up the manual-item order E2E run so the demo
-- project returns to a clean slate (empty stock, no orders, no GINs).
-- ============================================================================

-- E2E movements
DELETE FROM public.stock_movements
 WHERE reference_id LIKE 'GIN-20260805-%' AND movement_type = 'gin';

-- E2E balances (GIN batches + the manually typed test item)
DELETE FROM public.stock_batch_balances
 WHERE batch_id LIKE 'GIN-20260805-%'
    OR item_name LIKE 'Manual Test Item %';

-- E2E orders
DELETE FROM public.stock_orders
 WHERE order_no LIKE 'ORD-MAN-%';

-- E2E GIN bills (cascades items + documents)
DELETE FROM public.gin_bills
 WHERE bill_number LIKE 'ORD-MAN-%';

-- E2E auto-created catalog item (safe: balances referencing it are gone)
DELETE FROM public.stock_items
 WHERE name LIKE 'Manual Test Item %';
