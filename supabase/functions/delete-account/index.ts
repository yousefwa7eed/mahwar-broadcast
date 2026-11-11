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

// حذف الحساب لا يُنفَّذ إلا بعد إثبات ملكية رقم الهاتف برمز OTP يُتحقَّق منه
// **على الخادم** — كل الحسابات هاتفية (دخول OTP بلا كلمة مرور)، واشتراط كلمة
// مرور غير موجودة يمنع الحساب الهاتفي من الحذف (مطلوب في App Store 5.1.1(v)
// وGoogle Play account deletion). لا يُقبل أي «تم التحقق» قادم من العميل.
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

    // الرمز إلزامي لتأكيد الحذف.
    let otp: unknown;
    try {
      const body = await req.json();
      otp = body?.otp;
    } catch {
      otp = undefined;
    }

    if (typeof otp !== "string" || otp.trim().length === 0) {
      return json(400, {
        code: "OTP_REQUIRED",
        error: "Verification code is required",
      });
    }

    if (!user.phone) {
      // لا وسيلة للتحقق من الملكية بلا رقم مرتبط بالحساب.
      return json(400, {
        code: "PHONE_VERIFICATION_UNAVAILABLE",
        error: "Phone verification is unavailable for this account",
      });
    }

    const phone = user.phone.startsWith("+") ? user.phone : `+${user.phone}`;

    // عميل مجهول معزول بلا جلسة دائمة ولا تحديث تلقائي: التحقق من الرمز لا
    // يمسّ جلسة الطلب الأصلية ولا يترك أثرًا. لا يُنفّذ أي تنظيف أو حذف قبل
    // نجاح هذا التحقق.
    const verifyClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { auth: { persistSession: false, autoRefreshToken: false } }
    );

    const {
      data: verified,
      error: verifyError,
    } = await verifyClient.auth.verifyOtp({
      phone,
      token: otp.trim(),
      type: "sms",
    });

    if (verifyError) {
      console.error(
        "OTP verification error:",
        verifyError.status,
        verifyError.code
      );
      // 429 = تجاوز محاولات التحقق؛ 5xx/بلا حالة = عطل خدمة (لا نُسمّيه رمزًا
      // خاطئًا)؛ أي رد آخر (400/403/422) = رمز خاطئ أو منتهي الصلاحية.
      if (verifyError.status === 429) {
        return json(429, {
          code: "RATE_LIMITED",
          error: "Too many verification attempts",
        });
      }
      if (!verifyError.status || verifyError.status >= 500) {
        return json(503, {
          code: "VERIFICATION_UNAVAILABLE",
          error: "Verification temporarily unavailable",
        });
      }
      return json(403, {
        code: "INVALID_OTP",
        error: "Verification code is incorrect or expired",
      });
    }

    // الرقم فريد في auth.users، فالرمز الصحيح لرقم هذا الحساب لا يمكن أن يعود
    // بحساب آخر — لكن نتحقق صراحةً حتى لا يتحول أي خلل مستقبلي إلى حذف حساب
    // بجلسة مستخدم آخر.
    if (!verified?.user || verified.user.id !== userId) {
      console.error("OTP verified for a different user");
      return json(403, {
        code: "INVALID_OTP",
        error: "Verification code is incorrect or expired",
      });
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
        signal: AbortSignal.timeout(10000),
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
