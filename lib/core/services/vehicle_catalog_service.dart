import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vehicle_catalog.dart';

class VehicleCatalogException implements Exception {
  VehicleCatalogException(this.cause);

  final Object cause;

  @override
  String toString() => 'VehicleCatalogException: $cause';
}

/// يجلب كتالوج السيارات من قاعدة البيانات ويحفظه محليًا (كاش 24 ساعة).
///
/// المصدر الرسمي هو جداول `vehicle_*`؛ الكاش المحلي مجرد تسريع/عمل دون اتصال
/// بعد أول تحميل ناجح. عند فشل التحديث تُستخدم آخر نسخة محفوظة إن وُجدت.
class VehicleCatalogService {
  VehicleCatalogService._();

  static final VehicleCatalogService instance = VehicleCatalogService._();

  static const Duration cacheTtl = Duration(hours: 24);
  static const String _cacheFileName = 'vehicle_catalog_v1.json';

  /// شجرة الكتالوج كاملة في طلب PostgREST واحد عبر تضمين FK.
  static const String _catalogSelect =
      'id,name_ar,name_en,country_code,logo_asset,brand_color,is_popular,sort_order,'
      'models:vehicle_models(id,name_ar,name_en,body_type,sort_order,'
      'generations:vehicle_generations(id,year_from,year_to,name_ar,name_en,sort_order,'
      'trims:vehicle_trims(id,name_ar,name_en,engine_cc,fuel,transmission,horsepower,seats,sort_order)))';

  VehicleCatalog? _memory;
  Future<VehicleCatalog>? _pending;
  bool _refreshing = false;

  Future<VehicleCatalog> load({bool forceRefresh = false}) {
    final cached = _memory;
    if (!forceRefresh && cached != null) {
      if (_isFresh(cached.fetchedAt)) return Future.value(cached);
      // stale-while-revalidate: نعرض النسخة القديمة فورًا ونحدّثها بالخلفية.
      _refreshInBackground();
      return Future.value(cached);
    }

    final pending = _pending;
    if (pending != null) return pending;

    final future = _load(forceRefresh: forceRefresh);
    _pending = future;
    return future.whenComplete(() => _pending = null);
  }

  /// يُستخدم في الاختبارات فقط لتجاوز الشبكة.
  @visibleForTesting
  void setCatalogForTesting(VehicleCatalog? catalog) {
    _memory = catalog;
  }

  Future<VehicleCatalog> _load({required bool forceRefresh}) async {
    final disk = await _readCache();

    if (disk != null && !forceRefresh) {
      _memory = disk;
      if (!_isFresh(disk.fetchedAt)) {
        _refreshInBackground();
      }
      return disk;
    }

    try {
      final fetched = await _fetchFromServer();
      _memory = fetched;
      await _writeCache(fetched);
      return fetched;
    } catch (error) {
      if (disk != null) {
        _memory = disk;
        return disk;
      }
      if (_memory != null) return _memory!;
      throw VehicleCatalogException(error);
    }
  }

  void _refreshInBackground() {
    if (_refreshing) return;
    _refreshing = true;
    unawaited(() async {
      try {
        final fetched = await _fetchFromServer();
        _memory = fetched;
        await _writeCache(fetched);
      } catch (_) {
        // الكاش القديم يكفي حتى المحاولة التالية.
      } finally {
        _refreshing = false;
      }
    }());
  }

  bool _isFresh(DateTime fetchedAt) {
    final age = DateTime.now().toUtc().difference(fetchedAt.toUtc());
    return !age.isNegative && age < cacheTtl;
  }

