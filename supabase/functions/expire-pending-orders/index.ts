import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * يُلغى تلقائياً أي طلب (pending) مُرسَل إلى مزوّد ولم يُستجب له خلال
 * respond_deadline (افتراضياً 3 دقائق من لحظة الإسناد `assign_order_to_provider`).
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
    // 1) نحدد الطلبات منتهية المهلة فقط: مُسندة لمزوّد، ما تزال pending،
    //    والموعد فات (respond_deadline < now()). نُغيّر الحالة ونسترجع الصفوف.
    const nowIso = new Date().toISOString();

    const { data: expired, error: updateErr } = await supabase
      .from("orders")
      .update({
        status: "cancelled",
        respond_deadline: null,
        updated_at: nowIso,
      })
      .eq("status", "pending")
      .not("provider_id", "is", null)
      .not("respond_deadline", "is", null)
      .lt("respond_deadline", nowIso)
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