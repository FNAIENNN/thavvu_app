-- ============================================================
-- Migration 00020: payment_accounts upsert-safe unique index
-- ============================================================
-- 00019 created a PARTIAL unique index on
-- (site_id, worker_id, payment_month) WHERE worker_id IS NOT NULL.
-- PostgreSQL cannot infer a partial index for ON CONFLICT upserts
-- without the predicate, so PostgREST upserts would fail. Replace
-- with a full unique index — NULL worker_ids are still allowed
-- (NULLs are distinct in a btree unique index), so temp workers
-- can have multiple rows, while permanent workers keep one row
-- per site/month.

DROP INDEX IF EXISTS public.payment_accounts_worker_month_idx;

CREATE UNIQUE INDEX IF NOT EXISTS payment_accounts_site_worker_month_idx
  ON public.payment_accounts (site_id, worker_id, payment_month);
