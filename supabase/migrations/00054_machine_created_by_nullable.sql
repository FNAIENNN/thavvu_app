-- Thavvu App: machine created_by UUID relaxation
--
-- machine_assets.created_by, machine_suppliers.created_by and
-- machine_payment_requests.created_by are UUID FKs to profiles(id), but
-- the UI passes human-readable emp codes (e.g. "HOD-001"). The app now
-- resolves the authenticated user's real UUID in
-- SupabaseHodMachineRepository._actorUuid() before writing; making these
-- columns nullable lets unauthenticated/dev/test writes simply omit the
-- value instead of failing with a NOT NULL violation.
--
-- UUID type + FK to profiles are kept so real rows stay referentially clean.
-- (hod_approved_by / paid_by on payment requests were already nullable.)

ALTER TABLE public.machine_assets
  ALTER COLUMN created_by DROP NOT NULL;

ALTER TABLE public.machine_suppliers
  ALTER COLUMN created_by DROP NOT NULL;

ALTER TABLE public.machine_payment_requests
  ALTER COLUMN created_by DROP NOT NULL;
