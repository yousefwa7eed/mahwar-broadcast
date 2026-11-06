/// بُناة معاملات ونتائج RPC الفحص الدُفعي لهويات أطراف الطلب.
///
/// Must match the exact PostgREST argument names of the SECURITY DEFINER
/// function in the database (PostgREST resolves RPC by name + argument names,
/// so a wrong key fails with `PGRST202`).
///
/// Live signature:
///   get_public_profiles(p_user_ids uuid[])
///   → rows of {user_id, full_name, role, avatar_id, avatar_url}
///
/// Authorization is fail-closed server-side: ids the caller may not see are
/// simply absent from the rows. Never carries phone_number — owner contact is
/// released only by get_order_contact() once the order is confirmed.
library;

Map<String, dynamic> buildGetPublicProfilesParams({
  required List<String> userIds,
}) {
  return {'p_user_ids': userIds};
}

/// دمج صفوف الـ RPC في خرائط اللوحة، بنفس سلوك الفحص الفردي السابق:
/// اسم مُنقّح مع بديل افتراضي عند الغياب أو الفراغ، وصور فقط إذا غير فارغة.
class OwnerProfilesResolution {
  const OwnerProfilesResolution({
    required this.names,
    required this.avatarIds,
    required this.avatarUrls,
  });

  final Map<String, String> names;
  final Map<String, String> avatarIds;
  final Map<String, String> avatarUrls;
}

OwnerProfilesResolution resolveOwnerProfiles({
  required List<Object?> rows,
  required Set<String> requestedIds,
  required String fallbackName,
}) {
  final byId = <String, Map>{};
  for (final row in rows) {
    if (row is Map && row['user_id'] is String) {
      byId[row['user_id'] as String] = row;
    }
  }

  final names = <String, String>{};
  final avatarIds = <String, String>{};
  final avatarUrls = <String, String>{};
  for (final id in requestedIds) {
    final row = byId[id];
    if (row == null) {
      names[id] = fallbackName;
      continue;
    }
    final name = (row['full_name'] as String?)?.trim();
    names[id] = (name == null || name.isEmpty) ? fallbackName : name;
    final avatarId = row['avatar_id'] as String?;
    if (avatarId != null && avatarId.isNotEmpty) avatarIds[id] = avatarId;
    final avatarUrl = row['avatar_url'] as String?;
    if (avatarUrl != null && avatarUrl.isNotEmpty) avatarUrls[id] = avatarUrl;
  }
  return OwnerProfilesResolution(
    names: names,
    avatarIds: avatarIds,
    avatarUrls: avatarUrls,
  );
}

/// تجزئة العمل المستقل (جيوكود مثلًا) إلى دفعات متوازية بحد أقصى [cap]،
/// فتنفّذ كل قائمة بدفعاتها بالتتابع.
Future<List<R>> mapBounded<T, R>(
  List<T> items,
  int cap,
  Future<R> Function(T) work,
) async {
  final results = <R>[];
  for (var start = 0; start < items.length; start += cap) {
    final end = (start + cap).clamp(0, items.length);
    results.addAll(
      await Future.wait(items.sublist(start, end).map(work)),
    );
  }
  return results;
}
