// =============================================================================
// send-support-email — يبعث تذكرة الدعم الجديدة بريدًا إلى صندوق المالك.
//
// يُستدعى من DB Trigger public.notify_support_email عند إدخال صف في
// public.support_tickets عبر pg_net (fire-and-forget)، فلا يتوقف إنشاء التذكرة
// على نجاح البريد — نفس نمط notify_push.
//
// القالب: بريد شركات بسيط (HTML + نص بديل) بهوية محور، RTL، بلا إيموجي:
// ترويسة العلامة، شارات (المُرسل: مزوّد خدمة / صاحب سيارة / زائر — ونوع الرسالة)،
// قسم «عنوان الرسالة»، جدول بيانات التذكرة، قسم «نص الرسالة»، وتذييل بالرقم.
//
// المرفقات: الصورة تُقرأ من bucket «support-attachments» (خاص) عبر service
// role وتُرسَل مع البريد base64 (مُثبت أنه بلا فقد بايت) بنوع صريح يُستنتج من
// البايتات نفسها (JPEG/PNG/WebP/HEIC)، بلا content_id — فالمرفق يبقى مرفقًا
// عاديًا قابلًا للتنزيل، وcid سبق أن جعله اسم ملف لا يفتح شيئًا في جيميل.
// العرض داخل البريد يتم برابط موقّع طويل العمر (30 يومًا) يقرأه بروكسي صور
// جيميل مباشرة، ومعه رابط صريح «عرض الصورة» يفتحها في المتصفح — لأن عارض
// مرفقات جيميل أندرويد فتح الصورة السليمة شاشة سوداء.
// حدّ الـ bucket 10MB، وحدّ الدالة أدناه هو نفسه؛ ما يتجاوزه أو يفشل تحميله
// يُذكر في البريد كمتاح في لوحة الإدارة بدل إسقاط التذكرة.
//
// التشخيص: نداء بالجسم { ticket_id, diag: true } يعيد فحصًا للبايتات
// (magic/أبعاد/سلامة base64/رابط موقّع) ولا يلمس Resend إطلاقًا.
//
// الإرسال عبر Resend HTTP API (https://api.resend.com/emails):
//   * RESEND_API_KEY     — Supabase Secret (إجباري؛ بدونه 503 بلا إرسال).
//   * SUPPORT_EMAIL_FROM — افتراضي «دعم محور <support@mahwar.app>».
//   * SUPPORT_EMAIL_TO   — افتراضي support@mahwar.app، وتُقبل التجاوُزات داخل
//     نطاق mahwar.app فقط. سبب القيد: المسار المُثبت للوصول هو قاعدة Cloudflare
//     Email Routing (support@mahwar.app → بريد المالك)؛ عنوان مباشر خارجي
//     يقبله Resend بـ200 ثم يضيع بلا أي أثر في Cloudflare.
//
// الأمان: لا يُقبل النداء إلا بالسر المشترك x-order-event-secret المطابق
// لـ ORDER_EVENT_SECRET (مثل بقية دوال الأحداث). ولا تُسجَّل محتويات التذكرة
// ولا رقم التواصل ولا أي سر — فقط ticket_id ورمز مزوّد البريد.
// =============================================================================

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

const RESEND_URL = "https://api.resend.com/emails";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const SUPPORT_FROM = Deno.env.get("SUPPORT_EMAIL_FROM") ??
  "دعم محور <support@mahwar.app>";
const SUPPORT_TO = resolveRecipient(Deno.env.get("SUPPORT_EMAIL_TO"));
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const SUPPORT_BUCKET = "support-attachments";
const MAX_ATTACHMENT_BYTES = 10 * 1024 * 1024;
// عمر رابط المعاينة داخل البريد. طويل بقدر يكفي لقراءة التذكرة لاحقًا، وقصير
// بقدر لا يترك صورة العميل متاحة لمن يحصل على الرابط للأبد.
const PREVIEW_TTL_SECONDS = 30 * 24 * 60 * 60;

