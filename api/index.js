import pg from 'pg';

const pool = new pg.Pool({
  host: process.env.THAVVU_DB_HOST || 'aws-1-ap-northeast-2.pooler.supabase.com',
  port: Number(process.env.THAVVU_DB_PORT || 6543),
  database: process.env.THAVVU_DB_NAME || 'postgres',
  user: process.env.THAVVU_DB_USER || 'postgres.qpecrrhindaegcdfcbuz',
  password: process.env.THAVVU_DB_PASSWORD || 'waswEg-tuxqir-nogga8',
  ssl: { rejectUnauthorized: false },
  max: 3,
});

function json(res, status, body) {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.end(JSON.stringify(body));
}

async function readBody(req) {
  const chunks = [];
  for await (const c of req) chunks.push(c);
  if (!chunks.length) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
  } catch {
    return {};
  }
}

export default async function handler(req, res) {
  if (req.method === 'OPTIONS') {
    return json(res, 204, {});
  }

  const url = new URL(req.url, 'http://localhost');
  const path = url.pathname.replace(/^\/api/, '') || '/';

  try {
    if (req.method === 'GET' && (path === '/' || path === '/ping')) {
      await pool.query('select 1');
      return json(res, 200, { ok: true });
    }

    if (req.method === 'POST' && path === '/login') {
      const body = await readBody(req);
      const email = String(body.email || '').trim();
      const password = String(body.password || '');
      const { rows } = await pool.query(
        `select p.id, p.emp_id, p.full_name, p.email, p.phone, p.role, p.is_active, p.hod_id, c.password_hash
         from profiles p
         join app_credentials c on c.profile_id = p.id
         where lower(p.email) = lower($1) and p.is_active = true
         limit 1`,
        [email],
      );
      if (!rows.length) return json(res, 401, { error: 'Invalid credentials' });
      const hash = rows[0].password_hash || '';
      if (!(hash === `plain:${password}` || hash === password)) {
        return json(res, 401, { error: 'Invalid credentials' });
      }
      delete rows[0].password_hash;
      return json(res, 200, { user: rows[0] });
    }

    if (req.method === 'GET' && path === '/sites') {
      const { rows } = await pool.query('select * from sites order by name');
      return json(res, 200, { data: rows });
    }

    if (req.method === 'GET' && path === '/thavvu-points') {
      const siteId = url.searchParams.get('site_id');
      const { rows } = siteId
        ? await pool.query(
            'select * from thavvu_points where site_id = $1 order by point_name',
            [siteId],
          )
        : await pool.query('select * from thavvu_points order by point_name');
      return json(res, 200, { data: rows });
    }

    if (req.method === 'GET' && path === '/stock-items') {
      const { rows } = await pool.query(
        `select id, code, name, item_name, category, group_name, uom, primary_uom, reorder_level, is_active
         from stock_items where coalesce(is_active, true) = true
         order by category, coalesce(item_name, name)`,
      );
      return json(res, 200, { data: rows });
    }

    if (req.method === 'GET' && path === '/stock-balances') {
      const tp = url.searchParams.get('thavvu_point_id');
      const { rows } = tp
        ? await pool.query(
            'select * from stock_batch_balances where stock_point_id = $1 order by item_name',
            [tp],
          )
        : await pool.query('select * from stock_batch_balances order by item_name limit 500');
      return json(res, 200, { data: rows });
    }

    if (req.method === 'GET' && path === '/suppliers') {
      const siteId = url.searchParams.get('site_id');
      const { rows } = siteId
        ? await pool.query(
            'select * from suppliers where coalesce(active,true)=true and (site_id = $1 or site_id is null) order by name',
            [siteId],
          )
        : await pool.query('select * from suppliers where coalesce(active,true)=true order by name');
      return json(res, 200, { data: rows });
    }

    if (req.method === 'GET' && path === '/activity') {
      const siteId = url.searchParams.get('site_id');
      const from = url.searchParams.get('from');
      const to = url.searchParams.get('to');
      const module = url.searchParams.get('module');
      const filters = [];
      const params = [];
      if (siteId) {
        params.push(siteId);
        filters.push(`site_id = $${params.length}`);
      }
      if (module && module !== 'all') {
        params.push(module);
        filters.push(`module = $${params.length}`);
      }
      if (from) {
        params.push(from);
        filters.push(`created_at >= $${params.length}::timestamptz`);
      }
      if (to) {
        params.push(to);
        filters.push(`created_at < ($${params.length}::date + interval '1 day')`);
      }
      const where = filters.length ? `where ${filters.join(' and ')}` : '';
      const { rows } = await pool.query(
        `select * from app_activity_events ${where} order by created_at desc limit 500`,
        params,
      );
      return json(res, 200, { data: rows });
    }

    if (req.method === 'POST' && path === '/supplier-payments') {
      const body = await readBody(req);
      const { rows } = await pool.query(
        `insert into supplier_payment_requests (
           site_id, supplier_name, amount, bill_amount, used_amount,
           request_type, method, status, payment_proof, requested_at, hod_id
         ) values ($1,$2,$3,$4,$5,$6,$7,'pending',$8,now(),$9::uuid)
         returning *`,
        [
          body.site_id,
          body.supplier_name,
          body.amount,
          body.bill_amount ?? body.amount,
          body.used_amount ?? 0,
          body.request_type || 'payment',
          body.method || 'upi',
          body.payment_proof || null,
          body.hod_id || null,
        ],
      );
      return json(res, 201, { data: rows[0] });
    }

    return json(res, 404, { error: `Unknown route ${path}` });
  } catch (e) {
    return json(res, 500, { error: String(e?.message || e) });
  }
}