  Future<VehicleCatalog> _fetchFromServer() async {
    final client = Supabase.instance.client;

    // طلب واحد متداخل بدل 8 طلبات متتالية (كانت تكلّف ثواني على الشبكات البطيئة).
    final responses = await Future.wait<List<dynamic>>([
      client
          .from('vehicle_brands')
          .select(_catalogSelect)
          .eq('is_active', true)
          .eq('models.is_active', true)
          .eq('models.generations.is_active', true)
          .eq('models.generations.trims.is_active', true)
          .order('sort_order'),
      client.from('vehicle_colors').select().order('sort_order'),
    ]);

    // نستبعد كل فرع بلا أبناء نشطين، وإلا وصل المستخدم إلى خطوة فارغة لا يكملها.
    final brands = <VehicleBrand>[];
    for (final row in _asMaps(responses[0])) {
      final models = <Map<String, dynamic>>[];
      for (final model in _bySortOrder(
          _asMaps(row['models'] as List? ?? const []))) {
        final generations = <Map<String, dynamic>>[
          for (final generation in _byYear(
              _asMaps(model['generations'] as List? ?? const [])))
            if ((generation['trims'] as List? ?? const []).isNotEmpty)
              {
                ...generation,
                'trims': _bySortOrder(
                    _asMaps(generation['trims'] as List? ?? const [])),
              },
        ];
        if (generations.isEmpty) continue;
        models.add({...model, 'generations': generations});
      }
      if (models.isEmpty) continue;
      brands.add(VehicleBrand.fromJson({...row, 'models': models}));
    }

    return VehicleCatalog(
      fetchedAt: DateTime.now().toUtc(),
      brands: brands,
      colors: _asMaps(responses[1])
          .map((row) => VehicleColor.fromJson({
                'id': row['id'],
                'name_ar': row['name_ar'],
                'name_en': row['name_en'],
                'hex': row['hex'],
                'sort_order': row['sort_order'] ?? 0,
              }))
          .toList(growable: false),
    );
  }

  List<Map<String, dynamic>> _bySortOrder(List<Map<String, dynamic>> rows) =>
      [...rows]..sort(
          (a, b) => _int(a['sort_order']).compareTo(_int(b['sort_order'])));

  List<Map<String, dynamic>> _byYear(List<Map<String, dynamic>> rows) =>
      [...rows]..sort((a, b) {
          final byYear =
              _int(a['year_from']).compareTo(_int(b['year_from']));
          return byYear != 0
              ? byYear
              : _int(a['sort_order']).compareTo(_int(b['sort_order']));
        });

  List<Map<String, dynamic>> _asMaps(List<dynamic> rows) => rows
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);

  int _int(Object? value) => value is num ? value.toInt() : 0;

  Future<File?> _cacheFile() async {
    try {
      final directory = await getApplicationSupportDirectory();
      return File('${directory.path}${Platform.pathSeparator}$_cacheFileName');
    } catch (_) {
      return null;
    }
  }

  Future<VehicleCatalog?> _readCache() async {
    final file = await _cacheFile();
    if (file == null || !await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map || decoded['version'] != VehicleCatalog.schemaVersion) {
        return null;
      }
      return VehicleCatalog.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(VehicleCatalog catalog) async {
    final file = await _cacheFile();
    if (file == null) return;
    try {
      await file.writeAsString(jsonEncode({
        'version': VehicleCatalog.schemaVersion,
        'fetched_at': catalog.fetchedAt.toIso8601String(),
        'brands': [
          for (final brand in catalog.brands)
            {
              'id': brand.id,
              'name_ar': brand.nameAr,
              'name_en': brand.nameEn,
              'country_code': brand.countryCode,
              'logo_asset': brand.logoAsset,
              'brand_color': brand.brandColor,
              'is_popular': brand.isPopular,
              'sort_order': brand.sortOrder,
              'models': [
                for (final model in brand.models)
                  {
                    'id': model.id,
                    'name_ar': model.nameAr,
                    'name_en': model.nameEn,
                    'body_type': model.bodyType,
                    'sort_order': model.sortOrder,
                    'generations': [
                      for (final generation in model.generations)
                        {
                          'id': generation.id,
                          'year_from': generation.yearFrom,
                          'year_to': generation.yearTo,
                          'name_ar': generation.nameAr,
                          'name_en': generation.nameEn,
                          'sort_order': generation.sortOrder,
                          'trims': [
                            for (final trim in generation.trims)
                              {
                                'id': trim.id,
                                'name_ar': trim.nameAr,
                                'name_en': trim.nameEn,
                                'engine_cc': trim.engineCc,
                                'fuel': trim.fuel,
                                'transmission': trim.transmission,
                                'horsepower': trim.horsepower,
                                'seats': trim.seats,
                                'sort_order': trim.sortOrder,
                              },
                          ],
                        },
                    ],
                  },
              ],
            },
        ],
        'colors': [
          for (final color in catalog.colors)
            {
              'id': color.id,
              'name_ar': color.nameAr,
              'name_en': color.nameEn,
              'hex': color.hex,
              'sort_order': color.sortOrder,
            },
        ],
      }));
    } catch (error) {
      debugPrint('vehicle catalog cache write failed: $error');
    }
  }
}
