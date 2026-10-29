import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scanner_app/providers/barcode_scan_provider.dart';
import 'package:scanner_app/utils/barcode_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('BarcodeScanProvider state management test', () {
    final provider = BarcodeScanProvider(const []);
    expect(provider.totalCount, equals(0));
    expect(provider.filter, equals(GalleryFilter.all));
    expect(provider.newestFirst, isFalse);

    provider.setFilter(GalleryFilter.qr);
    expect(provider.filter, equals(GalleryFilter.qr));

    provider.toggleSortOrder();
    expect(provider.newestFirst, isTrue);
  });

  test('Barcode variants are small smoothed / contrast copies', () {
    final tmpDir = Directory.systemTemp.createTempSync('scan_var_');
    final srcFile = File('${tmpDir.path}/frame.jpg');

    final testImg = img.Image(width: 200, height: 200);
    img.fill(testImg, color: img.ColorRgb8(255, 255, 255));
    srcFile.writeAsBytesSync(img.encodeJpg(testImg));

    final variants = writeBarcodeVariants(srcFile.path);

    expect(variants, isNotEmpty);
    // half, half_smooth, third, quarter
    expect(variants.length, equals(4));

    for (final v in variants) {
      expect(File(v).existsSync(), isTrue);
      File(v).deleteSync();
    }

    tmpDir.deleteSync(recursive: true);
  });
}
