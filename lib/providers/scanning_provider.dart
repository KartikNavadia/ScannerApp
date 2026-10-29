import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/barcode_detector.dart';
import '../utils/frame_encoder.dart';

enum PermissionResult { granted, denied, permanentlyDenied }

class ScanningProvider extends ChangeNotifier {
  CameraController? _controller;
  bool _permissionsGranted = false;
  bool _isCapturing = false;
  bool _isTorchOn = false;
  bool _disposed = false;
  final List<String> _capturedPaths = [];

  /// Frames currently being encoded to JPEG on background isolates.
  final Set<Future<void>> _pendingEncodes = {};
  static const _maxConcurrentEncodes = 2;
  Directory? _captureDir;

  /// Frames get a quick barcode pass while capturing, one at a time, so most
  /// codes are already found by the time the user taps Stop.
  final BarcodeDetector _detector = BarcodeDetector();
  final List<String> _scanQueue = [];
  final Map<String, List<Barcode>> _found = {};
  final Set<String> _plainChecked = {};
  Future<void>? _scanLoop;
  int _frameCounter = 0;

  final StreamController<String> _messages = StreamController.broadcast();

  CameraController? get controller => _controller;
  bool get permissionsGranted => _permissionsGranted;
  bool get isCapturing => _isCapturing;
  bool get isTorchOn => _isTorchOn;
  bool get isCameraReady => _controller?.value.isInitialized ?? false;
  int get capturedCount => _capturedPaths.length;

  /// One-off messages (errors etc.) for the UI to show as snackbars.
  Stream<String> get messages => _messages.stream;

  @override
  void dispose() {
    _disposed = true;
    _isCapturing = false;
    _controller?.dispose();
    _messages.close();
    _detector.close();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _showMessage(String message) {
    if (!_disposed) _messages.add(message);
  }

  Future<PermissionResult> requestPermissions() async {
    if (_permissionsGranted) return PermissionResult.granted;

    final camera = await Permission.camera.request();

    if (camera.isGranted) {
      _permissionsGranted = true;
      _notify();
      await initCamera();
      return PermissionResult.granted;
    }

    return camera.isPermanentlyDenied || camera.isRestricted
        ? PermissionResult.permanentlyDenied
        : PermissionResult.denied;
  }

  Future<void> initCamera() async {
    if (_controller != null || _disposed) return;
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showMessage('No camera found on this device');
        return;
      }
      if (_disposed || _controller != null) return;
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        backCamera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        // Formats the frame encoder knows how to convert.
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      _controller = controller;
      await controller.initialize();
      // A lifecycle change may have disposed/replaced this controller while
      // it was initializing; the resume handler takes care of re-init.
      if (_controller != controller) return;
      _isTorchOn = false;
      try {
        await controller.setFlashMode(FlashMode.off);
      } on CameraException catch (e) {
        // Not all cameras support flash; this shouldn't block the preview.
        debugPrint('setFlashMode failed: ${e.code}');
      }
      _notify();
    } catch (e) {
      // Ignore errors from a controller that was already disposed/replaced,
      // otherwise we'd null out the newer, working controller.
      if (controller != null && _controller != controller) return;
      _controller = null;
      await controller?.dispose();
      _showMessage(
        'Camera error: ${e is CameraException ? e.description ?? e.code : e}',
      );
      _notify();
    }
  }

  /// Releases the camera, e.g. when the app goes to the background.
  void releaseCamera() {
    _isCapturing = false;
    _isTorchOn = false;
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    _notify();
  }

  /// Turns the flashlight on or off. Works while capturing too.
  Future<void> toggleTorch() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final turnOn = !_isTorchOn;
    try {
      await controller.setFlashMode(turnOn ? FlashMode.torch : FlashMode.off);
      if (_controller != controller) return;
      _isTorchOn = turnOn;
      _notify();
    } on CameraException catch (e) {
      _showMessage('Flashlight unavailable: ${e.description ?? e.code}');
    }
  }

  Future<void> startCapturing() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }
    _isCapturing = true;
    _capturedPaths.clear();
    _scanQueue.clear();
    _found.clear();
    _plainChecked.clear();
    _notify();

    // Grab frames from the live image stream instead of calling
    // takePicture(), which briefly pauses the preview on every shot.
    try {
      _captureDir ??= await Directory.systemTemp.createTemp('scan_');
      await controller.startImageStream(
        (image) => _onFrame(image, controller.description.sensorOrientation),
      );
    } on CameraException catch (e) {
      _isCapturing = false;
      _showMessage('Camera error: ${e.description ?? e.code}');
      _notify();
    }
  }

  void _onFrame(CameraImage image, int sensorOrientation) {
    // Drop frames while the encoders are busy rather than queueing them.
    if (!_isCapturing ||
        _disposed ||
        _pendingEncodes.length >= _maxConcurrentEncodes) {
      return;
    }
    // Stream frames come in the sensor's landscape orientation; rotate them
    // upright for the portrait UI.
    final rotation = image.width > image.height ? sensorOrientation : 0;
    final path = '${_captureDir!.path}/frame_${_frameCounter++}.jpg';

    late final Future<void> encode;
    encode = () async {
      try {
        final saved = await encodeFrameToJpeg(image, rotation, path);
        if (_disposed) return;
        _capturedPaths.add(saved);
        _scanQueue.add(saved);
        _scanLoop ??= _drainScanQueue();
        _notify();
      } catch (e) {
        debugPrint('Frame encode failed: $e');
      } finally {
        _pendingEncodes.remove(encode);
      }
    }();
    _pendingEncodes.add(encode);
  }

  Future<void> _drainScanQueue() async {
    try {
      while (_scanQueue.isNotEmpty && !_disposed) {
        final path = _scanQueue.removeAt(0);
        final barcodes = await _detector.scanPlain(path);
        _plainChecked.add(path);
        // Photos with no code are left for the gallery's fuller scan.
        if (barcodes.isNotEmpty) _found[path] = barcodes;
      }
    } finally {
      _scanLoop = null;
    }
  }

  /// Codes found while capturing, and the photos that already had a quick
  /// pass. Valid after [stopCapturing].
  Map<String, List<Barcode>> get foundCodes => Map.of(_found);
  Set<String> get plainChecked => Set.of(_plainChecked);

  /// Stops capturing and returns the captured image paths.
  Future<List<String>> stopCapturing() async {
    if (!_isCapturing) return const [];
    _isCapturing = false;
    _notify();

    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } on CameraException catch (e) {
        debugPrint('stopImageStream failed: ${e.code}');
      }
    }
    // Let in-flight frames finish encoding before returning.
    await Future.wait(List.of(_pendingEncodes));
    // Photos still waiting for their quick pass go to the gallery instead.
    _scanQueue.clear();
    await _scanLoop;
    final paths = List.of(_capturedPaths);
    _capturedPaths.clear();
    return paths;
  }
}
