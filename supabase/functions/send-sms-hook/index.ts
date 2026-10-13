// =============================================================================
// send-sms-hook — Supabase Auth "Send SMS" HTTP hook (ZADX OTP delivery).
//
// Invoked by gotrue BEFORE an OTP is deemed sent. Responsibilities:
//   1. Verify the Standard Webhooks signature against SMS_HOOK_SIGNING_SECRET.
//   2. Normalize the phone to an Egyptian E.164 (+201xxxxxxxxx) — this hook
//      only supports Egyptian mobile numbers; anything else is refused.
//   3. Identity rule: only deliver when the target user is a real / confirmed
//      account (email signups have confirmed_at, phone users confirming /
//      resending have phone_confirmed_at). A brand-new phone-only user created
//      straight from /otp has neither → the SMS is blocked, so an unverified
//      phone can never self-create an account through SMS delivery.
//   3b. Destination: use sms.phone — gotrue's own computed target (the NEW
//      number for a phone change, the sign-in number otherwise). This is
//      authoritative and immune to a stale auth.users.phone_change. Only if
//      sms.phone is absent (older gotrue) do we fall back to user.new_phone,
//      honoured only while live (phone_change_sent_at within
//      sms_cap_config.otp_expiry_seconds); an expired change is then cleared
//      server-side so it cannot shadow a later sign-in OTP.
//   4. Daily budget caps (per-phone / global) read from sms_cap_config.
//      Caps count ONLY rows with result = 'sent'; 'rejected' / 'failed' /
//      'dryrun' rows are recorded but never eat into the budget.
//   5. Then deliver. With SMS_DRY_RUN=true the function returns 200 without
//      calling ZADX and records result='dryrun' — lets us prove the whole
//      hook/SQL wiring works without spending a single SMS credit.
//
// Failure semantics (Standard Webhooks): returning 400/403 → gotrue surfaces
// an error and does NOT retry. Returning 429/503 would look like a transient
// failure and gotrue would retry — we deliberately avoid 429/503 so a ZADX
// outage never turns into a retry storm. No retries happen inside this
// function either; gotrue itself throttles a phone to one OTP / 60s before
// this hook even fires, and ZADX has a 24h idempotency key per phone:otp.
//
// Hard rules: NEVER log the OTP, a phone number, or any secret; no auto-retry.
// =============================================================================

import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";
import { createClient } from "jsr:@supabase/supabase-js@2";

const ZADX_API_KEY = Deno.env.get("ZADX_API_KEY") ?? "";
const ZADX_API_SECRET = Deno.env.get("ZADX_API_SECRET") ?? "";
const ZADX_BASE_URL = (Deno.env.get("ZADX_BASE_URL") ?? "https://smsapi.zadx.net/api/v1").replace(/\/+$/, "");
const ZADX_SENDER_ID = Deno.env.get("ZADX_SENDER_ID") ?? "ZADX";
const SMS_HOOK_SIGNING_SECRET = Deno.env.get("SMS_HOOK_SIGNING_SECRET") ?? "";
const SMS_DRY_RUN = ["true", "1", "yes"].includes((Deno.env.get("SMS_DRY_RUN") ?? "").toLowerCase());
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, webhook-id, webhook-timestamp, webhook-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

function hooksSecret(): string {
  let s = SMS_HOOK_SIGNING_SECRET.trim();
  for (const prefix of ["v1,whsec_", "whsec_", "v1,"]) {
    if (s.startsWith(prefix)) {
      s = s.slice(prefix.length);
      break;
    }
  }
  return s;
}

