import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * يرسل إشعارًا عامًا (broadcast) لكل المستخدمين المسجّلين.
 *
 * الاستخدام (يدوي من المالك فقط — ليس من التطبيق):
 *   curl -X POST https://trgesfzojaoirutkkfcs.supabase.co/functions/v1/send-broadcast-notification \
 *     -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
 *     -H "x-order-event-secret: $ORDER_EVENT_SECRET" \
 *     -H "Content-Type: application/json" \
 *     -d '{
 *       "title": "عنوان الإشعار (إجباري)",
 *       "body": "التفاصيل/النص الفرعي (إجباري)",
 *       "image_url": "https://.../image.png (اختياري)",
 *       "deep_link": "home (اختياري)"
 *     }'
 *
 * وجهة الضغط (deep_link) اختيارية، وفيها حالتين يفرّق بينهم التطبيق عند الضغط:
 *   - "home": deep link داخلي → يفتح شاشة جوه التطبيق (الرئيسية حسب الدور).
 *   - رابط يبدأ بـ http(s)://: رابط خارجي → يفتح في المتصفح بره التطبيق.
 * أي قيمة غير محددة → يفتح صفحة الإشعارات فقط.
 * (قيمة deep_link تُمرَّر كما هي جوه metadata، فتصل للـ push في data.deep_link
 *  وتظهر في صفحة الإشعارات — بدون أي معالجة هنا.)
 *
 * - المصادقة محصورة بالسر المشترك ORDER_EVENT_SECRET (مثل send-push-notification)
 *   فلا يمكن لأي مستخدم عادي استدعائها من داخل التطبيق.
 * - يقوم بـ batch insert (جملة SQL واحدة) في جدول notifications عبر
 *   insert_broadcast_notifications لكل مستخدم مسجّل، فتُطلق وظيفة notify_push
 *   تلقائيًا لكل صف ليبعث push (بالصورة والـ deep link في data payload) مع حفظه
 *   كاملًا في صفحة الإشعارات.
 */

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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // 1) Owner-only: نفس السر المشترك المُستخدَم في بقية دوال الأحداث.
  const expected = Deno.env.get("ORDER_EVENT_SECRET");
  if (!expected || req.headers.get("x-order-event-secret") !== expected) {
    console.warn("[send-broadcast-notification] unauthorized call");
    return json({ error: "unauthorized" }, 403);
  }

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  if (!serviceKey || !supabaseUrl) {
    return json({ error: "server_not_configured" }, 500);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  // 2) Validation: العنوان والنص إجباريان.
  const title = (payload.title ?? "").toString().trim();
  const body = (payload.body ?? "").toString().trim();
  if (!title || !body) {
    return json({ error: "title and body are required" }, 400);
  }

  const imageUrl = (payload.image_url ?? "").toString().trim();
  const deepLink = (payload.deep_link ?? "").toString().trim();

  // 3) بناء metadata (نفس بنية الإشعارات الموجودة — type='broadcast').
  const metadata: Record<string, unknown> = { title, body };
  if (imageUrl) metadata["image_url"] = imageUrl;
  if (deepLink) metadata["deep_link"] = deepLink;

  // 4) Batch insert لكل المستخدمين (جملة واحدة عبر RPC).
  const supabase = createClient(supabaseUrl, serviceKey);
  const { data, error } = await supabase.rpc("insert_broadcast_notifications", {
    p_metadata: metadata,
  });

  if (error) {
    console.error("[send-broadcast-notification] insert failed:", error);
    return json({ error: "insert_failed", detail: error.message }, 500);
  }

  const count = typeof data === "number" ? data : 0;
  console.log(
    `[send-broadcast-notification] inserted ${count} notifications (title="${title}")`,
  );
  return json({
    ok: true,
    inserted: count,
    type: "broadcast",
    image_url: imageUrl || null,
    deep_link: deepLink || null,
  });
});
