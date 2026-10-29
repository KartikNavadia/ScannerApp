import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// A copy of a [CameraImage] that can be sent to another isolate.
class _Frame {
  _Frame(CameraImage image, this.rotation, this.path)
    : width = image.width,
      height = image.height,
      isBgra = image.format.group == ImageFormatGroup.bgra8888,
      planes = [for (final p in image.planes) p.bytes],
      rowStrides = [for (final p in image.planes) p.bytesPerRow],
      pixelStrides = [for (final p in image.planes) p.bytesPerPixel ?? 1];

  final int width;
  final int height;
  final bool isBgra;
  final List<Uint8List> planes;
  final List<int> rowStrides;
  final List<int> pixelStrides;

  /// Clockwise rotation in degrees (0, 90, 180 or 270).
  final int rotation;
  final String path;
}

/// Converts a camera stream frame to an upright JPEG at [path] on a
/// background isolate, so the camera preview is never blocked.
Future<String> encodeFrameToJpeg(CameraImage image, int rotation, String path) {
  final frame = _Frame(image, rotation, path);
  return Isolate.run(() => _encode(frame));
}

String _encode(_Frame f) {
  final w = f.width;
  final h = f.height;
  final rotated = f.rotation % 180 != 0;
  final outW = rotated ? h : w;
  final outH = rotated ? w : h;
  final rgb = Uint8List(outW * outH * 3);

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      int r, g, b;
      if (f.isBgra) {
        final i = y * f.rowStrides[0] + x * 4;
        final p = f.planes[0];
        b = p[i];
        g = p[i + 1];
        r = p[i + 2];
      } else {
        // YUV420 -> RGB (BT.601).
        final yy = f.planes[0][y * f.rowStrides[0] + x];
        final uvIndex1 =
            (y >> 1) * f.rowStrides[1] + (x >> 1) * f.pixelStrides[1];
        final uvIndex2 = f.planes.length > 2
            ? (y >> 1) * f.rowStrides[2] + (x >> 1) * f.pixelStrides[2]
            : uvIndex1;
        final u = f.planes[1][uvIndex1] - 128;
        final v = (f.planes.length > 2 ? f.planes[2][uvIndex2] : 128) - 128;
        r = (yy + ((1436 * v) >> 10)).clamp(0, 255);
        g = (yy - ((352 * u + 731 * v) >> 10)).clamp(0, 255);
        b = (yy + ((1815 * u) >> 10)).clamp(0, 255);
      }

      final int dx, dy;
      switch (f.rotation) {
        case 90:
          dx = h - 1 - y;
          dy = x;
        case 180:
          dx = w - 1 - x;
          dy = h - 1 - y;
        case 270:
          dx = y;
          dy = w - 1 - x;
        default:
          dx = x;
          dy = y;
      }
      final o = (dy * outW + dx) * 3;
      rgb[o] = r;
      rgb[o + 1] = g;
      rgb[o + 2] = b;
    }
  }

  final image = img.Image.fromBytes(
    width: outW,
    height: outH,
    bytes: rgb.buffer,
    numChannels: 3,
  );
  File(f.path).writeAsBytesSync(img.encodeJpg(image, quality: 90));
  return f.path;
}
