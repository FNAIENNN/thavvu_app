-- ============================================================================
-- Migration 00035: Multi-item Goods Inward Notes (GIN) — Thavvu Point flow.
--
-- Turns the GIN tab into a production bill-based workflow:
--   1. gin_bills          — one row per supplier bill received at a Thavvu Point
--   2. gin_bill_items     — line items with ordered / billed / received qty and
--                           the reconciliation ACTION (shortage → reorder/accept,
--                           excess → extra, matched → done) picked by the
--                           supervisor and reviewed by HOD
--   3. gin_bill_documents — invoice / delivery note / photo attachments
--
-- Flow:
--   Supervisor: compose bill → pick ACTION per line → upload ≥1 document → submit
--   HOD:        reviews the same table, sees every ACTION, approves / rejects
--   Approve:    stock is added to the Thavvu Point (batch = GIN no) automatically
--   Reject:     supervisor sees the note and fixes / resubmits
--
-- All writes happen through SECURITY DEFINER RPCs (atomic, server-validated).
-- Table-level RLS only allows SELECT for authenticated users.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. gin_bills — bill header
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.gin_bills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  gin_no text NOT NULL UNIQUE,
  bill_number text NOT NULL,
  supplier_id text,
  supplier_name text NOT NULL,
  site_id text REFERENCES public.sites(id) ON DELETE SET NULL,
  thavvu_point_id text NOT NULL,
  thavvu_point_name text NOT NULL,
  bill_date date,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'submitted', 'approved', 'rejected', 'added_to_stock')),
  submitted_by text,
  submitted_at timestamptz,
  hod_status text NOT NULL DEFAULT 'pending'
    CHECK (hod_status IN ('pending', 'approved', 'rejected')),
  hod_note text,
  hod_reviewed_by text,
  hod_reviewed_at timestamptz,
  added_to_stock_by text,
  added_to_stock_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_gin_bills_point_status
  ON public.gin_bills(thavvu_point_id, status);
CREATE INDEX IF NOT EXISTS idx_gin_bills_hod_status
  ON public.gin_bills(hod_status, created_at);

-- ---------------------------------------------------------------------------
-- 2. gin_bill_items — reconciliation lines with supervisor + HOD actions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.gin_bill_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  gin_bill_id uuid NOT NULL REFERENCES public.gin_bills(id) ON DELETE CASCADE,
  item_name text NOT NULL,
  ordered_qty numeric(14, 2) NOT NULL DEFAULT 0,
  billed_qty numeric(14, 2) NOT NULL DEFAULT 0,
  received_qty numeric(14, 2) NOT NULL DEFAULT 0,
  uom text DEFAULT 'units',
  action text CHECK (action IN ('reorder', 'extra', 'done')),
  action_note text,
  hod_action text CHECK (hod_action IN ('reorder', 'extra', 'done')),
  hod_action_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_gin_items_bill ON public.gin_bill_items(gin_bill_id);

-- ---------------------------------------------------------------------------
-- 3. gin_bill_documents — invoice / delivery note / photo attachments
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.gin_bill_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  gin_bill_id uuid NOT NULL REFERENCES public.gin_bills(id) ON DELETE CASCADE,
  name text NOT NULL,
  type text NOT NULL CHECK (type IN ('invoice', 'delivery_note', 'photo')),
  storage_path text,
  uploaded_by text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_gin_docs_bill ON public.gin_bill_documents(gin_bill_id);

