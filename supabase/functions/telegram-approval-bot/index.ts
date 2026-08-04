// Telegram approval bot for the Thavvu HOD login gate.
//
// Endpoints (deploy with --no-verify-jwt so Telegram's webhook can reach it):
//   POST /send     { token, email }  -> DM the owner with the approval prompt
//   POST /webhook  Telegram update    -> record owner chat on /start; approve
//                                        when the reply references a pending token
//   GET  /health
//
// Secrets (supabase secrets set):
//   TELEGRAM_BOT_TOKEN            - bot token from @BotFather
//   SUPABASE_SERVICE_ROLE_KEY     - service/secret key (server-side calls)
//   OWNER_TELEGRAM_CHAT_ID        - optional; if set it overrides auto-discovery
//   TELEGRAM_WEBHOOK_SECRET       - optional; checked against the
//                                   X-Telegram-Bot-Api-Secret-Token header
//
// The bot token must NEVER be placed in the Flutter app.
import { createClient } from "npm:@supabase/supabase-js@2";

const BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const OWNER_CHAT = Deno.env.get("OWNER_TELEGRAM_CHAT_ID") ?? "";
const WEBHOOK_SECRET = Deno.env.get("TELEGRAM_WEBHOOK_SECRET") ?? "";
const PROJECT_URL = "https://qpecrrhindaegcdfcbuz.supabase.co";
const TG_API = `https://api.telegram.org/bot${BOT_TOKEN}`;

const supabase = createClient(PROJECT_URL, SERVICE_KEY);

// Browser (Flutter web) clients trigger a CORS preflight before the real
// call, so every response must advertise the allowed methods/headers.
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "apikey, authorization, content-type, accept, x-client-info, x-telegram-bot-api-secret-token",
  "Access-Control-Max-Age": "86400",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json", ...CORS },
  });
}

async function getOwnerChat(): Promise<string | null> {
  if (OWNER_CHAT) return OWNER_CHAT;
  try {
    const { data } = await supabase.rpc("get_owner_chat");
    const chat = typeof data === "string" && data ? data : null;
    return chat;
  } catch {
    return null;
  }
}

async function sendTelegram(chatId: string, text: string): Promise<boolean> {
  try {
    const res = await fetch(`${TG_API}/sendMessage`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ chat_id: chatId, text }),
    });
    return res.ok;
  } catch {
    return false;
  }
}

async function approveLatestPending(replyText: string): Promise<boolean> {
  try {
    const { data } = await supabase
      .from("hod_login_approvals")
      .select("request_token")
      .eq("status", "pending")
      .order("requested_at", { ascending: false })
      .limit(1);
    if (!data || data.length === 0) return false;
    const token = data[0].request_token as string;
    const lower = (replyText ?? "").trim().toLowerCase();
    // The owner replies with the token or "okay send".
    const matches = lower.includes(token.toLowerCase()) || lower.includes("okay");
    if (!matches) return false;
    await supabase.rpc("approve_hod_login_request", {
      p_token: token,
      p_response: replyText,
    });
    return true;
  } catch {
    return false;
  }
}

async function handleWebhook(req: Request): Promise<Response> {
  // Optional shared-secret guard (recommended) if a webhook secret is set.
  if (WEBHOOK_SECRET) {
    const header = req.headers.get("x-telegram-bot-api-secret-token") ?? "";
    if (header !== WEBHOOK_SECRET) return json({ ok: false }, 403);
  }
  const update = await req.json();
  const msg = update?.message;
  if (!msg?.chat) return json({ ok: true });

  const chatId = msg.chat.id;
  const username = msg.chat.username ?? "";
  const text = (msg.text ?? "").trim();

  // Owner discovery: any /start (or any inbound message) records the chat.
  if (chatId) {
    await supabase.rpc("record_owner_chat", {
      p_chat_id: String(chatId),
      p_username: username || null,
    });
    // Tell the owner it's set up.
    if (text.toLowerCase() === "/start") {
      await sendTelegram(
        String(chatId),
        "Thavvu owner approval bot ready. When a HOD requests approval you'll get the request here — reply with the code or \"okay send\".",
      );
    }
  }

  await approveLatestPending(text);
  return json({ ok: true });
}

async function handleSend(req: Request): Promise<Response> {
  const body = await req.json();
  const token = body?.token ?? "";
  const email = body?.email ?? "";
  if (!token) return json({ ok: false, error: "missing token" }, 400);

  const chatId = await getOwnerChat();
  if (!chatId) {
    return json({
      ok: false,
      reason: "owner_not_started",
      hint: "Ask the owner to open the bot in Telegram and send /start first.",
    });
  }
  const text =
    "Thavvu — HOD login approval requested.\n" +
    `Email: ${email}\n` +
    `Request: ${token}\n` +
    "Reply \"okay send\" to approve.";
  const sent = await sendTelegram(chatId, text);
  return json({ ok: sent });
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const rawPath = url.pathname.split("/").filter(Boolean).pop() ?? "";
  // The app invokes the function by name (base URL) for the "send" action —
  // that resolves to the function slug itself, so default it to /send.
  const path = rawPath === "telegram-approval-bot" ? "send" : rawPath;

  if (req.method === "OPTIONS") {
    // Preflight: must be a 204 with NO body (a 204 with a body errors the
    // edge runtime and produces a 500).
    return new Response(null, { status: 204, headers: CORS });
  }
  switch (path) {
    case "health":
      return json({ ok: true });
    case "webhook":
      return await handleWebhook(req);
    case "send":
      return await handleSend(req);
    default:
      return json({ ok: false, error: "unknown path" }, 404);
  }
});