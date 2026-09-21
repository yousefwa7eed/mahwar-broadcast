import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * يُلغى تلقائياً أي طلب (pending) لم يكتمل خلال المهلة التي اختارها العميل
 * نفسه، وهي respond_deadline (افتراضياً 5 دقائق من لحظة إنشاء الطلب عبر
 * خيار "إلغاء الطلب بعد 5 دقائق" — auto_cancel = true).
 *
 * الطلبات التي عطّل العميل لها الإلغاء التلقائي (auto_cancel = false) لا تُلغى
 * هنا إطلاقاً.
 *
 * يُستدعى كل دقيقة عبر pg_cron → net.http_post (مؤمّن بـ x-order-event-secret).
 * عند الإلغاء: يُسجَّل إشعار 'order_cancelled' للمالك (مما يشغّل إشعار الدفع
 * آلياً عبر trigger notifications_push). الـ trigger order_terminal_cleanup
 * سيُشرف على حذف مرفقات الطلب من Storage (قائم بالفعل).
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

  const expected = Deno.env.get("ORDER_EVENT_SECRET");
  if (!expected || req.headers.get("x-order-event-secret") !== expected) {
    return json({ error: "unauthorized" }, 403);
  }

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  if (!serviceKey || !supabaseUrl) {
    return json({ error: "server_not_configured" }, 500);
  }
  const supabase = createClient(supabaseUrl, serviceKey);

  try {
    // 1) نحدد الطلبات منتهية المهلة فقط: ما تزال pending، والعميل فعّل
    //    الإلغاء التلقائي (auto_cancel = true). شرط الـ deadline له فرعان
    //    (احتياط للطلبات القديمة التي سبق إنشاؤها قبل تفعيل الخيار، فتبقى
    //    قيمة respond_deadline فيها NULL معلّقة pending للأبد):
    //      a) respond_deadline محدد وسابق على now()  ← انتهى موعده طبيعياً.
    //      b) respond_deadline فارغ لكن مُنشأ قبل أكثر من 5 دقائق ← طلب عالق
    //         قديم، نعتبر منشأه هو موعد انتهائه ويُلغى الآن.
    const nowIso = new Date().toISOString();
    const createdBeforeCutoff = new Date(Date.now() - 5 * 60 * 1000).toISOString();

    const { data: expired, error: updateErr } = await supabase
      .from("orders")
      .update({
        status: "cancelled",
        respond_deadline: null,
        updated_at: nowIso,
      })
      .eq("status", "pending")
      .eq("auto_cancel", true)
      .or(
        `and(respond_deadline.is.null,created_at.lt.${createdBeforeCutoff}),` +
          `and(respond_deadline.not.is.null,respond_deadline.lt.${nowIso})`,
      )
      .select("id, car_owner_id, service_type_id");

    if (updateErr) {
      console.error("[expire-pending-orders] update error:", updateErr);
      return json({ error: "update_failed" }, 500);
    }

    const rows = expired ?? [];
    if (rows.length === 0) {
      return json({ ok: true, expired: 0 });
    }

    // 2) إشعار المالك لكل طلب مُلغى (يفرّع الدفع تلقائياً عبر notify_push)
    const notifications = rows.map((o) => ({
      user_id: o.car_owner_id,
      order_id: o.id,
      type: "order_cancelled" as const,
      metadata: { by: "timeout" },
    }));

    const { error: notifErr } = await supabase
      .from("notifications")
      .insert(notifications);

    if (notifErr) {
      console.error("[expire-pending-orders] notify error:", notifErr);
      return json({ error: "notify_failed", expired: rows.length }, 500);
    }

    console.log(
      `[expire-pending-orders] auto-cancelled ${rows.length} order(s): ` +
        rows.map((o) => o.id).join(", "),
    );
    return json({ ok: true, expired: rows.length });
  } catch (e) {
    console.error("[expire-pending-orders] exception:", e);
    return json({ error: "internal", message: String(e) }, 500);
  }
});