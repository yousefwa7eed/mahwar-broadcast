// Unit tests for notification_text.ts.
//
// Runnable with Node's built-in test runner (Node 22.18+ / 24, TypeScript type
// stripping is on by default):
//   node --test supabase/functions/send-push-notification/notification_text_test.ts
// It is also Deno-compatible (node:test / node:assert via Deno's node compat).
//
// This file is NOT imported by index.ts, so it is not bundled on deploy.

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  buildTitleBody,
  normalizeLanguage,
  resolveServiceName,
} from "./notification_text.ts";

// type, arTitle, arBody, enTitle, enBody (types with no metadata dependency)
const simpleCases: Array<[string, string, string, string, string]> = [
  [
    "order_confirmed",
    "تم تأكيد الطلب",
    "تم تأكيد طلبك بنجاح",
    "Order confirmed",
    "Your order was confirmed successfully",
  ],
  [
    "order_cancelled",
    "تم إلغاء الطلب",
    "تم إلغاء هذا الطلب",
    "Order cancelled",
    "This order was cancelled",
  ],
  [
    "order_completed",
    "تم إتمام الطلب",
    "تم إتمام خدمة الطلب بنجاح",
    "Order completed",
    "The order service was completed successfully",
  ],
  [
    "shift_started",
    "بدء ساعات العمل",
    "بدأت ساعات عملك — أنت الآن متاح أمام العملاء",
    "Work hours started",
    "Your working hours have started — you are now available to customers",
  ],
  [
    "shift_ended",
    "انتهاء ساعات العمل",
    "انتهت ساعات عملك — أصبحت الآن غير متاح",
    "Work hours ended",
    "Your working hours have ended — you are now unavailable",
  ],
  ["new_message", "رسالة جديدة", "وصلتك رسالة جديدة", "New message", "You received a new message"],
  [
    "some_unknown_type",
    "إشعار جديد",
    "يوجد تحديث جديد لتطبيق محور",
    "New notification",
    "There is a new update for Mahwar",
  ],
];

test("simple types render in both languages", () => {
  for (const [type, arTitle, arBody, enTitle, enBody] of simpleCases) {
    assert.deepEqual(buildTitleBody(type, {}, "ar"), { title: arTitle, body: arBody }, `ar ${type}`);
    assert.deepEqual(buildTitleBody(type, {}, "en"), { title: enTitle, body: enBody }, `en ${type}`);
  }
});

// Regression: the exact ORIGINAL Arabic output (live send-push-notification v25
// buildTitleBody), for EVERY type — including the no-service-name and
// no-provider cases — so any future drift in the Arabic strings fails a test.
// [type, metadata, expectedTitle, expectedBody]
const originalArabicCases: Array<[string, Record<string, unknown>, string, string]> = [
  ["new_order", {}, "طلب جديد", "لديك طلب جديد"],
  ["new_order", { service_name: "كهرباء" }, "طلب جديد", "لديك طلب جديد: كهرباء"],
  ["price_offer", {}, "عرض سعر جديد", "تم استلام عرض سعر جديد"],
  ["price_offer", { provider_name: "أحمد", price: 150 }, "عرض سعر جديد", "أحمد قدم عرض سعر 150 ج.م"],
  [
    "price_offer",
    { provider_name: "أحمد", price: 150, service_name: "كهرباء" },
    "عرض سعر جديد",
    "أحمد قدم عرض سعر 150 ج.م لطلب كهرباء",
  ],
  ["order_confirmed", {}, "تم تأكيد الطلب", "تم تأكيد طلبك بنجاح"],
  ["order_rejected", {}, "تم رفض الطلب", "تم رفض الطلب"],
  ["order_rejected", { provider_name: "خالد" }, "تم رفض الطلب", "تم رفض الطلب من خالد"],
  ["order_cancelled", {}, "تم إلغاء الطلب", "تم إلغاء هذا الطلب"],
  ["order_completed", {}, "تم إتمام الطلب", "تم إتمام خدمة الطلب بنجاح"],
  ["shift_started", {}, "بدء ساعات العمل", "بدأت ساعات عملك — أنت الآن متاح أمام العملاء"],
  ["shift_ended", {}, "انتهاء ساعات العمل", "انتهت ساعات عملك — أصبحت الآن غير متاح"],
  ["rating_received", {}, "تقييم جديد", "حصلت على تقييم جديد"],
  ["rating_received", { rating: 4 }, "تقييم جديد", "حصلت على تقييم 4 من 5"],
  ["new_message", {}, "رسالة جديدة", "وصلتك رسالة جديدة"],
  ["broadcast", {}, "إشعار", ""],
  ["broadcast", { title: "عرض", body: "خصم" }, "عرض", "خصم"],
  ["some_unknown_type", {}, "إشعار جديد", "يوجد تحديث جديد لتطبيق محور"],
];

test("arabic output matches the original implementation exactly", () => {
  for (const [type, metadata, title, body] of originalArabicCases) {
    assert.deepEqual(
      buildTitleBody(type, metadata, "ar"),
      { title, body },
      `ar ${type} ${JSON.stringify(metadata)}`,
    );
  }
});