const BRAND = "#FF6B00";

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

/**
 * العنوان الفعلي للاستلام. لا يُقبل إلا داخل نطاق mahwar.app (يمرّ حتمًا عبر
 * قاعدة Cloudflare Forward)؛ أي قيمة أخرى — أو خطأ كتابة — تعود للافتراضي
 * بدل أن تُرسَل لعنوان خاطئ يقبله Resend ثم يضيع.
 */
function resolveRecipient(raw: string | null | undefined): string {
  const value = (raw ?? "").trim().toLowerCase();
  return /^[a-z0-9._%+-]+@mahwar\.app$/.test(value) ? value : "support@mahwar.app";
}

function esc(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

function sizeLabel(bytes: number): string {
  if (bytes >= 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${Math.max(1, Math.round(bytes / 1024))} KB`;
}

/** يحدّد نوع الصورة من بايتاتها (لا من امتداد اسم الملف). */
function sniffImage(bytes: Uint8Array): { mime: string; ext: string } {
  const ascii = (from: number, to: number) => String.fromCharCode(...bytes.subarray(from, to));
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return { mime: "image/jpeg", ext: "jpg" };
  }
  if (bytes.length >= 8 && bytes[0] === 0x89 && ascii(1, 4) === "PNG") {
    return { mime: "image/png", ext: "png" };
  }
  if (bytes.length >= 12 && ascii(0, 4) === "RIFF" && ascii(8, 12) === "WEBP") {
    return { mime: "image/webp", ext: "webp" };
  }
  if (bytes.length >= 12 && ascii(4, 8) === "ftyp") {
    const brand = ascii(8, 12);
    if (["heic", "heix", "hevc", "hevx", "mif1", "msf1"].includes(brand)) {
      return { mime: "image/heic", ext: "heic" };
    }
  }
  return { mime: "application/octet-stream", ext: "bin" };
}

/** 2026-11-10T23:47:10Z -> "11-11-2026 · 01:47" بتوقيت القاهرة. */
function cairoStamp(iso: string): string {
  const dt = new Date(iso);
  if (Number.isNaN(dt.getTime())) return iso;
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Africa/Cairo",
    hourCycle: "h23",
    hour: "2-digit",
    minute: "2-digit",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  }).formatToParts(dt);
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? "";
  return `${get("day")}-${get("month")}-${get("year")} · ${get("hour")}:${get("minute")}`;
}

type SupportTicket = {
  id: string;
  user_id: string | null;
  user_role: string | null;
  kind: string;
  category: string | null;
  subject: string;
  body: string;
  contact_name: string;
  contact_phone: string;
  attachment_path: string | null;
  created_at: string;
};

const KIND_LABEL: Record<string, string> = {
  complaint: "شكوى",
  suggestion: "اقتراح",
  inquiry: "استفسار",
};

const ROLE_LABEL: Record<string, string> = {
  car_owner: "صاحب سيارة",
  provider: "مزوّد خدمة",
};

const ROLE_BADGE: Record<string, string> = {
  provider: "background:#EFF6FF;color:#1D4ED8",
  car_owner: "background:#F5F3FF;color:#6D28D9",
  guest: "background:#F3F4F6;color:#4B5563",
};

function senderKind(ticket: SupportTicket): { label: string; key: string } {
  if (!ticket.user_id) return { label: "زائر (بدون تسجيل دخول)", key: "guest" };
  const role = ticket.user_role ?? "";
  return { label: ROLE_LABEL[role] ?? "مستخدم مسجّل", key: role || "member" };
}

function buildEmail(
  ticket: SupportTicket,
  attachmentLabel: string,
  previewUrl: string | null,
): { subject: string; html: string; text: string } {
  const typeStr = KIND_LABEL[ticket.kind] ?? ticket.kind;
  const category = ticket.category ?? "غير محدد";
  const sender = senderKind(ticket);
  const when = cairoStamp(ticket.created_at);

  const subject = ticket.user_id
    ? `[${sender.label}] ${typeStr} — ${ticket.subject}`
    : `[زائر] ${typeStr} — ${ticket.subject}`;

  const badgeStyle =
    "display:inline-block;padding:3px 10px;border-radius:999px;font-size:12px;font-weight:600";
  const senderBadge = `<span style="${badgeStyle};${ROLE_BADGE[sender.key] ?? ROLE_BADGE.guest}">${
    esc(sender.label)
  }</span>`;
  const kindBadge = `<span style="${badgeStyle};background:#FFF4EC;color:#C2410C">${
    esc(typeStr)
  }</span>`;

  const rows: Array<[string, string]> = [
    ["الاسم", esc(ticket.contact_name)],
    ["الهاتف", `<span dir="ltr" style="display:inline-block">${esc(ticket.contact_phone)}</span>`],
    ["التصنيف", esc(category)],
    ["تاريخ الإرسال", `<span dir="ltr" style="display:inline-block">${esc(when)}</span>`],
    ["المرفقات", `<span dir="ltr" style="display:inline-block">${esc(attachmentLabel)}</span>`],
  ];

  const metaRows = rows.map(([label, value]) =>
    `<tr>
      <td style="padding:8px 0;border-bottom:1px solid #F3F4F6;color:#6B7280;font-size:13px;white-space:nowrap;width:110px">${label}</td>
      <td style="padding:8px 14px 8px 0;border-bottom:1px solid #F3F4F6;color:#111827;font-size:13px">${value}</td>
    </tr>`
  ).join("\n      ");

  const safePreview = previewUrl ? esc(previewUrl) : "";
  const inlineImage = previewUrl
    ? `<tr><td style="padding:20px 28px 0">
        <div style="font-size:11px;color:#9CA3AF;margin-bottom:8px">الصورة المرفقة</div>
        <a href="${safePreview}" style="display:block;text-decoration:none">
          <img src="${safePreview}" alt="صورة التذكرة" width="544" style="display:block;width:100%;max-width:544px;height:auto;border:1px solid #EEF0F3;border-radius:8px">
        </a>
        <div style="margin-top:10px;font-size:12px;color:#6B7280">
          إن لم تظهر الصورة داخل البريد،
          <a href="${safePreview}" style="color:${BRAND};text-decoration:none">افتحها في المتصفح</a>.
        </div>
      </td></tr>`
    : "";

  const html = `<!doctype html>
<html dir="rtl" lang="ar">
<head><meta charset="utf-8"><meta name="color-scheme" content="light"></head>
<body style="margin:0;padding:0;background:#F4F5F7">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#F4F5F7;padding:32px 16px">
  <tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" style="width:600px;max-width:100%;background:#FFFFFF;border:1px solid #E5E7EB;border-radius:12px;overflow:hidden;font-family:Tahoma,'Segoe UI',Arial,sans-serif">
      <tr><td style="height:4px;background:${BRAND};font-size:0;line-height:0">&nbsp;</td></tr>
      <tr><td style="padding:22px 28px 0">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
          <td style="font-size:16px;font-weight:700;color:#111827">محور</td>
          <td align="left" style="font-size:12px;color:#9CA3AF">دعم العملاء</td>
        </tr></table>
      </td></tr>
      <tr><td style="padding:20px 28px 0">
        <div style="font-size:11px;color:#9CA3AF">تذكرة دعم جديدة</div>
        <div style="margin-top:10px">${senderBadge}&nbsp;&nbsp;${kindBadge}</div>
      </td></tr>
      <tr><td style="padding:20px 28px 0">
        <div style="font-size:11px;color:#9CA3AF">عنوان الرسالة</div>
        <div style="font-size:18px;line-height:1.6;font-weight:700;color:#111827;margin-top:6px">${
    esc(ticket.subject)
  }</div>
      </td></tr>
      <tr><td style="padding:20px 28px 0">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse;text-align:right">
      ${metaRows}
        </table>
      </td></tr>
      <tr><td style="padding:20px 28px 0">
        <div style="font-size:11px;color:#9CA3AF;margin-bottom:8px">نص الرسالة</div>
        <div style="background:#FAFAFA;border:1px solid #EEF0F3;border-right:3px solid ${BRAND};border-radius:8px;padding:16px 18px;font-size:14px;line-height:1.9;color:#1F2937;white-space:pre-wrap">${
    esc(ticket.body)
  }</div>
      </td></tr>
      ${inlineImage}
      <tr><td style="padding:24px 28px 26px">
        <div style="border-top:1px solid #EEF0F3;padding-top:14px;font-size:11px;line-height:1.8;color:#9CA3AF">
          أُرسلت هذه التذكرة تلقائيًا من تطبيق محور · رقم التذكرة
          <span dir="ltr" style="display:inline-block;font-family:Consolas,monospace;color:#6B7280">${esc(ticket.id)}</span>
        </div>
      </td></tr>
    </table>
  </td></tr>
</table>
</body>
</html>`;

  const text = [
    "تذكرة دعم جديدة — محور",
    "",
    `نوع المرسل: ${sender.label}`,
    `نوع الرسالة: ${typeStr}`,
    `عنوان الرسالة: ${ticket.subject}`,
    `الاسم: ${ticket.contact_name}`,
    `الهاتف: ${ticket.contact_phone}`,
    `التصنيف: ${category}`,
    `تاريخ الإرسال: ${when}`,
    `المرفقات: ${attachmentLabel}`,
    "",
    "نص الرسالة:",
    ticket.body,
    "",
    ...(previewUrl ? ["الصورة المرفقة:", previewUrl, ""] : []),
    `رقم التذكرة: ${ticket.id}`,
    "أُرسلت هذه التذكرة تلقائيًا من تطبيق محور.",
  ].join("\n");

  return { subject, html, text };
}

type LoadedAttachment = {
  filename: string;
  content: string;
  content_type: string;
};

type AttachmentDiag = {
  bytes: number;
  magic: string;
  mime: string;
  width: number;
  height: number;
  complete: boolean;
  markers: string[];
  base64_roundtrip: boolean;
  signed_url: boolean;
  url?: string;
};

function hexPrefix(bytes: Uint8Array, count: number): string {
  return Array.from(bytes.subarray(0, count))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join(" ");
}

/** يمشي على علامات JPEG ليستخرج الأبعاد ونوع الترميز وعلامات EXIF/ICC/MPF. */
function jpegMeta(bytes: Uint8Array): { width: number; height: number; markers: string[] } {
  const markers: string[] = [];
  let width = 0;
  let height = 0;
  let i = 2;
  while (i + 9 < bytes.length) {
    if (bytes[i] !== 0xff) {
      i++;
      continue;
    }
    const marker = bytes[i + 1];
    if (marker === 0xff) {
      i++;
      continue;
    }
    if (marker === 0xd8 || marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
      i += 2;
      continue;
    }
    if (marker === 0xd9) break;
    const len = (bytes[i + 2] << 8) | bytes[i + 3];
    if (len < 2) break;

    if (marker === 0xe0) {
      markers.push("jfif");
    } else if (marker === 0xe1) {
      const tag = String.fromCharCode(...bytes.subarray(i + 4, i + 9));
      markers.push(tag.startsWith("Exif") ? "exif" : "app1");
    } else if (marker === 0xe2) {
      const tag = String.fromCharCode(...bytes.subarray(i + 4, i + 7));
      markers.push(tag === "MPF" ? "mpf" : tag === "ICC" ? "icc" : "app2");
    } else if (marker === 0xed) {
      markers.push("ps");
    } else if (marker === 0xee) {
      markers.push("adobe");
    } else if (marker === 0xfe) {
      markers.push("comment");
    } else if (
      marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc
    ) {
      height = (bytes[i + 5] << 8) | bytes[i + 6];
      width = (bytes[i + 7] << 8) | bytes[i + 8];
      markers.push(`sof${marker - 0xc0}/components=${bytes[i + 9]}`);
      break;
    }
    i += 2 + len;
  }
  return { width, height, markers };
}

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** يثبت أن toBase64 لا يفقد بايتًا: فكّ الترميز ثم قارن البصمة. */
async function base64RoundTripOk(bytes: Uint8Array): Promise<boolean> {
  const encoded = toBase64(bytes);
  const decoded = Uint8Array.from(atob(encoded), (c) => c.charCodeAt(0));
  if (decoded.length !== bytes.length) return false;
  const [a, b] = await Promise.all([sha256Hex(bytes), sha256Hex(decoded)]);
  return a === b;
}

/**
 * يقرأ الصورة من الـ bucket الخاص ويجهّزها: مرفق Resend (base64 + نوع صريح،
 * بلا content_id) ورابط معاينة موقّع طويل العمر لعرضها داخل جسم البريد.
 */
async function loadAttachment(
  supabase: SupabaseClient,
  ticket: SupportTicket,
  wantDiag: boolean,
): Promise<{
  attachment: LoadedAttachment | null;
  label: string;
  previewUrl: string | null;
  diag?: AttachmentDiag;
}> {
  if (!ticket.attachment_path) {
    return { attachment: null, label: "لا يوجد", previewUrl: null };
  }
  const path = ticket.attachment_path;

  const failedLabel = "تعذّر إرفاق الصورة — متاحة في لوحة الإدارة";
  try {
    const { data, error } = await supabase.storage.from(SUPPORT_BUCKET).download(path);
    if (error || !data) {
      console.warn(`[send-support-email] attachment download failed for ${ticket.id}`);
      return { attachment: null, label: failedLabel, previewUrl: null };
    }

    const bytes = new Uint8Array(await data.arrayBuffer());
    if (bytes.length === 0 || bytes.length > MAX_ATTACHMENT_BYTES) {
      console.warn(`[send-support-email] attachment skipped for ${ticket.id}: size out of range`);
      return {
        attachment: null,
        label: "الصورة خارج حد الحجم — متاحة في لوحة الإدارة",
        previewUrl: null,
      };
    }

    const { mime, ext } = sniffImage(bytes);
    const filename = `mahwar-support-${ticket.id.slice(0, 8)}.${ext}`;

    const meta = jpegMeta(bytes);
    console.log(
      `[send-support-email] attachment ticket=${ticket.id} bytes=${bytes.length} mime=${mime} ` +
        `dims=${meta.width}x${meta.height} end=${bytes[bytes.length - 2] === 0xff && bytes[bytes.length - 1] === 0xd9} ` +
        `markers=${meta.markers.join(",")}`,
    );

    const attachment: LoadedAttachment = {
      filename,
      content: toBase64(bytes),
      content_type: mime,
    };

    // معاينة داخل البريد: رابط موقّع يقرأه بروكسي صور جيميل بلا حاجة لجلسة.
    const previewUrl = mime.startsWith("image/")
      ? (await supabase.storage.from(SUPPORT_BUCKET).createSignedUrl(path, PREVIEW_TTL_SECONDS))
        .data?.signedUrl ?? null
      : null;

    // الرابط الموقّع للتشخيص فقط (فحص البايتات خارجيًا)، لا يُرسَل في البريد.
    const signedUrl = wantDiag
      ? (await supabase.storage.from(SUPPORT_BUCKET).createSignedUrl(path, 600)).data?.signedUrl ??
        null
      : null;

    const diag: AttachmentDiag | undefined = wantDiag
      ? {
        bytes: bytes.length,
        magic: hexPrefix(bytes, 12),
        mime,
        width: meta.width,
        height: meta.height,
        complete: bytes[bytes.length - 2] === 0xff && bytes[bytes.length - 1] === 0xd9,
        markers: meta.markers,
        base64_roundtrip: await base64RoundTripOk(bytes),
        signed_url: Boolean(signedUrl),
        url: signedUrl ?? undefined,
      }
      : undefined;

    return {
      attachment,
      label: `${filename} (${sizeLabel(bytes.length)})`,
      previewUrl,
      diag,
    };
  } catch (e) {
    console.warn(`[send-support-email] attachment read error for ${ticket.id}: ${String(e)}`);
    return { attachment: null, label: failedLabel, previewUrl: null };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const expected = Deno.env.get("ORDER_EVENT_SECRET");
  if (!expected || req.headers.get("x-order-event-secret") !== expected) {
    console.warn("[send-support-email] unauthorized call (missing/mismatched secret)");
    return json({ error: "unauthorized" }, 403);
  }

  if (!RESEND_API_KEY) {
    console.error("[send-support-email] RESEND_API_KEY is not configured");
    return json({ error: "not_configured" }, 503);
  }

  let ticketId = "";
  let wantDiag = false;
  try {
    const body = await req.json();
    ticketId = typeof body?.ticket_id === "string" ? body.ticket_id.trim() : "";
    wantDiag = body?.diag === true;
  } catch {
    ticketId = "";
  }
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(ticketId)) {
    return json({ error: "invalid_ticket_id" }, 400);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  const { data, error } = await supabase
    .from("support_tickets")
    .select(
      "id, user_id, user_role, kind, category, subject, body, contact_name, contact_phone, attachment_path, created_at",
    )
    .eq("id", ticketId)
    .maybeSingle();

  if (error) {
    console.error(`[send-support-email] ticket ${ticketId} read failed: ${error.message}`);
    return json({ error: "read_failed" }, 500);
  }
  if (!data) return json({ error: "ticket_not_found" }, 404);

  const ticket = data as SupportTicket;
  const { attachment, label, previewUrl, diag } = await loadAttachment(supabase, ticket, wantDiag);

  // نداء تشخيصي: لا يلمس Resend إطلاقًا، فلا 409 من Idempotency ولا بريد جديد.
  if (wantDiag) {
    return json({ diag_only: true, attachment: Boolean(attachment), diag });
  }

  const email = buildEmail(ticket, label, previewUrl);

  let response: Response;
  try {
    response = await fetch(RESEND_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
        // إعادة النداء لنفس التذكرة لا ترسل نسخة ثانية (نافذة Resend 24 ساعة).
        "Idempotency-Key": `support-ticket-${ticketId}`,
      },
      body: JSON.stringify({
        from: SUPPORT_FROM,
        to: [SUPPORT_TO],
        subject: email.subject,
        html: email.html,
        text: email.text,
        ...(attachment ? { attachments: [attachment] } : {}),
      }),
    });
  } catch (e) {
    console.error(`[send-support-email] resend network error for ${ticketId}: ${String(e)}`);
    return json({ error: "provider_unreachable" }, 502);
  }

  const raw = await response.text();
  if (!response.ok) {
    let providerError = "";
    try {
      const parsed = JSON.parse(raw);
      providerError = parsed?.name ?? parsed?.message ?? "";
    } catch {
      providerError = "";
    }
    console.error(
      `[send-support-email] resend rejected ${ticketId}: status=${response.status} ${providerError}`,
    );
    return json({ error: "provider_failed" }, 502);
  }

  let messageId = "";
  try {
    messageId = JSON.parse(raw)?.id ?? "";
  } catch {
    messageId = "";
  }
  console.log(
    `[send-support-email] sent ticket ${ticketId} attachment=${attachment ? "yes" : "no"} message=${messageId}`,
  );
  return json({
    sent: true,
    id: messageId,
    attachment: Boolean(attachment),
    attachment_mode: attachment ? "attachment+preview-link" : "none",
    preview: Boolean(previewUrl),
    ...(diag ? { diag } : {}),
  });
});