/** Normalizes an arbitrary phone input to Egyptian E.164 ("+2010..."). Returns null when not Egyptian mobile. */
function toEgyptianE164(raw: string): string | null {
  let s = (raw ?? "").replace(/[\s\-().]/g, "");
  if (s.startsWith("00")) s = s.slice(2);
  if (s.startsWith("+")) s = s.slice(1);
  if (s.startsWith("20") && s.length === 12) {
    s = s.slice(2); // "+20"/"20" country code already present
  } else if (s.startsWith("0") && s.length === 11) {
    s = s.slice(1); // local 010xxxxxxxxx form — drop the leading "0"
  }
  if (/^1[0125][0-9]{8}$/.test(s)) return "+20" + s; // Egypt national: 10x 8 digits
  return null;
}

/** "+2010..." -> "010..." (the profiles / app 01x convention). */
function toLocalForm(e164: string): string {
  return "0" + e164.slice(3);
}

/** Deterministic 24h idempotency key for ZADX: "otp-" + sha256("<e164>:<otp>"). */
async function idempotencyKey(phoneE164: string, otp: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(`${phoneE164}:${otp}`),
  );
  const hex = [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
  return `otp-${hex}`;
}

function zadxErrorCode(status: number): string {
  if (status === 429) return "zadx_rate_limited";
  if (status === 402) return "zadx_insufficient_credits";
  if (status >= 500) return "zadx_provider_error";
  return `zadx_http_${status}`;
}

