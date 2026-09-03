import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * يرسل إشعار دفع (FCM HTTP v1) لأي إشعار داخل التطبيق.
 *
 * يُستدعى من DB Trigger عند إنشاء صف جديد في public.notifications عبر pg_net
 * (async fire-and-forget) بحيث لا يفشل كتابة الإشعار بسبب مشكلة في الدفع.
 * وبهذا يبقى مصدر الإشعار واحداً (جدول notifications) ما يضمن تزامن
 * جرس التنبيهات / صفحة الإشعارات / الجهاز.
 *
 * المصادقة: FCM HTTP v1 باستخدام Service Account JSON
 * (env: FCM_SERVICE_ACCOUNT_JSON — مُعيَّن في Supabase Secrets)
 * ويعمل بصورة أفضل في حال عدم وجود مفتاح (يرجع skipped).
 * الاستدعاء محمي بسر مشترك عبر x-order-event-secret (مثله مثل delete-order-attachments).
 */

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const TOKEN_URL = "https://oauth2.googleapis.com/token";
const FCM_SEND_URL = "https://fcm.googleapis.com/v1/projects/";

// Service Account يُقرأ حصريًا من Supabase Secrets (env) — لا يُخزَّن أي JSON في الكود.
const FCM_SERVICE_ACCOUNT_JSON = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-order-event-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

// -----------------------------------------------------------------------------
// JWT (RS256) + OAuth2 token للـ Service Account
// -----------------------------------------------------------------------------
function b64url(bytes: Uint8Array): string {
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function b64urlEncodeJson(obj: unknown): string {
  return b64url(new TextEncoder().encode(JSON.stringify(obj)));
}

function pemToDer(pem: string): Uint8Array {
  const base64 = pem.replace(/-----.*-----/g, "").replace(/\s+/g, "");
  const bin = atob(base64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

async function createAssertion(sa: Record<string, string>): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: sa.client_email,
    scope: FCM_SCOPE,
    aud: TOKEN_URL,
    iat: now,
    exp: now + 3600,
  };
  const signingInput = `${b64urlEncodeJson(header)}.${b64urlEncodeJson(payload)}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${b64url(new Uint8Array(sig))}`;
}

// caching: التوكن صالح ساعة، والوظيفة قد تعيش أطول؛ نخزّنه بذاكرة الوحدة.
let _tokenCache: { token: string; exp: number } | null = null;

async function getAccessToken(sa: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (_tokenCache && _tokenCache.exp > now + 60) {
    return _tokenCache.token;
  }
  const assertion = await createAssertion(sa);
  const body = new URLSearchParams({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion,
  });
  const res = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`oauth2 token failed ${res.status}: ${text.slice(0, 300)}`);
  }
  const data = await res.json();
  _tokenCache = {
    token: data.access_token as string,
    exp: now + ((data.expires_in as number) ?? 3600),
  };
  return _tokenCache.token;
}

