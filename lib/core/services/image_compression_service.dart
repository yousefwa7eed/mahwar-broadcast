import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// خدمة ضغط الصور قبل رفعها إلى التخزين.
///
/// تقلص الأبعاد إلى حد أقصى [maxDimension] على الجانب الأطول وتحول
/// الصورة إلى JPEG بجودة [quality] لتصغير الحجم بشكل ملحوظ بما يكفي
/// لغرض التوثيق، وفي فشل الضغط (صيغة غير مدعومة مثلاً) تعيد الملف الأصلي.
class ImageCompressionService {
  const ImageCompressionService({this.quality = 70, this.maxDimension = 1024});

  final int quality;
  final int maxDimension;

  Future<File> compress(File source) async {
    final originalBytes = await source.length();

    try {
      final dir = await getTemporaryDirectory();
      final outputPath = p.join(
        dir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        source.path,
        outputPath,
        quality: quality,
        minWidth: maxDimension,
        minHeight: maxDimension,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        final compressedBytes = await result.length();
        debugPrint(
          '[ImageCompression] ${p.basename(source.path)}: '
          '${_formatBytes(originalBytes)} -> ${_formatBytes(compressedBytes)} '
          '($quality% quality, max $maxDimension px)',
        );
        return File(result.path);
      }
    } catch (e, st) {
      debugPrint('[ImageCompression] فشل ضغط الصورة (سنرفع الأصل): $e');
      debugPrint('$st');
    }

    return source;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// أداة بسيطة لقياس مدة كل مرحلة من مراحل إرسال الطلب بالصور
/// (ضغط / رفع / استجابة السيرفر) وطباعتها في الـ console للتشخيص.
class OrderSubmitTimer {
  final Map<String, Duration> _samples = {};
  final Stopwatch _current = Stopwatch();
  String _label = '';

  void start(String label) {
    _label = label;
    _current
      ..reset()
      ..start();
  }

  void stop() {
    _current.stop();
    _samples[_label] = _current.elapsed;
  }

  void report() {
    for (final entry in _samples.entries) {
      debugPrint('[OrderSubmitTiming] ${entry.key}: ${entry.value.inMilliseconds}ms');
    }
  }

  String? lastResult(String label) {
    final d = _samples[label];
    return d == null ? null : '${d.inMilliseconds}ms';
  }
}