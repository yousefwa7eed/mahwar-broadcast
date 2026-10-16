// Bilingual (Arabic / English) text for push notifications.
//
// Extracted out of index.ts so it can be unit-tested without any Deno-only API
// (this module has zero imports and no runtime side effects).
//
// ── Keep in sync with the Flutter side ────────────────────────────────────────
// The SAME in-app notifications are rendered client-side from ARB strings.
// Flutter counterpart:
//   lib/l10n/app_ar.arb + lib/l10n/app_en.arb
//   rendered by lib/core/models/notification_model.dart
//   (that file carries the reverse comment pointing back here).
//
// Edge branch → Flutter ARB key:
//   new_order       title → notificationTitleNewOrder
//                   body  → notificationBodyNewOrderWithService / notificationBodyNewOrder
//   price_offer     title → notificationTitlePriceOffer
//                   body  → notificationBodyPriceOfferWithService / notificationBodyPriceOffer
//                           / notificationBodyPriceOfferReceived
//   order_confirmed title → notificationTitleOrderConfirmed
//                   body  → notificationBodyOrderConfirmed
//   order_rejected  title → notificationTitleOrderRejected
//                   body  → notificationBodyOrderRejectedWithProvider / notificationBodyOrderRejected
//   order_cancelled title → notificationTitleOrderCancelled
//                   body  → notificationBodyOrderCancelled
//   order_completed title → notificationTitleOrderCompleted
//                   body  → notificationBodyOrderCompleted
//   shift_started   title → notificationTitleShiftStarted
//                   body  → notificationBodyShiftStarted
//   shift_ended     title → notificationTitleShiftEnded
//                   body  → notificationBodyShiftEnded
//   rating_received title → notificationTitleRatingReceived
//                   body  → notificationBodyRatingWithValue / notificationBodyRating
//   new_message     title → notificationTitleNewMessage
//                   body  → notificationBodyNewMessage
//   broadcast       title → metadata.title_en (en) / metadata.title, fallback "Notification"/"إشعار"
//                   body  → metadata.body_en (en) / metadata.body
//   default         title → notificationTitleDefault
//                   body  → notificationBodyDefault
//   currency → egp  ("ج.م" in ar / "EGP" in en)
//   no resolvable service name → the service suffix is omitted (as before)

export type NotificationLanguage = "ar" | "en";

export function normalizeLanguage(value: unknown): NotificationLanguage {
  return value === "en" ? "en" : "ar";
}

function nonEmptyString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim() ? value : undefined;
}

const CURRENCY: Record<NotificationLanguage, string> = {
  ar: "ج.م",
  en: "EGP",
};

/**
 * Resolve the service label shown in a notification body.
 * Priority: name from service_types (by metadata.service_type_id, in the
 * requested language, supplied by the caller as `serviceNameFromDb`)
 * → metadata.service_name → undefined. When undefined the callers omit the
 * service suffix, exactly like the original Arabic-only implementation.
 */
export function resolveServiceName(
  metadata: Record<string, unknown>,
  serviceNameFromDb?: string | null,
): string | undefined {
  return nonEmptyString(serviceNameFromDb) ?? nonEmptyString(metadata["service_name"]);
}

/**
 * Build the push title/body for a notification in the recipient's language.
 *
 * @param type            notifications.type
 * @param metadata        notifications.metadata (jsonb)
 * @param language        recipient language ("ar" | "en"); anything else → "ar"
 * @param serviceNameFromDb  service_types.name_ar|name_en for metadata.service_type_id
 */
export function buildTitleBody(
  type: string,
  metadata: Record<string, unknown>,
  language: unknown = "ar",
  serviceNameFromDb?: string | null,
): { title: string; body: string } {
  const lang = normalizeLanguage(language);
  const en = lang === "en";
  const serviceName = resolveServiceName(metadata, serviceNameFromDb);
  const providerName = nonEmptyString(metadata["provider_name"]);
  const price = metadata["price"];
  const rating = metadata["rating"];
  const currency = CURRENCY[lang];

  switch (type) {
    case "new_order":
      return {
        title: en ? "New order" : "طلب جديد",
        body: serviceName
          ? (en ? `You have a new order: ${serviceName}` : `لديك طلب جديد: ${serviceName}`)
          : (en ? "You have a new order" : "لديك طلب جديد"),
      };
    case "price_offer": {
      const title = en ? "New price offer" : "عرض سعر جديد";
      if (providerName && price != null) {
        return {
          title,
          body: en
            ? `${providerName} offered a price of ${price} ${currency}${serviceName ? ` for ${serviceName}` : ""}`
            : `${providerName} قدم عرض سعر ${price} ${currency}${serviceName ? ` لطلب ${serviceName}` : ""}`,
        };
      }
      return {
        title,
        body: en ? "A new price offer was received" : "تم استلام عرض سعر جديد",
      };
    }
    case "order_confirmed":
      return {
        title: en ? "Order confirmed" : "تم تأكيد الطلب",
        body: en ? "Your order was confirmed successfully" : "تم تأكيد طلبك بنجاح",
      };
    case "order_rejected":
      return {
        title: en ? "Order rejected" : "تم رفض الطلب",
        body: providerName
          ? (en ? `The order was rejected by ${providerName}` : `تم رفض الطلب من ${providerName}`)
          : (en ? "The order was rejected" : "تم رفض الطلب"),
      };
    case "order_cancelled":
      return {
        title: en ? "Order cancelled" : "تم إلغاء الطلب",
        body: en ? "This order was cancelled" : "تم إلغاء هذا الطلب",
      };
    case "order_completed":
      return {
        title: en ? "Order completed" : "تم إتمام الطلب",
        body: en ? "The order service was completed successfully" : "تم إتمام خدمة الطلب بنجاح",
      };
    case "shift_started":
      return {
        title: en ? "Work hours started" : "بدء ساعات العمل",
        body: en
          ? "Your working hours have started — you are now available to customers"
          : "بدأت ساعات عملك — أنت الآن متاح أمام العملاء",
      };
    case "shift_ended":
      return {
        title: en ? "Work hours ended" : "انتهاء ساعات العمل",
        body: en
          ? "Your working hours have ended — you are now unavailable"
          : "انتهت ساعات عملك — أصبحت الآن غير متاح",
      };
    case "rating_received":
      return {
        title: en ? "New rating" : "تقييم جديد",
        body: rating != null
          ? (en ? `You received a rating of ${rating} out of 5` : `حصلت على تقييم ${rating} من 5`)
          : (en ? "You received a new rating" : "حصلت على تقييم جديد"),
      };
    case "new_message":
      return {
        title: en ? "New message" : "رسالة جديدة",
        body: en ? "You received a new message" : "وصلتك رسالة جديدة",
      };
    case "broadcast": {
      // إشعار عام: العنوان والنص يأتيان مباشرة من metadata (محددان من المالك).
      // English uses the *_en variants when present, else falls back to the Arabic ones.
      const title = en
        ? (nonEmptyString(metadata["title_en"]) ?? nonEmptyString(metadata["title"]))
        : nonEmptyString(metadata["title"]);
      const body = en
        ? (nonEmptyString(metadata["body_en"]) ?? nonEmptyString(metadata["body"]))
        : nonEmptyString(metadata["body"]);
      return {
        title: title ?? (en ? "Notification" : "إشعار"),
        body: body ?? "",
      };
    }
    default:
      return {
        title: en ? "New notification" : "إشعار جديد",
        body: en ? "There is a new update for Mahwar" : "يوجد تحديث جديد لتطبيق محور",
      };
  }
}
