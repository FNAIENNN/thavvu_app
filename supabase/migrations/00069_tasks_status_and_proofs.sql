-- ============================================================================
-- 00069: tasks status CHECK extension + task-proofs storage bucket
--
-- 1. The app writes 'completed' (supervisor marks work done) and
--    'revisionRequested' (HOD sends a task back), but the original CHECK
--    only allowed ('pending','in_progress','submitted','approved','rejected').
--    Every supervisor completion / HOD revision failed the constraint, so
--    task status never persisted. Extend the CHECK to the full app contract.
--
-- 2. Real photo/video proof uploads need a dedicated bucket with the same
--    uid-prefixed policy pattern as gin-documents.
-- ============================================================================

ALTER TABLE public.tasks DROP CONSTRAINT IF EXISTS tasks_status_check;
ALTER TABLE public.tasks ADD CONSTRAINT tasks_status_check
  CHECK (status IN ('pending', 'in_progress', 'completed', 'submitted',
                    'approved', 'rejected', 'revisionRequested'));

-- ---------------------------------------------------------------------------
-- task-proofs bucket + storage RLS
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('task-proofs', 'task-proofs', true, 15728640,
        ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']::text[])
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "task_proofs_select_authenticated" ON storage.objects;
CREATE POLICY "task_proofs_select_authenticated"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'task-proofs' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "task_proofs_insert_own" ON storage.objects;
CREATE POLICY "task_proofs_insert_own"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'task-proofs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "task_proofs_delete_own" ON storage.objects;
CREATE POLICY "task_proofs_delete_own"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'task-proofs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
