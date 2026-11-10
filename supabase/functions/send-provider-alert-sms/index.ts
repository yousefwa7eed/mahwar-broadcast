// =============================================================================
// send-provider-alert-sms — يرسل رسالة SMS واحدة للمزوّد الغائب بناءً على
// طلب مالكه (البند 2: «SMS للمزوّد الغائب»).
//
// يُستدعى من التطبيق (شاشة التتبع بعد 30 ثانية) بـ JWT المستخدم — لا
// ORDER_EVENT_SECRET: الفاعل هنا عميل عادي، والتحقق كله من التوثيق والبيانات:
//   1. التحقق من هوية المستخدم عبر GoTrue (Authorization header).
//   2. فحص الحالة عبر RPC `order_provider_alert_status` بنفس جلسة المستخدم —
//      يشمل: ملكية الطلب، بقاء الطلب pending، تسجيل خروج المزوّد داخل نافذة
//      الساعتين، عدم وجود تنبيه سابق لنفس الطلب، الحصة الشهرية (شهر القاهرة)
//      والسقف اليومي المجمّع (يوم القاهرة). لا نعيد حساب التواريخ هنا —
//      قاعدة البيانات هي المرجع الوحيد.
//   3. حجز صف `result='sending'` قبل أي نداء خارجي؛ الفهرس الفريد الجزئي على
//      (order_id) يمنع إرسالين متزامنين — تعارض 23505 = already_sent.
//   4. إرسال عبر ZADX ثم تحديث الصف إلى sent/failed. الفشل → 'failed' خارج
//      الفهرس فيُسمح بمحاولة ثانية، ولا تُحرق الحصة الشهرية (تُحتسب فقط في
//      السقف اليومي، مطابقةً لدالة الحالة).
//
// ZADX (نفس حساب OTP): المسار والجسم مأخوذان حرفيًا من مثال المزوّد العامل
// المُتحقَّق منه 2026-11-10:
//   POST {ZADX_BASE_URL}/sms/send
//   headers: X-Api-Key, X-Api-Secret, Idempotency-Key
//   body:    { "to": "01xxxxxxxxx", "message": "..." }   ← الرقم بصيغة محلية
// ملاحظة: على عكس /otp/send هنا لا يُرسل sender_id ولا locale في الجسم.
//
// متغيرات النشر: ZADX_API_KEY / ZADX_API_SECRET (نفس قيم send-sms-hook)،
// وZADX_BASE_URL اختياري (الافتراضي هو المعروف).
//
// قواعد صارمة: لا سجلات تحتوي رقمًا أو نص الرسالة أو أي سر. لا إعادة محاولة
// تلقائية. التطبيق يحوّل رموز الرد إلى نصوص عربية عبر ARB؛ لا نص خادم للعميل.
// =============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const ALERT_SMS_TEXT = "طلب جديد طارئ على محور، افتح التطبيق";

const ZADX_API_KEY = Deno.env.get("ZADX_API_KEY") ?? "";
const ZADX_API_SECRET = Deno.env.get("ZADX_API_SECRET") ?? "";
const ZADX_BASE_URL = (Deno.env.get("ZADX_BASE_URL") ?? "https://smsapi.zadx.net/api/v1").replace(/\/+$/, "");
// مسار SMS العادية — من مثال ZADX العامل (ليس تخمينًا).
const ZADX_SMS_URL = `${ZADX_BASE_URL}/sms/send`;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

/** Normalizes an arbitrary phone input to Egyptian E.164 ("+2010..."). Returns null when not Egyptian mobile. */
function toEgyptianE164(raw: string): string | null {
  let s = (raw ?? "").replace(/[\s\-().]/g, "");
  if (s.startsWith("00")) s = s.slice(2);
  if (s.startsWith("+")) s = s.slice(1);
  if (s.startsWith("20") && s.length === 12) {
    s = s.slice(2);
  } else if (s.startsWith("0") && s.length === 11) {
    s = s.slice(1);
  }
  if (/^1[0125][0-9]{8}$/.test(s)) return "+20" + s;
  return null;
}

/** "+2010..." -> "010..." — الصيغة المحلية التي يقبلها /sms/send في مثال ZADX. */
function toLocalForm(e164: string): string {
  return "0" + e164.slice(3);
}

function zadxErrorCode(status: number): string {
  if (status === 429) return "zadx_rate_limited";
  if (status === 402) return "zadx_insufficient_credits";
  if (status >= 500) return "zadx_provider_error";
  return `zadx_http_${status}`;
}

async function zadxSendSms(phoneLocal: string, orderId: string): Promise<{ ok: boolean; idempotent: boolean; status: number }> {
  let res: Response;
  try {
    res = await fetch(ZADX_SMS_URL, {
      method: "POST",
      signal: AbortSignal.timeout(8000),
      headers: {
        "Content-Type": "application/json",
        "X-Api-Key": ZADX_API_KEY,
        "X-Api-Secret": ZADX_API_SECRET,
        // Deterministic per order (same 24h replay semantics as OTP): a retried
        // request for the same order can never deliver twice.
        "Idempotency-Key": `order-alert-${orderId}`,
      },
      // مطابق لمثال ZADX العامل: to (محلي) + message فقط.
      body: JSON.stringify({ to: phoneLocal, message: ALERT_SMS_TEXT }),
    });
  } catch {
    return { ok: false, idempotent: false, status: 0 };
  }

  // 409: ZADX already accepted this idempotency key → treat as delivered.
  if (res.status === 409) return { ok: true, idempotent: true, status: res.status };
  if (res.ok) return { ok: true, idempotent: false, status: res.status };

  let bodyText = "";
  try {
    bodyText = await res.text();
  } catch {
    bodyText = "<unreadable>";
  }
  const sanitized = bodyText.replace(/\d{5,}/g, "***").slice(0, 300);
  console.error(`[send-provider-alert-sms] ZADX non-2xx: status=${res.status} body="${sanitized}"`);
  return { ok: false, idempotent: false, status: res.status };
}

