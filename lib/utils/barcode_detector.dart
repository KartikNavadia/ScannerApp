import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;

/// Finds QR codes / barcodes in a saved photo.
///
/// ML Kit is tried on the photo as is. Photos of a screen or a moving code are
/// often missed at full size (moiré, blur, no quiet zone), so when that finds
/// nothing a few small, smoothed, contrast-stretched copies are tried too.
/// (ML Kit already reads rotated codes, so no rotated copies are needed.)
class BarcodeDetector {
  final BarcodeScanner _scanner = BarcodeScanner();
  bool _closed = false;

  /// Quick pass on the photo as is. Cheap enough to run while capturing.
  Future<List<Barcode>> scanPlain(String path) => _process(path);

  /// Full scan. Pass `plainPass: false` when [scanPlain] already ran on
  /// [path] and found nothing.
  Future<List<Barcode>> scan(String path, {bool plainPass = true}) async {
    var barcodes = plainPass ? await _process(path) : const <Barcode>[];
    if (barcodes.isEmpty && !_closed) barcodes = await _scanEnhanced(path);
    return barcodes;
  }

  Future<List<Barcode>> _process(String path) async {
    if (_closed) return const [];
    try {
      return await _scanner.processImage(InputImage.fromFilePath(path));
    } catch (e) {
      debugPrint('Barcode scan failed for $path: $e');
      return const [];
    }
  }

  Future<List<Barcode>> _scanEnhanced(String path) async {
    List<String> variants = const [];
    try {
      variants = await Isolate.run(() => writeBarcodeVariants(path));
      for (final variant in variants) {
        final found = await _process(variant);
        if (found.isNotEmpty) return found;
      }
    } catch (e) {
      debugPrint('Enhanced scan failed for $path: $e');
    } finally {
      for (final variant in variants) {
        try {
          File(variant).deleteSync();
        } on FileSystemException {
          // Already gone.
        }
      }
    }
    return const [];
  }

  void close() {
    _closed = true;
    _scanner.close();
  }
}

/// Writes small, smoothed grayscale copies of the image at [path] next to it
/// and returns their paths. Kept small so this stays fast.
@visibleForTesting
List<String> writeBarcodeVariants(String path) {
  final source = img.decodeJpg(File(path).readAsBytesSync());
  if (source == null) return const [];

  img.Image shrink(int divisor) => img.copyResize(
    source,
    width: source.width ~/ divisor,
    interpolation: img.Interpolation.average,
  );

  img.Image enhance(img.Image image) =>
      img.normalize(img.grayscale(image), min: 0, max: 255);

  final variants = {
    'half': shrink(2),
    'half_smooth': enhance(img.gaussianBlur(shrink(2), radius: 1)),
    'third': enhance(shrink(3)),
    'quarter': enhance(shrink(4)),
  };

  final paths = <String>[];
  for (final entry in variants.entries) {
    final variantPath = '$path.${entry.key}.jpg';
    File(variantPath).writeAsBytesSync(img.encodeJpg(entry.value, quality: 95));
    paths.add(variantPath);
  }
  return paths;
}
