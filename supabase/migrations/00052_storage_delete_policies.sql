-- ============================================================================
-- Migration 00052: Storage DELETE policies for photo buckets.
--
-- Audit found uploads+reads work on every photo bucket but DELETE was
-- missing (RLS deny) for rental-photos, machine-daily-attachments,
-- machine-payment-proofs and hod-map-uploads. Owners could never remove a
-- photo. Fix: owner-scoped DELETE policies (first path segment = auth.uid,
-- matching the existing insert policies).
-- ============================================================================

DROP POLICY IF EXISTS "rental_photos_delete_own" ON storage.objects;
CREATE POLICY "rental_photos_delete_own" ON storage.objects FOR DELETE
  USING (
    bucket_id = 'rental-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "machine_daily_attachments_delete_own" ON storage.objects;
CREATE POLICY "machine_daily_attachments_delete_own" ON storage.objects FOR DELETE
  USING (
    bucket_id = 'machine-daily-attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "machine_payment_proofs_delete_own" ON storage.objects;
CREATE POLICY "machine_payment_proofs_delete_own" ON storage.objects FOR DELETE
  USING (
    bucket_id = 'machine-payment-proofs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "hod_map_uploads_delete_own" ON storage.objects;
CREATE POLICY "hod_map_uploads_delete_own" ON storage.objects FOR DELETE
  USING (
    bucket_id = 'hod-map-uploads'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Rental entry created by the live audit (kept out of storage.objects
-- cleanup because Supabase blocks direct storage deletes — those probe
-- files are removed via the Storage API instead).
DELETE FROM public.rental_entries
 WHERE entry_no LIKE 'LIVE-TEST-%';