/** Maps `order_provider_alert_status.reason` to the client error contract. */
function reasonToError(reason: string): { code: string; status: number } | null {
  switch (reason) {
    case "ok":
      return null;
    case "provider_active":
      return { code: "provider_active", status: 409 };
    case "order_not_pending":
      return { code: "order_not_pending", status: 409 };
    case "already_alerted":
      return { code: "already_sent", status: 409 };
    case "monthly_quota_used":
      return { code: "monthly_quota_used", status: 409 };
    case "daily_cap_reached":
      return { code: "daily_cap_reached", status: 429 };
    default:
      return { code: "failed", status: 409 };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error("[send-provider-alert-sms] supabase env missing");
    return json({ error: "server_not_configured" }, 500);
  }
  if (!ZADX_API_KEY || !ZADX_API_SECRET) {
    console.error("[send-provider-alert-sms] ZADX API credentials missing");
    return json({ error: "server_not_configured" }, 500);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return json({ error: "unauthenticated" }, 401);
  }

  let orderId = "";
  try {
    const body = await req.json();
    orderId = typeof body?.order_id === "string" ? body.order_id.trim() : "";
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(orderId)) {
    return json({ error: "invalid_order_id" }, 400);
  }

  // 1) User context: anon client carrying the caller's JWT (never service role).
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return json({ error: "unauthenticated" }, 401);
  }

  // 2) All eligibility + quota rules live in the SQL function (Cairo month/day).
  const { data: statusRows, error: statusErr } = await userClient.rpc(
    "order_provider_alert_status",
    { p_order_id: orderId },
  );
  if (statusErr) {
    const msg = statusErr.message ?? "";
    if (msg.includes("ORDER_NOT_FOUND")) return json({ error: "order_not_found" }, 404);
    if (msg.includes("NOT_OWNER")) return json({ error: "not_owner" }, 403);
    if (msg.includes("NOT_AUTHENTICATED")) return json({ error: "unauthenticated" }, 401);
    console.error(`[send-provider-alert-sms] status rpc failed: ${msg.slice(0, 120)}`);
    return json({ error: "failed" }, 500);
  }
  const statusRow = Array.isArray(statusRows) ? statusRows[0] : statusRows;
  const reason = typeof statusRow?.reason === "string" ? statusRow.reason : "";
  const mapped = reasonToError(reason);
  if (mapped) return json({ error: mapped.code }, mapped.status);

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // 3) Provider phone + id (service role: phone is never exposed to a client).
  const { data: orderRow, error: orderErr } = await admin
    .from("orders")
    .select("provider_id")
    .eq("id", orderId)
    .single();
  if (orderErr || !orderRow?.provider_id) {
    return json({ error: "failed" }, 500);
  }
  const providerId = orderRow.provider_id as string;

  const { data: profileRow, error: profileErr } = await admin
    .from("profiles")
    .select("phone_number")
    .eq("id", providerId)
    .single();
  const phoneE164 = toEgyptianE164(
    profileErr ? "" : (typeof profileRow?.phone_number === "string" ? profileRow.phone_number : ""),
  );
  if (!phoneE164) {
    console.error("[send-provider-alert-sms] provider phone unavailable/invalid");
    return json({ error: "provider_phone_unavailable" }, 409);
  }

  // 4) Atomic reservation — the partial unique index is the concurrency lock.
  const { data: reserved, error: reserveErr } = await admin
    .from("provider_alert_sms_log")
    .insert({
      provider_id: providerId,
      order_id: orderId,
      phone_e164: phoneE164,
      result: "sending",
    })
    .select("id")
    .single();
  if (reserveErr) {
    if ((reserveErr as { code?: string }).code === "23505") {
      return json({ error: "already_sent" }, 409);
    }
    console.error(`[send-provider-alert-sms] reservation insert failed: ${reserveErr.message.slice(0, 120)}`);
    return json({ error: "failed" }, 500);
  }
  const logId = reserved.id as number;

  // 5) Deliver — العمود يُحفظ E.164 للمراجعة، والإرسال بالصيغة المحلية.
  const z = await zadxSendSms(toLocalForm(phoneE164), orderId);
  if (z.ok) {
    await admin
      .from("provider_alert_sms_log")
      .update({ result: "sent", error_code: z.idempotent ? "zadx_idempotent_replay" : null })
      .eq("id", logId);
    console.info(`[send-provider-alert-sms] alert SMS sent (order ${orderId.slice(0, 8)}…)`);
    return json({ ok: true, idempotent: z.idempotent });
  }

  const errorCode = zadxErrorCode(z.status);
  await admin
    .from("provider_alert_sms_log")
    .update({ result: "failed", error_code: errorCode })
    .eq("id", logId);
  console.error(`[send-provider-alert-sms] ZADX send failed (${errorCode})`);
  return json({ error: "failed" }, 502);
});
