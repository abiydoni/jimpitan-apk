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

class ImageCompressor {
  static Future<String?> compressImage(Uint8List bytes, {int width = 300, int quality = 30}) async {
    return await compute(_compressImageIsolate, {
      'bytes': bytes,
      'width': width,
      'quality': quality,
    });
  }
}
