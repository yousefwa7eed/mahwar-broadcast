import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * حذف صور الطلب من Storage عند انتقاله لحالة نهائية (completed / cancelled).
 *
 * يُستدعى من DB Trigger عبر pg_net (async, fire-and-forget)، لذلك:
 *  - أي فشل هنا لا يؤثر على نجاح تحديث حالة الطلب في قاعدة البيانات.
 *  - كل الخطوات تُسجَّل بوضوح في Function Logs.
 *
 * الأمان: الطلب لا يصلح إلا بحمل سر مشترك (مخزّن في public.order_event_secret)
 * مطابق لقيمة env ORDER_EVENT_SECRET. وإلا 403.
 */

const BUCKET = "order-attachments";
const ENDPOINT_PREFIX = "/storage/v1/object/public/order-attachments/";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-order-event-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

/** يستخرج مسارات الملفات (نسبةً لجذر الباكت) من روابط public المتوقعة. */
function extractPaths(urls: string[] | null): string[] {
  const paths: string[] = [];
  for (const url of urls ?? []) {
    const marker = url.indexOf(ENDPOINT_PREFIX);
    if (marker >= 0) {
      const path = url.slice(marker + ENDPOINT_PREFIX.length);
      if (path.trim().length > 0) {
        paths.push(decodeURIComponent(path));
        continue;
      }
    }
    // fallback: name end-of-path segment فقط
    const seg = url.split("/").filter(Boolean).pop();
    if (seg) paths.push(seg);
  }
  return [...new Set(paths)];
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  // 1) تحقق من السر المشترك (يُقرأ من env فقط — لا يُخزَّن في الكود)
  const expected = Deno.env.get("ORDER_EVENT_SECRET");
  const provided = req.headers.get("x-order-event-secret");
  if (!expected || provided !== expected) {
    console.warn("[delete-order-attachments] unauthorized call (missing/mismatched secret)");
    return json({ error: "unauthorized" }, 403);
  }

  // 2) قراءة الحمولة
  let payload: { order_id?: string; status?: string };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const orderId = payload.order_id;
  const eventStatus = payload.status;
  if (!orderId || !["completed", "cancelled"].includes(eventStatus ?? "")) {
    return json(
      { error: "order_id and a terminal status (completed|cancelled) are required" },
      400,
    );
  }

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  if (!serviceKey || !supabaseUrl) {
    console.error("[delete-order-attachments] missing env (service role/url)");
    return json({ error: "server_not_configured" }, 500);
  }
  const supabase = createClient(supabaseUrl, serviceKey);

  // 3) جلب الطلب للتأكد أنه ما يزال في حالة نهائية (حماية من السباقات)
  const { data: order, error: fetchErr } = await supabase
    .from("orders")
    .select("id, status, attachments, provider_attachments")
    .eq("id", orderId)
    .maybeSingle();

  if (fetchErr) {
    console.error(`[delete-order-attachments] fetch error for ${orderId}:`, fetchErr);
    return json({ error: "fetch_failed" }, 500);
  }
  if (!order) {
    console.warn(`[delete-order-attachments] order not found: ${orderId}`);
    return json({ ok: true, skipped: "order_not_found" });
  }
  if (!["completed", "cancelled"].includes(order.status ?? "")) {
    console.log(`[delete-order-attachments] order ${orderId} no longer terminal (${order.status}); skip`);
    return json({ ok: true, skipped: "status_changed" });
  }

  // 4) حذف كل الملفات المرتبطة من Storage (client + provider)
  const paths = extractPaths([
    ...(order.attachments ?? []),
    ...(order.provider_attachments ?? []),
  ]);

  if (paths.length > 0) {
    const { data: removed, error: removeErr } = await supabase.storage
      .from(BUCKET)
      .remove(paths);

    if (removeErr) {
      // لا نفضّل إفراغ السجل: نترك المرفقات ليتم استردادها/تنظيفها لاحقاً،
      // ونسجّل الخطأ بوضوح للمراجعة.
      console.error(
        `[delete-order-attachments] storage remove FAILED for ${orderId}:`,
        removeErr,
      );
      return json({ error: "storage_remove_failed" }, 502);
    }
    console.log(
      `[delete-order-attachments] removed ${removed?.length ?? 0} of ${paths.length} objects for ${orderId}`,
    );
  } else {
    console.log(`[delete-order-attachments] no attachments to remove for ${orderId}`);
  }

  // 5) إفراغ سجل الطلب بحيث لا يبقى رابط لصورة محذوفة
  const { error: updateErr } = await supabase
    .from("orders")
    .update({ attachments: null, provider_attachments: null, updated_at: new Date().toISOString() })
    .eq("id", orderId);

  if (updateErr) {
    console.error(`[delete-order-attachments] order update FAILED for ${orderId}:`, updateErr);
    return json({ error: "order_update_failed" }, 500);
  }

  console.log(`[delete-order-attachments] finished cleanup for order ${orderId}`);
  return json({ ok: true, deleted: paths.length });
});