-- Thavvu App: deactivate duplicate supervisor assignment (migration 00017)
--
-- The seed created TWO active assignments for the same supervisor
-- (TP-VJA-001 and TP-VJA-002, both SITE-VJA-001). The app's site-context
-- resolver treats an assignment set as a single row (maybeSingle), so the
-- duplicate made resolveSiteId() throw, which froze the attendance loader
-- and crashed the food screen. Keep the primary point active.
UPDATE public.thavvu_point_assignments
SET is_active = false
WHERE id = 'bbbbbbbb-0000-0000-0000-000000000002';
