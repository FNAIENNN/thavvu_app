-- ============================================================================
-- Migration 00053: Clean cash-module E2E test artifacts.
-- ============================================================================

DELETE FROM public.cash_transactions
 WHERE txn_no LIKE 'CASH-E2E-%';

DELETE FROM public.cash_allocations
 WHERE note = 'E2E allocation';
