import { createClient } from "jsr:@supabase/supabase-js@2";
import { buildTitleBody, normalizeLanguage } from "./notification_text.ts";

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
// نص الإشعار (عربي/إنجليزي) انتقل إلى notification_text.ts ليخضع لاختبارات
// الوحدة (notification_text_test.ts) بدون اعتماد على أي واجهة Deno.
// -----------------------------------------------------------------------------

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

  // 2) resolve المتلقي + التوكن + الدور + اللغة المفضّلة
  const { data: profile } = await supabase
    .from("profiles")
    .select("fcm_token, role, language")
    .eq("id", notif.user_id)
    .maybeSingle();

  if (!profile?.fcm_token) {
    console.log(
      `[send-push-notification] skip ${notif.id} type=${notif.type} reason=no_token user=${notif.user_id ?? "null"}`,
    );
    return json({ ok: true, skipped: "no_token" });
  }

  const fcmToken = profile.fcm_token as string;
  const role = (profile.role as string | null) ?? "car_owner";
  // لغة المستقبِل (profiles.language) — أي قيمة غير "en" تُعامل كعربية.
  const language = normalizeLanguage(profile.language);

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

  // اسم الخدمة المعروض: يُقرأ من service_types عبر metadata.service_type_id
  // بلغة المستقبِل (name_en/name_ar)؛ وإن تعذّر نرجع إلى metadata.service_name،
  // وإن غاب كلاهما تُحذف لاحقة اسم الخدمة من النص (داخل buildTitleBody).
  let serviceNameFromDb: string | null = null;
  const serviceTypeId = metadata["service_type_id"];
  if (typeof serviceTypeId === "string" && serviceTypeId.trim()) {
    const { data: serviceType } = await supabase
      .from("service_types")
      .select("name_ar, name_en")
      .eq("id", serviceTypeId)
      .maybeSingle();
    if (serviceType) {
      const name = language === "en" ? serviceType.name_en : serviceType.name_ar;
      serviceNameFromDb = typeof name === "string" && name.trim() ? name : null;
    }
  }

  const { title, body } = buildTitleBody(notif.type, metadata, language, serviceNameFromDb);

  // صورة الإشعار (إن وُجدت) — تُعرض داخل الإشعار نفسه (rich/large image على Android)
  const imageUrl =
    typeof metadata["image_url"] === "string" ? (metadata["image_url"] as string).trim() : "";

  // deep link اختياري: "home" ينقل المستخدم للرئيسية حسب دوره، أو يكون فارغًا
  // فيُفتح التطبيق على صفحة الإشعارات فقط.
  const deepLink =
    typeof metadata["deep_link"] === "string" ? (metadata["deep_link"] as string).trim() : "";

  // الشاشة المستهدفة عند لمس الإشعار — جدول واحد موحّد حسب دور المستقبِل
  // ونوع الإشعار (مطابق لجانب العميل: PushNotificationService.resolveOrderRoute):
  //   provider + new_order       → quote (شاشة القبول/عرض السعر)
  //   provider + order_confirmed → provider_home (بطاقة الطلب فيها زر «إتمام الطلب»)
  //   provider + rating_received → notifications (يفتحها العميل على شاشة تفاصيل التقييم)
  //   provider + rejected/cancelled → track (كتلة الحالة العامة + عودة للرئيسية)
  //   car_owner + أي نوع مرتبط بطلب → track (شاشة التتبع بأزرارها)
  //   لا يوجد طلب مرتبط         → notifications
  // أي تركيبة غير مذكورة أعلاه → track، وفي غياب order_id → notifications.
  let screen =
    notif.type === "shift_started" || notif.type === "shift_ended"
      ? "provider_home"
      : !notif.order_id
        ? "notifications"
        : role === "provider"
          ? (notif.type === "new_order"
              ? "quote"
              : notif.type === "order_confirmed"
                ? "provider_home"
                : notif.type === "rating_received"
                  ? "notifications"
                  : "track")
          : "track";

  // إن كانت الوجهة شاشة إجرائية (quote/provider_home) لكن الطلب انتهى
  // (مكتمل/مرفوض/ملغى) نحوله لشاشة التتبع (ملخّص المعاملة) بدل فتح إجراء لم
  // يعد صالحاً — نفس منطق العميل (PushNotificationService.orderIsFinalized).
  if (notif.order_id && (screen === "quote" || screen === "provider_home")) {
    const { data: order } = await supabase
      .from("orders")
      .select("status")
      .eq("id", notif.order_id)
      .maybeSingle();
    const status = (order?.status as string | undefined) ?? "";
    if (
      status === "completed" ||
      status === "rejected_by_provider" ||
      status === "rejected_by_owner" ||
      status === "cancelled"
    ) {
      screen = "track";
    }
  }

  // 4) بناء message
  const base: Record<string, unknown> = {
    notification: { title, body },
    data: {
      notification_id: String(notif.id),
      order_id: notif.order_id ? String(notif.order_id) : "",
      type: String(notif.type),
      screen,
      deep_link: deepLink,
    },
    android: {
      priority: "HIGH",
      notification: { channel_id: "mahwar_alerts" },
    },
  };
  if (imageUrl) {
    (base.notification as Record<string, unknown>).image = imageUrl;
    const androidNotif = (base.android as Record<string, unknown>)
      .notification as Record<string, unknown>;
    androidNotif.image = imageUrl;
  }
  base.token = fcmToken;

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
      let deadToken = false;
      try {
        const body = JSON.parse(text);
        const fcmStatus = body?.error?.status ?? "";
        const details: Array<Record<string, unknown>> = body?.error?.details ?? [];
        const hasUnregistered = details.some(
          (d) => d?.errorCode === "UNREGISTERED",
        );
        const tokenFieldViolated = details
          .flatMap((d) =>
            Array.isArray(d?.fieldViolations)
              ? (d?.fieldViolations as Array<{ field?: unknown }>)
              : [],
          )
          .some((v) => v?.field === "message.token");
        deadToken =
          hasUnregistered ||
          (fcmStatus === "INVALID_ARGUMENT" && tokenFieldViolated);
      } catch {
        deadToken = false;
      }
      if (deadToken && notif.user_id && fcmToken) {
        await supabase
          .from("profiles")
          .update({ fcm_token: null })
          .eq("id", notif.user_id)
          .eq("fcm_token", fcmToken);
        console.log(
          `[send-push-notification] dead token cleared for user ${notif.user_id} (notification ${notif.id}, type=${notif.type}, fcm_status=${res.status})`,
        );
        return json({ ok: true, recovered: "dead_token" });
      }
      console.error(
        `[send-push-notification] FCM send FAILED (${res.status}) for ${notif.id} (${notif.type}): ${text}`,
      );
      return json({ error: "fcm_send_failed", detail: res.status }, 502);
    }
    console.log(
      `[send-push-notification] sent "${notif.type}" to token (notification ${notif.id})`,
    );
    return json({ ok: true, sent: true });
  } catch (e) {
    console.error(`[send-push-notification] exception for ${notif.id}:`, e);
    return json({ error: "internal", message: String(e) }, 500);
  }
});