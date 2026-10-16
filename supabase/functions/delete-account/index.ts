import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const json = (status: number, payload: Record<string, unknown>) =>
  new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json(401, { error: "Missing authorization header" });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();
    if (userError || !user) {
      return json(401, { error: "Unauthorized" });
    }

    const userId = user.id;

    // كلمة المرور الحالية إلزامية لتأكيد الحذف.
    let password: unknown;
    try {
      const body = await req.json();
      password = body?.password;
    } catch {
      password = undefined;
    }

    if (typeof password !== "string" || password.length === 0) {
      return json(400, {
        code: "PASSWORD_REQUIRED",
        error: "Current password is required",
      });
    }

    if (!user.email) {
      // لا وسيلة للتحقق من كلمة المرور بلا بريد مرتبط بالحساب.
      return json(400, {
        code: "PASSWORD_VERIFICATION_UNAVAILABLE",
        error: "Password verification is unavailable for this account",
      });
    }

    // التحقق من كلمة المرور على عميل مجهول معزول بلا جلسة دائمة ولا تحديث
    // تلقائي — لا يمسّ جلسة الطلب الأصلية ولا يترك أثرًا. لا يُنفّذ أي تنظيف
    // أو حذف قبل نجاح هذا التحقق.
    const verifyClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { auth: { persistSession: false, autoRefreshToken: false } }
    );

    const { error: signInError } = await verifyClient.auth.signInWithPassword({
      email: user.email,
      password,
    });

    if (signInError) {
      // 400 من الخدمة = اعتماد خاطئ؛ أي رمز آخر (شبكة/خادم) خطأ غير متوقع.
      if (signInError.status === 400) {
        return json(403, {
          code: "INVALID_PASSWORD",
          error: "Current password is incorrect",
        });
      }
      console.error("Password verification error:", signInError);
      return json(500, { error: "Failed to verify password" });
    }

    const { error: cleanupError } = await supabaseAdmin.rpc(
      "cleanup_user_data",
      { p_user_id: userId }
    );
    if (cleanupError) {
      console.error("Cleanup error:", cleanupError);
      return json(500, { error: "Failed to clean up user data" });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const deleteResponse = await fetch(
      `${supabaseUrl}/auth/v1/admin/users/${userId}`,
      {
        method: "DELETE",
        headers: {
          Authorization: `Bearer ${serviceRoleKey}`,
          apikey: serviceRoleKey!,
        },
      }
    );

    if (!deleteResponse.ok) {
      const errBody = await deleteResponse.text();
      console.error("Delete user error:", deleteResponse.status, errBody);
      return json(500, { error: "Failed to delete user from auth" });
    }

    return json(200, { message: "Account deleted successfully" });
  } catch (err) {
    console.error("Unexpected error:", err);
    return json(500, { error: "Internal server error" });
  }
});