-- ---------------------------------------------------------------------------
-- 4. RLS — authenticated SELECT only; all writes via SECURITY DEFINER RPCs
-- ---------------------------------------------------------------------------
ALTER TABLE public.gin_bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gin_bill_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gin_bill_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "gin_bills_select_authenticated" ON public.gin_bills;
CREATE POLICY "gin_bills_select_authenticated" ON public.gin_bills FOR SELECT
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "gin_items_select_authenticated" ON public.gin_bill_items;
CREATE POLICY "gin_items_select_authenticated" ON public.gin_bill_items FOR SELECT
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "gin_docs_select_authenticated" ON public.gin_bill_documents;
CREATE POLICY "gin_docs_select_authenticated" ON public.gin_bill_documents FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ---------------------------------------------------------------------------
-- 5. gin_add_to_stock — move approved GIN lines into Thavvu Point balances
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.gin_add_to_stock(p_bill_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_bill public.gin_bills%ROWTYPE;
  v_item RECORD;
  v_item_id uuid;
  v_item_code text;
  v_balance_id uuid;
  v_email text := auth.jwt() ->> 'email';
  v_added int := 0;
  v_skipped text[] := '{}'::text[];
BEGIN
  SELECT * INTO v_bill FROM public.gin_bills WHERE id = p_bill_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'GIN bill not found';
  END IF;
  IF v_bill.status = 'added_to_stock' THEN
    RETURN jsonb_build_object('ok', true, 'added', 0, 'status', 'already_added');
  END IF;
  IF v_bill.hod_status <> 'approved' THEN
    RAISE EXCEPTION 'GIN is not approved by HOD';
  END IF;

  FOR v_item IN SELECT * FROM public.gin_bill_items WHERE gin_bill_id = p_bill_id LOOP
    IF v_item.received_qty IS NULL OR v_item.received_qty <= 0 THEN
      v_skipped := array_append(v_skipped, v_item.item_name || ' (0 received)');
      CONTINUE;
    END IF;

    -- Resolve the master stock item by name, or create a lightweight entry.
    SELECT id, COALESCE(NULLIF(code, ''), NULLIF(item_code, ''))
      INTO v_item_id, v_item_code
      FROM public.stock_items
      WHERE lower(COALESCE(name, item_name, '')) = lower(v_item.item_name)
      LIMIT 1;

    IF v_item_id IS NULL THEN
      v_item_code := 'GIN-' || upper(left(regexp_replace(
          v_item.item_name, '[^a-zA-Z0-9]+', '', 'g'), 12));
      INSERT INTO public.stock_items
        (code, item_code, name, item_name, group_name, category, uom,
         primary_uom, batch_required, is_active)
      VALUES
        (v_item_code, v_item_code, v_item.item_name, v_item.item_name,
         'GIN Received', 'GIN', COALESCE(v_item.uom, 'units'),
         COALESCE(v_item.uom, 'units'), false, true)
      RETURNING id INTO v_item_id;
    END IF;

    -- Upsert the balance for (item, Thavvu Point, batch = GIN no).
    SELECT id INTO v_balance_id
      FROM public.stock_batch_balances
      WHERE item_id = v_item_id
        AND stock_point_id = v_bill.thavvu_point_id
        AND batch_id = v_bill.gin_no
      LIMIT 1;

    IF v_balance_id IS NULL THEN
      INSERT INTO public.stock_batch_balances
        (item_id, item_name, item_code, stock_point_id, stock_point_name,
         location, batch_id, batch_code, available_qty, loose_qty)
      VALUES
        (v_item_id, v_item.item_name, v_item_code, v_bill.thavvu_point_id,
         v_bill.thavvu_point_name, v_bill.thavvu_point_name,
         v_bill.gin_no, v_bill.gin_no, v_item.received_qty, 0)
      RETURNING id INTO v_balance_id;
    ELSE
      UPDATE public.stock_batch_balances
        SET available_qty = available_qty + v_item.received_qty,
            item_name = v_item.item_name,
            item_code = COALESCE(item_code, v_item_code),
            updated_at = now()
        WHERE id = v_balance_id;
    END IF;

    INSERT INTO public.stock_movements
      (reference_id, movement_type, item_id, batch_balance_id, batch_id,
       to_stock_point_id, quantity, loose_quantity, reason, created_at)
    VALUES
      (v_bill.gin_no, 'gin', v_item_id, v_balance_id, v_bill.gin_no,
       v_bill.thavvu_point_id, v_item.received_qty, 0,
       'Goods inward — ' || v_item.item_name ||
         ' (Bill ' || v_bill.bill_number || ')', now());

    v_added := v_added + 1;
  END LOOP;

  UPDATE public.gin_bills
    SET status = 'added_to_stock',
        added_to_stock_by = v_email,
        added_to_stock_at = now(),
        updated_at = now()
    WHERE id = p_bill_id;

  RETURN jsonb_build_object('ok', true, 'added', v_added,
                            'skipped', to_jsonb(v_skipped), 'status', 'added_to_stock');
END $$;

-- ---------------------------------------------------------------------------
-- 6. gin_submit_bill — supervisor submits a composed bill atomically
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.gin_submit_bill(
  p_bill_number text,
  p_supplier_name text,
  p_thavvu_point_id text,
  p_thavvu_point_name text,
  p_items jsonb,
  p_gin_no text DEFAULT NULL,
  p_supplier_id text DEFAULT NULL,
  p_site_id text DEFAULT NULL,
  p_bill_date date DEFAULT NULL,
  p_documents jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_bill_id uuid;
  v_gin_no text;
  v_item jsonb;
  v_doc jsonb;
  v_email text := auth.jwt() ->> 'email';
BEGIN
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'GIN requires at least one item';
  END IF;
  IF p_bill_number IS NULL OR trim(p_bill_number) = '' THEN
    RAISE EXCEPTION 'Bill number is required';
  END IF;
  IF p_thavvu_point_id IS NULL OR trim(p_thavvu_point_id) = '' THEN
    RAISE EXCEPTION 'Thavvu Point is required';
  END IF;
  IF p_supplier_name IS NULL OR trim(p_supplier_name) = '' THEN
    RAISE EXCEPTION 'Supplier is required';
  END IF;

  v_gin_no := COALESCE(NULLIF(trim(p_gin_no), ''),
    'GIN-' || to_char(now(), 'YYYYMMDD') || '-' ||
      upper(substr(md5(random()::text), 1, 5)));

  INSERT INTO public.gin_bills
    (gin_no, bill_number, supplier_id, supplier_name, site_id,
     thavvu_point_id, thavvu_point_name, bill_date,
     status, submitted_by, submitted_at, hod_status)
  VALUES
    (v_gin_no, trim(p_bill_number), p_supplier_id, trim(p_supplier_name),
     p_site_id, p_thavvu_point_id, trim(p_thavvu_point_name), p_bill_date,
     'pending', v_email, now(), 'pending')
  RETURNING id INTO v_bill_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    INSERT INTO public.gin_bill_items
      (gin_bill_id, item_name, ordered_qty, billed_qty, received_qty,
       uom, action, action_note)
    VALUES
      (v_bill_id,
       COALESCE(NULLIF(v_item ->> 'item_name', ''), 'Item'),
       COALESCE((v_item ->> 'ordered_qty')::numeric, 0),
       COALESCE((v_item ->> 'billed_qty')::numeric, 0),
       COALESCE((v_item ->> 'received_qty')::numeric, 0),
       COALESCE(NULLIF(v_item ->> 'uom', ''), 'units'),
       NULLIF(v_item ->> 'action', ''),
       NULLIF(v_item ->> 'action_note', ''));
  END LOOP;

  FOR v_doc IN SELECT * FROM jsonb_array_elements(COALESCE(p_documents, '[]'::jsonb)) LOOP
    INSERT INTO public.gin_bill_documents
      (gin_bill_id, name, type, storage_path, uploaded_by)
    VALUES
      (v_bill_id,
       COALESCE(NULLIF(v_doc ->> 'name', ''), 'document'),
       COALESCE(NULLIF(v_doc ->> 'type', ''), 'photo'),
       NULLIF(v_doc ->> 'storage_path', ''),
       v_email);
  END LOOP;

  RETURN jsonb_build_object('id', v_bill_id, 'gin_no', v_gin_no,
                            'status', 'pending');
END $$;

-- ---------------------------------------------------------------------------
-- 7. gin_hod_review — HOD approves / rejects; approve adds stock to the point
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.gin_hod_review(
  p_bill_id uuid,
  p_decision text,
  p_note text DEFAULT NULL,
  p_item_actions jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_bill public.gin_bills%ROWTYPE;
  v_act jsonb;
  v_email text := auth.jwt() ->> 'email';
BEGIN
  IF p_decision NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'Invalid decision';
  END IF;

  SELECT * INTO v_bill FROM public.gin_bills WHERE id = p_bill_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'GIN bill not found';
  END IF;
  IF v_bill.hod_status = 'approved' THEN
    RAISE EXCEPTION 'GIN is already approved';
  END IF;

  -- Optional per-line HOD actions (shown back on the supervisor table).
  FOR v_act IN SELECT * FROM jsonb_array_elements(COALESCE(p_item_actions, '[]'::jsonb)) LOOP
    UPDATE public.gin_bill_items
      SET hod_action = NULLIF(v_act ->> 'hod_action', ''),
          hod_action_note = NULLIF(v_act ->> 'hod_action_note', '')
      WHERE id = (v_act ->> 'item_id')::uuid
        AND gin_bill_id = p_bill_id;
  END LOOP;

  IF p_decision = 'approved' THEN
    UPDATE public.gin_bills
      SET hod_status = 'approved',
          hod_note = p_note,
          hod_reviewed_by = v_email,
          hod_reviewed_at = now(),
          status = 'approved',
          updated_at = now()
      WHERE id = p_bill_id;
    RETURN public.gin_add_to_stock(p_bill_id);
  ELSE
    UPDATE public.gin_bills
      SET hod_status = 'rejected',
          hod_note = p_note,
          hod_reviewed_by = v_email,
          hod_reviewed_at = now(),
          status = 'rejected',
          updated_at = now()
      WHERE id = p_bill_id;
    RETURN jsonb_build_object('ok', true, 'status', 'rejected');
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 8. Realtime — publish GIN tables
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                 WHERE pubname = 'supabase_realtime' AND schemaname = 'public'
                   AND tablename = 'gin_bills') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.gin_bills;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                 WHERE pubname = 'supabase_realtime' AND schemaname = 'public'
                   AND tablename = 'gin_bill_items') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.gin_bill_items;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                 WHERE pubname = 'supabase_realtime' AND schemaname = 'public'
                   AND tablename = 'gin_bill_documents') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.gin_bill_documents;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 9. Storage bucket — GIN documents (invoice / delivery note / photo)
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'gin-documents',
  'gin-documents',
  true,
  15728640, -- 15 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']::text[]
) ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "gin_documents_select_authenticated" ON storage.objects;
CREATE POLICY "gin_documents_select_authenticated"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'gin-documents' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "gin_documents_insert_own" ON storage.objects;
CREATE POLICY "gin_documents_insert_own"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'gin-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "gin_documents_delete_own" ON storage.objects;
CREATE POLICY "gin_documents_delete_own"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'gin-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------------
-- 10. Demo seed — pending bills at both Thavvu Points so the supervisor GIN
--     tab and the HOD approvals screen have immediate data on demo logins.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_bill_a uuid;
  v_bill_b uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM public.gin_bills) THEN
    RETURN;
  END IF;

  -- Bill A (TP-VJA-001): one matched line + one SHORTAGE line
  INSERT INTO public.gin_bills
    (gin_no, bill_number, supplier_id, supplier_name, site_id,
     thavvu_point_id, thavvu_point_name, bill_date, status,
     submitted_by, submitted_at, hod_status)
  VALUES
    ('GIN-DEMO-001', 'BILL-SUP-2026-104', 'SUP-REAL-002', 'Andhra Steel Traders',
     'SITE-VJA-001', 'TP-VJA-001', 'East Ramp Loading Point', '2026-08-04',
     'pending', 'supervisor@thavvu.com', now(), 'pending')
  RETURNING id INTO v_bill_a;

  INSERT INTO public.gin_bill_items
    (gin_bill_id, item_name, ordered_qty, billed_qty, received_qty, uom, action, action_note)
  VALUES
    (v_bill_a, 'TMT Steel Bar 12mm', 500, 500, 500, 'KG', 'done', 'Received as billed'),
    (v_bill_a, 'TMT Steel Bar 8mm', 300, 300, 250, 'KG', 'reorder',
     'Short by 50 KG — reorder placed');

  -- Bill B (TP-VJA-002): one EXCESS line (received more than billed)
  INSERT INTO public.gin_bills
    (gin_no, bill_number, supplier_id, supplier_name, site_id,
     thavvu_point_id, thavvu_point_name, bill_date, status,
     submitted_by, submitted_at, hod_status)
  VALUES
    ('GIN-DEMO-002', 'BILL-SUP-2026-118', 'SUP-REAL-001', 'Vijay Concrete Mixers',
     'SITE-VJA-001', 'TP-VJA-002', 'River Sand Screening Point', '2026-08-05',
     'pending', 'supervisor@thavvu.com', now(), 'pending')
  RETURNING id INTO v_bill_b;

  INSERT INTO public.gin_bill_items
    (gin_bill_id, item_name, ordered_qty, billed_qty, received_qty, uom, action, action_note)
  VALUES
    (v_bill_b, 'Cement OPC 53 Grade', 200, 200, 215, 'BAG', 'extra',
     'Received 15 BAG extra — reported to HOD'),
    (v_bill_b, 'River Sand', 10, 10, 10, 'CUM', 'done', 'Received as billed');
END $$;
