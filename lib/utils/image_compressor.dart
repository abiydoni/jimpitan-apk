import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

String? _compressImageIsolate(Map<String, dynamic> args) {
  try {
    final Uint8List bytes = args['bytes'];
    final int width = args['width'];
    final int quality = args['quality'];
    
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage != null) {
      final resized = img.copyResize(decodedImage, width: width);
      final compressedBytes = img.encodeJpg(resized, quality: quality);
      return base64Encode(compressedBytes);
    }
  } catch (e) {
    debugPrint('Isolate error: $e');
  }
  return null;
}

String? _cropAndCompressFunction(Map<String, dynamic> args) {
  try {
    final Uint8List bytes = args['bytes'];
    final double alignmentX = (args['alignmentX'] as num).toDouble();
    final double alignmentY = (args['alignmentY'] as num).toDouble();
    final double targetAspectRatio = (args['targetAspectRatio'] as num).toDouble();
    final int targetWidth = args['targetWidth'];
    final int quality = args['quality'];

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final origWidth = decoded.width;
    final origHeight = decoded.height;
    final currentRatio = origWidth / origHeight;

    int cropX = 0;
    int cropY = 0;
    int cropW = origWidth;
    int cropH = origHeight;

    if (currentRatio > targetAspectRatio) {
      // Gambar lebih lebar dari target -> potong kiri/kanan
      cropW = (origHeight * targetAspectRatio).round();
      if (cropW > origWidth) cropW = origWidth;
      final maxShift = origWidth - cropW;
      // alignmentX: -1 (kiri), 0 (tengah), 1 (kanan)
      cropX = ((maxShift * ((alignmentX + 1.0) / 2.0))).round().clamp(0, maxShift);
    } else {
      // Gambar lebih tinggi dari target -> potong atas/bawah
      cropH = (origWidth / targetAspectRatio).round();
      if (cropH > origHeight) cropH = origHeight;
      final maxShift = origHeight - cropH;
      // alignmentY: -1 (atas), 0 (tengah), 1 (bawah)
      cropY = ((maxShift * ((alignmentY + 1.0) / 2.0))).round().clamp(0, maxShift);
    }

    final cropped = img.copyCrop(
      decoded,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );

    final resized = img.copyResize(cropped, width: targetWidth);
    final compressedBytes = img.encodeJpg(resized, quality: quality);
    return base64Encode(compressedBytes);
  } catch (e) {
    debugPrint('Crop & Compress error: $e');
  }
  return null;
}

class ImageCompressor {
  static Future<String?> compressImage(Uint8List bytes, {int width = 300, int quality = 30}) async {
    return await compute(_compressImageIsolate, {
      'bytes': bytes,
      'width': width,
      'quality': quality,
    });
  }

  static Future<String?> cropAndCompressImage(
    Uint8List bytes, {
    double alignmentX = 0.0,
    double alignmentY = 0.0,
    double targetAspectRatio = 2.4,
    int targetWidth = 600,
    int quality = 65,
  }) async {
    final args = {
      'bytes': bytes,
      'alignmentX': alignmentX,
      'alignmentY': alignmentY,
      'targetAspectRatio': targetAspectRatio,
      'targetWidth': targetWidth,
      'quality': quality,
    };
    if (kIsWeb) {
      return _cropAndCompressFunction(args);
    }
    return await compute(_cropAndCompressFunction, args);
  }
}
