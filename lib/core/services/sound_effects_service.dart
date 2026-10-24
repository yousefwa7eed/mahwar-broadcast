import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../models/order.dart';

/// مؤثرات صوتية قصيرة لأحداث الطلب. الملفات محلية بصيغة WAV (تعمل على
/// Android وiOS) ومأخوذة من حزمة Kenney Interface Sounds بترخيص CC0 —
/// راجع `assets/sounds/LICENSE.txt`.
enum SoundEffect {
  /// حفظ نموذج الطلب والانتقال لاختيار المزوّد (لا صف في قاعدة البيانات بعد).
  requestSubmitted('sounds/request_submitted.wav'),

  /// أُنشئ الطلب فعلياً وأُرسل للمزوّد المختار.
  requestSent('sounds/request_sent.wav'),

  /// وصل طلب جديد إلى المزوّد.
  newOrder('sounds/new_order.wav'),

  /// أرسل المزوّد عرض سعره.
  offerSent('sounds/offer_sent.wav'),

  /// وصل عرض سعر جديد إلى العميل.
  newOffer('sounds/new_offer.wav'),

  /// تأكيد الطلب بعد قبول العرض.
  confirmed('sounds/order_confirmed.wav'),

  /// رفض العرض أو الطلب.
  rejected('sounds/order_rejected.wav'),

  /// اكتمال الخدمة.
  completed('sounds/order_completed.wav'),

  /// إلغاء الطلب (يدوي أو تلقائي).
  cancelled('sounds/order_cancelled.wav'),

  /// إرسال تقييم المزوّد.
  ratingSubmitted('sounds/rating_submitted.wav');

  const SoundEffect(this.assetPath);

  final String assetPath;

  /// المؤثر المناسب لحالة الطلب. `priced` تعني شيئاً مختلفاً لكل طرف:
  /// للعميل «وصل عرض» وللمزوّد «أرسلت عرضك». و`pending` للمزوّد فقط تعني
  /// «طلب جديد»، أما للعميل فهي حالة إنشاء داخلية بلا صوت.
  static SoundEffect? forOrderStatus(
    OrderStatus status, {
    bool forProvider = false,
  }) {
    switch (status) {
      case OrderStatus.pending:
        return forProvider ? SoundEffect.newOrder : null;
      case OrderStatus.priced:
        return forProvider ? SoundEffect.offerSent : SoundEffect.newOffer;
      case OrderStatus.confirmed:
        return SoundEffect.confirmed;
      case OrderStatus.rejectedByProvider:
      case OrderStatus.rejectedByOwner:
        return SoundEffect.rejected;
      case OrderStatus.cancelled:
        return SoundEffect.cancelled;
      case OrderStatus.completed:
        return SoundEffect.completed;
    }
  }
}

/// يشغّل مؤثرات الطلب بمستوى صوت خفيف، ويمنع تكرار نفس المؤثر عندما يصل
/// الحدث من أكثر من مصدر (مثلاً رد الـ RPC المحلي + حدث Realtime، أو شاشتا
/// المالك/التتبع المفتوحتان فوق بعضهما).
///
/// الخدمة خاملة حتى [enable] — يُستدعى مرة واحدة من `main()` بعد تهيئة
/// الـ binding، فتبقى اختبارات الـ widget بلا أي استدعاء لمنصة الصوت.
class SoundEffectsService {
  SoundEffectsService._();

  static final SoundEffectsService instance = SoundEffectsService._();

  static const double _volume = 0.55;
  static const int _playerCount = 2;
  static const Duration _statusDuplicateWindow = Duration(seconds: 4);
  static const Duration _effectDuplicateWindow = Duration(milliseconds: 800);

  bool _enabled = false;
  final List<AudioPlayer> _players = <AudioPlayer>[];
  int _nextPlayer = 0;
  final Map<String, DateTime> _lastPlayed = <String, DateTime>{};

  bool get isEnabled => _enabled;

  /// يفعّل الصوت ويجهّز مشغّلاً واحداً مسبقاً لتقليل تأخير أول مؤثر.
  /// سياق الصوت «مؤثرات واجهة»: يختلط بموسيقى المستخدم بلا سرقتها، ويحترم
  /// مفتاح الصامت على iOS.
  void enable() {
    if (_enabled) return;
    _enabled = true;
    unawaited(
      AudioPlayer.global
          .setAudioContext(AudioContext(
            android: const AudioContextAndroid(
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.assistanceSonification,
              audioFocus: AndroidAudioFocus.none,
            ),
            iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          ))
          .catchError((_) {}),
    );
    _player();
  }

  /// يشغّل مؤثر الحالة مع مفتاح منع تكرار `(الطلب، الحالة)`.
  Future<void> playOrderStatus(
    String orderId,
    OrderStatus status, {
    bool forProvider = false,
  }) {
    final effect = SoundEffect.forOrderStatus(status, forProvider: forProvider);
    if (effect == null) return Future<void>.value();
    return play(effect, dedupeKey: 'order:$orderId:${status.name}');
  }

  /// يشغّل المؤثر بلا throw: أي فشل في المنصة أو الملف لا يكسر المعاملة.
  /// بلا [dedupeKey] يُمنع تكرار نفس المؤثر خلال نافذة قصيرة فقط.
  Future<void> play(SoundEffect effect, {String? dedupeKey}) async {
    if (!_enabled) return;

    final key = dedupeKey ?? 'effect:${effect.name}';
    final window =
        dedupeKey == null ? _effectDuplicateWindow : _statusDuplicateWindow;
    final now = DateTime.now();
    final last = _lastPlayed[key];
    if (last != null && now.difference(last) < window) return;
    _lastPlayed[key] = now;
    if (_lastPlayed.length > 64) {
      _lastPlayed.removeWhere(
        (_, playedAt) => now.difference(playedAt) > _statusDuplicateWindow,
      );
    }

    try {
      final player = _player();
      await player.play(AssetSource(effect.assetPath), volume: _volume);
    } catch (_) {
      // الصوت تجميلي: نتجاهل فشل المنصة/الملف بصمت.
    }
  }

  AudioPlayer _player() {
    while (_players.length < _playerCount) {
      final player = AudioPlayer();
      unawaited(player.setPlayerMode(PlayerMode.lowLatency).catchError((_) {}));
      unawaited(player.setReleaseMode(ReleaseMode.stop).catchError((_) {}));
      _players.add(player);
    }
    final player = _players[_nextPlayer];
    _nextPlayer = (_nextPlayer + 1) % _playerCount;
    return player;
  }

  /// يوقف المشغّلات ويحرّر مواردها (غير مطلوب أثناء عمر التطبيق).
  Future<void> dispose() async {
    for (final player in _players) {
      await player.dispose();
    }
    _players.clear();
    _nextPlayer = 0;
    _lastPlayed.clear();
    _enabled = false;
  }
}
