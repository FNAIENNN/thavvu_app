-- Thavvu App: Face signature column for professional face ID (migration 00008)
--
-- Stores a 64-bit perceptual hash (dHash) of the enrolled face selfie.
-- The app captures a live selfie on check-in, computes the same hash,
-- and matches by Hamming distance — real image-based face matching,
-- not a name-derived string.
ALTER TABLE public.workers
  ADD COLUMN IF NOT EXISTS face_signature TEXT;