test("new_order uses service name, with the full fallback chain", () => {
  const dbFirst = buildTitleBody(
    "new_order",
    { service_name: "سباكة" },
    "ar",
    "كهرباء",
  );
  assert.deepEqual(dbFirst, { title: "طلب جديد", body: "لديك طلب جديد: كهرباء" });

  const metaOnly = buildTitleBody("new_order", { service_name: "سباكة" }, "ar");
  assert.deepEqual(metaOnly, { title: "طلب جديد", body: "لديك طلب جديد: سباكة" });

  const noServiceAr = buildTitleBody("new_order", {}, "ar");
  assert.deepEqual(noServiceAr, { title: "طلب جديد", body: "لديك طلب جديد" });

  const noServiceEn = buildTitleBody("new_order", {}, "en");
  assert.deepEqual(noServiceEn, { title: "New order", body: "You have a new order" });

  const enWithDb = buildTitleBody("new_order", {}, "en", "Electricity");
  assert.deepEqual(enWithDb, { title: "New order", body: "You have a new order: Electricity" });
});

test("price_offer with provider + price + service, in both languages", () => {
  const meta = { provider_name: "أحمد", price: 150, service_name: "كهرباء" };
  assert.deepEqual(buildTitleBody("price_offer", meta, "ar"), {
    title: "عرض سعر جديد",
    body: "أحمد قدم عرض سعر 150 ج.م لطلب كهرباء",
  });
  assert.deepEqual(buildTitleBody("price_offer", meta, "en"), {
    title: "New price offer",
    body: "أحمد offered a price of 150 EGP for كهرباء",
  });
});

test("price_offer price 0 is still an offer", () => {
  const meta = { provider_name: "أحمد", price: 0, service_name: "كهرباء" };
  assert.equal(buildTitleBody("price_offer", meta, "ar").body, "أحمد قدم عرض سعر 0 ج.م لطلب كهرباء");
});

test("price_offer without provider falls back to the generic line", () => {
  assert.deepEqual(buildTitleBody("price_offer", { price: 100 }, "ar"), {
    title: "عرض سعر جديد",
    body: "تم استلام عرض سعر جديد",
  });
  assert.deepEqual(buildTitleBody("price_offer", { price: 100 }, "en"), {
    title: "New price offer",
    body: "A new price offer was received",
  });
});

test("price_offer without a service name omits the service suffix", () => {
  const meta = { provider_name: "أحمد", price: 100 };
  assert.equal(buildTitleBody("price_offer", meta, "ar").body, "أحمد قدم عرض سعر 100 ج.م");
  assert.equal(buildTitleBody("price_offer", meta, "en").body, "أحمد offered a price of 100 EGP");
});

test("order_rejected with and without provider", () => {
  assert.deepEqual(buildTitleBody("order_rejected", { provider_name: "خالد" }, "ar"), {
    title: "تم رفض الطلب",
    body: "تم رفض الطلب من خالد",
  });
  assert.deepEqual(buildTitleBody("order_rejected", { provider_name: "خالد" }, "en"), {
    title: "Order rejected",
    body: "The order was rejected by خالد",
  });
  assert.deepEqual(buildTitleBody("order_rejected", {}, "ar"), {
    title: "تم رفض الطلب",
    body: "تم رفض الطلب",
  });
  assert.deepEqual(buildTitleBody("order_rejected", {}, "en"), {
    title: "Order rejected",
    body: "The order was rejected",
  });
});

test("rating_received with and without value (including 0)", () => {
  assert.deepEqual(buildTitleBody("rating_received", { rating: 4 }, "ar"), {
    title: "تقييم جديد",
    body: "حصلت على تقييم 4 من 5",
  });
  assert.deepEqual(buildTitleBody("rating_received", { rating: 4 }, "en"), {
    title: "New rating",
    body: "You received a rating of 4 out of 5",
  });
  assert.equal(buildTitleBody("rating_received", { rating: 0 }, "ar").body, "حصلت على تقييم 0 من 5");
  assert.deepEqual(buildTitleBody("rating_received", {}, "ar"), {
    title: "تقييم جديد",
    body: "حصلت على تقييم جديد",
  });
  assert.deepEqual(buildTitleBody("rating_received", {}, "en"), {
    title: "New rating",
    body: "You received a new rating",
  });
});

test("broadcast: arabic uses title/body", () => {
  assert.deepEqual(buildTitleBody("broadcast", { title: "عرض", body: "خصم 20%" }, "ar"), {
    title: "عرض",
    body: "خصم 20%",
  });
});

test("broadcast: english prefers *_en, else falls back to arabic", () => {
  assert.deepEqual(
    buildTitleBody("broadcast", { title: "عرض", body: "خصم", title_en: "Offer", body_en: "Discount" }, "en"),
    { title: "Offer", body: "Discount" },
  );
  assert.deepEqual(buildTitleBody("broadcast", { title: "عرض", body: "خصم" }, "en"), {
    title: "عرض",
    body: "خصم",
  });
});

test("broadcast: empty metadata falls back to defaults", () => {
  assert.deepEqual(buildTitleBody("broadcast", {}, "ar"), { title: "إشعار", body: "" });
  assert.deepEqual(buildTitleBody("broadcast", {}, "en"), { title: "Notification", body: "" });
});

test("resolveServiceName fallback chain", () => {
  assert.equal(resolveServiceName({ service_name: "ب" }, "أ"), "أ");
  assert.equal(resolveServiceName({ service_name: "ب" }, null), "ب");
  assert.equal(resolveServiceName({}), undefined);
  assert.equal(resolveServiceName({ service_name: "   " }, ""), undefined);
  assert.equal(resolveServiceName({ service_name: "   " }), undefined);
});

test("normalizeLanguage defaults unknown values to arabic", () => {
  assert.equal(normalizeLanguage("en"), "en");
  assert.equal(normalizeLanguage("ar"), "ar");
  assert.equal(normalizeLanguage(undefined), "ar");
  assert.equal(normalizeLanguage(null), "ar");
  assert.equal(normalizeLanguage("EN"), "ar");
  assert.equal(normalizeLanguage("fr"), "ar");
});