// -----------------------------------------------------------------------------
// بناء نص الإشعار بالعربية (مطابق لعناصر التطبيق)
// -----------------------------------------------------------------------------
function buildTitleBody(type: string, metadata: Record<string, unknown>): { title: string; body: string } {
  const serviceName = metadata["service_name"] as string | undefined;
  const providerName = metadata["provider_name"] as string | undefined;
  const price = metadata["price"];
  const rating = metadata["rating"];

  switch (type) {
    case "new_order":
      return {
        title: "طلب جديد",
        body: serviceName ? `لديك طلب جديد: ${serviceName}` : "لديك طلب جديد",
      };
    case "price_offer":
      return {
        title: "عرض سعر جديد",
        body: providerName && price != null
          ? `${providerName} قدم عرض سعر ${price} ج.م${serviceName ? ` لطلب ${serviceName}` : ""}`
          : "تم استلام عرض سعر جديد",
      };
    case "order_confirmed":
      return { title: "تم تأكيد الطلب", body: "تم تأكيد طلبك بنجاح" };
    case "order_rejected":
      return {
        title: "تم رفض الطلب",
        body: providerName ? `تم رفض الطلب من ${providerName}` : "تم رفض الطلب",
      };
    case "order_cancelled":
      return { title: "تم إلغاء الطلب", body: "تم إلغاء هذا الطلب" };
    case "order_completed":
      return { title: "تم إتمام الطلب", body: "تم إتمام خدمة الطلب بنجاح" };
    case "rating_received":
      return {
        title: "تقييم جديد",
        body: rating != null ? `حصلت على تقييم ${rating} من 5` : "حصلت على تقييم جديد",
      };
    case "new_message":
      return { title: "رسالة جديدة", body: "وصلتك رسالة جديدة" };
    case "broadcast": {
      // إشعار عام: العنوان والنص يأتيان مباشرة من metadata (محددان من المالك).
      const t = metadata["title"];
      const b = metadata["body"];
      return {
        title: typeof t === "string" && t.trim() ? t : "إشعار",
        body: typeof b === "string" && b.trim() ? b : "",
      };
    }
    default:
      return { title: "إشعار جديد", body: "يوجد تحديث جديد لتطبيق محور" };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const expected = Deno.env.get("ORDER_EVENT_SECRET");
  if (!expected || req.headers.get("x-order-event-secret") !== expected) {
    console.warn("[send-push-notification] unauthorized call (missing/mismatched secret)");
    return json({ error: "unauthorized" }, 403);
  }

  let payload: { notification_id?: string };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const notificationId = payload.notification_id;
  if (!notificationId) {
    return json({ error: "notification_id required" }, 400);
  }

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  if (!serviceKey || !supabaseUrl) {
    return json({ error: "server_not_configured" }, 500);
  }
  const supabase = createClient(supabaseUrl, serviceKey);

  // 1) قراءة الإشعار نفسه (المصدر الوحيد للبيانات)
  const { data: notif, error: notifErr } = await supabase
    .from("notifications")
    .select("id, user_id, order_id, type, metadata")
    .eq("id", notificationId)
    .maybeSingle();

  if (notifErr) {
    console.error(`[send-push-notification] fetch error ${notificationId}:`, notifErr);
    return json({ error: "fetch_failed" }, 500);
  }
  if (!notif) {
    return json({ ok: true, skipped: "notification_not_found" });
  }

  // 2) resolve المتلقي + التوكن + الدور
  const { data: profile } = await supabase
    .from("profiles")
    .select("fcm_token, role")
    .eq("id", notif.user_id)
    .maybeSingle();

  const fcmToken = (profile?.fcm_token as string | null) ?? "";
  const role = (profile?.role as string | null) ?? "car_owner";

  // 3) تأكد أن FCM مُهيّأ (env فقط — بدون env نُقصي بأمان)
  if (!FCM_SERVICE_ACCOUNT_JSON) {
    console.log(`[send-push-notification] skip ${notificationId} (FCM not configured yet)`);
    return json({ ok: false, skipped: "fcm_not_configured" });
  }
  let sa: Record<string, string>;
  try {
    sa = JSON.parse(FCM_SERVICE_ACCOUNT_JSON);
  } catch {
    console.warn(`[send-push-notification] invalid FCM_SERVICE_ACCOUNT json for ${notificationId}`);
    return json({ ok: false, skipped: "fcm_not_configured" });
  }

  const metadata = (notif.metadata ?? {}) as Record<string, unknown>;
  const { title, body } = buildTitleBody(notif.type, metadata);

  // صورة الإشعار (إن وُجدت) — تُعرض داخل الإشعار نفسه (rich/large image على Android)
  const imageUrl =
    typeof metadata["image_url"] === "string" ? (metadata["image_url"] as string).trim() : "";

  // deep link اختياري: "home" ينقل المستخدم للرئيسية حسب دوره، أو يكون فارغًا
  // فيُفتح التطبيق على صفحة الإشعارات فقط.
  const deepLink =
    typeof metadata["deep_link"] === "string" ? (metadata["deep_link"] as string).trim() : "";

  // 4) بناء message
  const base: Record<string, unknown> = {
    notification: { title, body },
    data: {
      notification_id: String(notif.id),
      order_id: notif.order_id ? String(notif.order_id) : "",
      type: String(notif.type),
      screen: notif.order_id ? "track" : "notifications",
      deep_link: deepLink,
    },
    android: { priority: "HIGH" },
  };
  if (imageUrl) {
    (base.notification as Record<string, unknown>).image = imageUrl;
    (base.android as Record<string, unknown>).notification = { image: imageUrl };
  }
  if (fcmToken) {
    base.token = fcmToken;
  } else {
    base.condition = role === "provider" ? `'providers' in topics` : `'car_owners' in topics`;
  }

  // 5) إرسال
  try {
    const accessToken = await getAccessToken(sa);
    const res = await fetch(`${FCM_SEND_URL}${sa.project_id}/messages:send`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message: base }),
    });
    if (!res.ok) {
      const text = await res.text();
      console.error(
        `[send-push-notification] FCM send FAILED (${res.status}) for ${notif.id} (${notif.type}): ${text.slice(0, 400)}`,
      );
      return json({ error: "fcm_send_failed", detail: res.status }, 502);
    }
    console.log(
      `[send-push-notification] sent "${notif.type}" to ${fcmToken ? "token" : "topic:" + role} (notification ${notif.id})`,
    );
    return json({ ok: true, sent: true });
  } catch (e) {
    console.error(`[send-push-notification] exception for ${notif.id}:`, e);
    return json({ error: "internal", message: String(e) }, 500);
  }
});