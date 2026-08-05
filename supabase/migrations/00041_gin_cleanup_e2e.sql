-- ============================================================================
-- Migration 00041: Clean up automated E2E / diagnostic test artifacts so the
-- demo project only shows the intended seeded GIN bills (GIN-DEMO-001/002).
--
-- Order matters: stock_movements reference stock_batch_balances, so the
-- movements must be removed before the balances.
-- ============================================================================

-- 1. E2E movements (they reference the balances below)
DELETE FROM public.stock_movements
 WHERE (reference_id LIKE 'GIN-20260805-%' OR reference_id = 'GIN-DIAG-1')
   AND movement_type = 'gin';

-- 2. E2E stock balances created by approved test bills (batch = GIN no)
DELETE FROM public.stock_batch_balances
 WHERE batch_id LIKE 'GIN-20260805-%'
    OR batch_id = 'GIN-DIAG-1';

-- 3. E2E bills (cascades to gin_bill_items + gin_bill_documents)
DELETE FROM public.gin_bills
 WHERE bill_number LIKE 'BILL-E2E-%'
    OR bill_number LIKE 'BILL-ISOLATE-%'
    OR gin_no = 'GIN-DIAG-1';

-- NOTE: storage.objects cannot be deleted from SQL (Supabase blocks direct
-- storage deletes). The E2E upload artifacts are removed through the
-- Storage API DELETE endpoint (folder-owned by the demo supervisor).
