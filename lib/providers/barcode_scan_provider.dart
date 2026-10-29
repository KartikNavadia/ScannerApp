import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../utils/barcode_detector.dart';

enum GalleryFilter { all, qr, noQr }

class BarcodeScanProvider extends ChangeNotifier {
  /// [scanned] holds codes already found while capturing, and
  /// [plainChecked] the images that already had a quick full-size pass, so
  /// those aren't repeated here.
  BarcodeScanProvider(
    List<String> imagePaths, {
    Map<String, List<Barcode>> scanned = const {},
    Set<String> plainChecked = const {},
  }) : _imagePaths = List.of(imagePaths),
       // ignore: prefer_initializing_formals
       _plainChecked = plainChecked {
    _results.addAll(scanned);
    _scanAll();
  }

  final List<String> _imagePaths;
  final Set<String> _plainChecked;
  final BarcodeDetector _detector = BarcodeDetector();
  bool _disposed = false;
  GalleryFilter _filter = GalleryFilter.all;
  final Map<String, DateTime> _capturedAt = {};

  /// Detected barcodes per image path. A missing key means not scanned yet.
  final Map<String, List<Barcode>> _results = {};

  int get scannedCount => _results.length;
  List<String> get imagePaths => List.unmodifiable(_imagePaths);
  int get totalCount => _imagePaths.length;
  bool get isDone => scannedCount >= totalCount;

  GalleryFilter get filter => _filter;

  void setFilter(GalleryFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    notifyListeners();
  }

  /// Images matching the current [filter]. "All" includes images that are
  /// still being scanned.
  List<String> get visiblePaths => switch (_filter) {
    GalleryFilter.all => imagePaths,
    GalleryFilter.qr => codeImagePaths,
    GalleryFilter.noQr => normalImagePaths,
  };

  bool _newestFirst = false;

  /// Sort order for the detected-codes list.
  bool get newestFirst => _newestFirst;

  void toggleSortOrder() {
    _newestFirst = !_newestFirst;
    notifyListeners();
  }

  /// Every detected code with the image it was found in, in capture order
  /// (or reversed when [newestFirst]).
  List<({String path, Barcode barcode})> get detectedCodes {
    final entries = [
      for (final path in _imagePaths)
        for (final barcode in _results[path] ?? const <Barcode>[])
          (path: path, barcode: barcode),
    ];
    return _newestFirst ? entries.reversed.toList() : entries;
  }

  bool hasCodes(String path) => _results[path]?.isNotEmpty ?? false;

  /// When the image was captured (its file's modified time), cached.
  DateTime capturedAt(String path) => _capturedAt.putIfAbsent(path, () {
    try {
      return File(path).lastModifiedSync();
    } on FileSystemException {
      return DateTime.now();
    }
  });

  /// Scanned images in which at least one QR/barcode was detected.
  List<String> get codeImagePaths => [
    for (final path in _imagePaths)
      if (_results[path]?.isNotEmpty ?? false) path,
  ];

  /// Scanned images with no QR/barcode.
  List<String> get normalImagePaths => [
    for (final path in _imagePaths)
      if (_results[path]?.isEmpty ?? false) path,
  ];

  /// Null while the image is still being scanned.
  List<Barcode>? resultsFor(String path) => _results[path];

  @override
  void dispose() {
    _disposed = true;
    _detector.close();
    super.dispose();
  }

  Future<void> _scanAll() async {
    for (final path in List.of(_imagePaths)) {
      if (_disposed || !_imagePaths.contains(path)) return;
      if (_results.containsKey(path)) continue;
      final barcodes = await _detector.scan(
        path,
        plainPass: !_plainChecked.contains(path),
      );
      if (_disposed || !_imagePaths.contains(path)) return;
      _results[path] = barcodes;
      notifyListeners();
    }
  }

  /// Removes all images from the list and deletes their files.
  Future<void> clearAll() async {
    final paths = List.of(_imagePaths);
    _imagePaths.clear();
    _results.clear();
    notifyListeners();
    for (final path in paths) {
      try {
        await File(path).delete();
      } on FileSystemException catch (e) {
        debugPrint('Failed to delete $path: $e');
      }
    }
  }
}
