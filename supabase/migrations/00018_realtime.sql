-- ============================================================
-- Migration 00018: Enable Supabase Realtime on attendance/food
-- ============================================================
-- Adds the critical tables to the supabase_realtime publication
-- so any INSERT/UPDATE/DELETE is broadcast to subscribing clients.
-- Safe to run multiple times (ALTER PUBLICATION ADD TABLE is idempotent
-- in PostgreSQL 16+; earlier versions error if already present, so we
-- use a DO block guard).

DO $$
BEGIN
  -- workers
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'workers'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.workers';
  END IF;

  -- attendance_records
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'attendance_records'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.attendance_records';
  END IF;

  -- attendance_batches
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'attendance_batches'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.attendance_batches';
  END IF;

  -- attendance_batch_workers
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'attendance_batch_workers'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.attendance_batch_workers';
  END IF;

  -- food_requests
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'food_requests'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.food_requests';
  END IF;

  -- food_submissions
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'food_submissions'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.food_submissions';
  END IF;
END;
$$;