async function zadxOtpSend(phoneE164: string, otp: string): Promise<{ ok: boolean; idempotent: boolean; status: number }> {
  const idemKey = await idempotencyKey(phoneE164, otp);
  let res: Response;
  try {
    res = await fetch(`${ZADX_BASE_URL}/otp/send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Api-Key": ZADX_API_KEY,
        "X-Api-Secret": ZADX_API_SECRET,
        "Idempotency-Key": idemKey,
      },
      body: JSON.stringify({
        to: phoneE164,
        otp,
        sender_id: ZADX_SENDER_ID,
        locale: "ar",
      }),
    });
  } catch {
    // Network-level failure — log as provider_error. We return 400 so gotrue
    // does not retry the same OTP (the user simply requests a fresh OTP).
    return { ok: false, idempotent: false, status: 0 };
  }

  if (res.status === 409) {
    // Same phone:otp replayed within ZADX's 24h window → already delivered.
    return { ok: true, idempotent: true, status: res.status };
  }
  if (res.ok) return { ok: true, idempotent: false, status: res.status };

  // Non-2xx failure — log ONE diagnostic line: status + response body truncated
  // to 300 chars with every run of 5+ digits redacted (phones/OTPs/hex ids can
  // never leak) + the idempotency-key length. Never log the OTP, the phone, the
  // API key/secret, or request headers.
  let bodyText = "";
  try {
    bodyText = await res.text();
  } catch {
    bodyText = "<unreadable>";
  }
  const sanitized = bodyText.replace(/\d{5,}/g, "***").slice(0, 300);
  console.error(
    `[send-sms-hook] ZADX non-2xx: status=${res.status} idemKeyLen=${idemKey.length} body="${sanitized}"`,
  );
  return { ok: false, idempotent: false, status: res.status };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: { http_code: 405, message: "method_not_allowed" } }, 405);

  // 1) Verify the Standard Webhooks signature before trusting anything.
  const secret = hooksSecret();
  if (!secret) {
    console.error("[send-sms-hook] SMS_HOOK_SIGNING_SECRET is not set");
    return json({ error: { http_code: 500, message: "hook_secret_missing" } }, 500);
  }

  const raw = await req.text();
  const headers = Object.fromEntries(req.headers);

  let payload: { user?: Record<string, unknown>; sms?: { otp?: string; phone?: string; sms_type?: string } };
  try {
    const wh = new Webhook(secret);
    payload = wh.verify(raw, headers) as { user?: Record<string, unknown>; sms?: { otp?: string; phone?: string; sms_type?: string } };
  } catch {
    console.warn("[send-sms-hook] signature verification failed");
    return json({ error: { http_code: 400, message: "invalid_signature" } }, 400);
  }

  const user = payload.user ?? {};
  const otp = payload.sms?.otp ?? "";
  const userId = typeof user.id === "string" ? user.id : null;
  const newPhone = typeof user.new_phone === "string" ? user.new_phone : "";
  const rawPhone = typeof user.phone === "string" ? user.phone : "";
  const smsPhone = typeof payload.sms?.phone === "string" ? payload.sms.phone : "";

  // DIAGNOSTIC: key names + booleans only — never values, phones, or the OTP.
  console.info(
    `[send-sms-hook] payload-keys sms=[${Object.keys(payload.sms ?? {}).sort().join(",")}] user=[${Object.keys(user).sort().join(",")}] new_phone_present=${newPhone.length > 0}`,
  );

  // The Supabase client + config are read BEFORE choosing the destination,
  // because the fallback path needs the OTP-expiry window
  // (sms_cap_config.otp_expiry_seconds) to decide whether an in-progress
  // phone change is still trusted (see below).
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error("[send-sms-hook] SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are not set");
    return json({ error: { http_code: 500, message: "supabase_env_missing" } }, 500);
  }
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: cfgRows } = await supabase.from("sms_cap_config").select("key, value");
  const cfg = new Map<string, number>((cfgRows ?? []).map((r) => [r.key, +r.value]));
  const perPhoneCap = cfg.get("per_phone_per_day") ?? 3;
  const globalCap = cfg.get("global_per_day") ?? 20;
  // OTP validity window in seconds. MUST mirror Auth -> Settings -> SMS OTP
  // Expiry. Missing/<=0 => we never trust an in-progress change (fail closed).
  const otpExpirySeconds = cfg.get("otp_expiry_seconds") ?? 0;
  if (!otpExpirySeconds || otpExpirySeconds <= 0) {
    console.error("[send-sms-hook] sms_cap_config.otp_expiry_seconds missing/invalid; not trusting new_phone");
  }

  // 1) Destination. sms.phone is gotrue's own computed target
  //    (internal/api/phone.go -> NewSendSMSInput{OTP, Phone}): the NEW number
  //    for a phone change, and the sign-in / forgot-password number otherwise.
  //    It is authoritative, so we trust it first. Only when it is absent (older
  //    gotrue) do we fall back to user.new_phone — honoured only while the
  //    change is still live (phone_change_sent_at within the OTP expiry window,
  //    read from sms_cap_config.otp_expiry_seconds) — else user.phone. Note the
  //    payload's phone_change_sent_at is the PREVIOUS attempt's value (gotrue
  //    persists the new one only AFTER this hook returns), so the fallback can
  //    only ever observe an already-set change, never the one minted now.
  const sentAtMs = typeof user.phone_change_sent_at === "string"
    ? Date.parse(user.phone_change_sent_at)
    : Number.NaN;
  const newPhoneFresh = newPhone.length > 0 &&
    otpExpirySeconds > 0 &&
    Number.isFinite(sentAtMs) &&
    Date.now() - sentAtMs <= otpExpirySeconds * 1000;
  const targetPhone = smsPhone || (newPhoneFresh ? newPhone : rawPhone);

  // Clear a stale phone change so it can never shadow a later sign-in OTP. The
  // rpc is service_role-only and clears ONLY an already-expired change, so a
  // live change — or the change this OTP is minting — is never touched. We call
  // it only when this OTP is NOT destined for the new number.
  const destinedForNewPhone = newPhone.length > 0 && targetPhone === newPhone;
  if (newPhone.length > 0 && !destinedForNewPhone && userId) {
    const { error: clearErr } = await supabase.rpc("clear_stale_phone_change", {
      p_user_id: userId,
      p_window_seconds: otpExpirySeconds,
    });
    if (clearErr) {
      console.warn(`[send-sms-hook] clear_stale_phone_change failed: ${clearErr.message}`);
    } else {
      console.info("[send-sms-hook] cleared an expired phone change");
    }
  }

  if (!otp || !targetPhone || !userId) {
    console.warn("[send-sms-hook] incomplete payload (missing sms.otp / target phone / user.id)");
    return json({ error: { http_code: 400, message: "invalid_payload" } }, 400);
  }

  // 2) Normalize — Egypt only. Non-Egyptian numbers are refused.
  const phoneE164 = toEgyptianE164(targetPhone);
  if (!phoneE164) {
    console.warn("[send-sms-hook] refused non-Egyptian phone");
    return json({ error: { http_code: 400, message: "unsupported_phone_number" } }, 400);
  }
  const phoneLocal = toLocalForm(phoneE164);

  // 3) Identity rule: real/confirmed account only (blocks phone-only creation).
  const identityOk = user.confirmed_at != null || user.phone_confirmed_at != null;
  if (!identityOk) {
    console.warn("[send-sms-hook] blocked SMS for unverified phone-only account");
    return json({ error: { http_code: 403, message: "phone_only_account_blocked" } }, 403);
  }

  // 4) Budget caps (DB is authoritative; defaults here are fallbacks only).

  const dayStart = new Date();
  dayStart.setUTCHours(0, 0, 0, 0);

  const [perPhoneCount, globalCount] = await Promise.all([
    supabase
      .from("sms_send_logs")
      .select("id", { count: "exact", head: true })
      .eq("phone_local", phoneLocal)
      .eq("result", "sent")
      .gte("created_at", dayStart.toISOString()),
    supabase
      .from("sms_send_logs")
      .select("id", { count: "exact", head: true })
      .eq("result", "sent")
      .gte("created_at", dayStart.toISOString()),
  ]);

  const perPhoneSent = perPhoneCount.count ?? 0;
  const globalSent = globalCount.count ?? 0;

  if (perPhoneSent >= perPhoneCap || globalSent >= globalCap) {
    await supabase.from("sms_send_logs").insert({
      phone_local: phoneLocal,
      phone_e164: phoneE164,
      user_id: userId,
      otp_hash: await idempotencyKey(phoneE164, otp),
      result: "rejected",
      error_code: "cap_exceeded",
    });
    console.warn(`[send-sms-hook] cap exceeded (per_phone=${perPhoneSent}/${perPhoneCap}, global=${globalSent}/${globalCap})`);
    return json({ error: { http_code: 400, message: "SMS_LIMIT_EXCEEDED" } }, 400);
  }

  const otpHash = await idempotencyKey(phoneE164, otp);

  // 5) Dry-run: verify hook + SQL wiring without spending a credit.
  if (SMS_DRY_RUN) {
    await supabase.from("sms_send_logs").insert({
      phone_local: phoneLocal,
      phone_e164: phoneE164,
      user_id: userId,
      otp_hash: otpHash,
      result: "dryrun",
      error_code: "dry_run",
    });
    console.info("[send-sms-hook] dry-run OK (no delivery)");
    return json({ ok: true, dry_run: true });
  }

  // 6) Real delivery via ZADX.
  const z = await zadxOtpSend(phoneE164, otp);
  if (z.ok) {
    await supabase.from("sms_send_logs").insert({
      phone_local: phoneLocal,
      phone_e164: phoneE164,
      user_id: userId,
      otp_hash: otpHash,
      result: "sent",
      error_code: z.idempotent ? "zadx_idempotent_replay" : null,
    });
    console.info(`[send-sms-hook] SMS sent to user ${userId}`);
    return json({ ok: true, idempotent: z.idempotent });
  }

  const errorCode = zadxErrorCode(z.status);
  await supabase.from("sms_send_logs").insert({
    phone_local: phoneLocal,
    phone_e164: phoneE164,
    user_id: userId,
    otp_hash: otpHash,
    result: "failed",
    error_code: errorCode,
  });
  console.error(`[send-sms-hook] ZADX send failed (${errorCode})`);
  return json({ error: { http_code: 400, message: errorCode } }, 400);
});