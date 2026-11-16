import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Result of the local privacy pass applied before a photo is uploaded.
class PhotoPrivacyResult {
  const PhotoPrivacyResult({
    required this.file,
    required this.blurredRegionCount,
    required this.detectionCompleted,
  });

  final File file;
  final int blurredRegionCount;
  final bool detectionCompleted;

  bool get needsPreviewWarning =>
      !detectionCompleted || blurredRegionCount == 0;
}

/// Removes camera metadata and masks likely personal regions locally.
///
/// ML Kit is used only on Android/iOS. On unsupported targets the image is
/// still decoded and re-encoded, which removes EXIF/GPS metadata, but no
/// automatic region detection is claimed.
class PhotoPrivacyService {
  const PhotoPrivacyService._();

  static bool get supportsAutomaticRedaction =>
      Platform.isAndroid || Platform.isIOS;

  static Future<PhotoPrivacyResult> sanitize(File source) async {
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Fotoğraf okunamadı.');
    }

    // Normalize EXIF orientation before detection so ML Kit boxes and blur
    // coordinates use the same upright pixel space.
    final image = img.bakeOrientation(decoded);
    final outputDir = await getTemporaryDirectory();
    final normalizedInput = File(
      '${outputDir.path}/parkist_detection_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await normalizedInput.writeAsBytes(
      img.encodeJpg(image, quality: 95),
      flush: true,
    );

    final regions = <_PrivacyRegion>[];
    var detectionCompleted = false;

    try {
      if (supportsAutomaticRedaction) {
        try {
          final input = InputImage.fromFile(normalizedInput);
          final faceDetector = FaceDetector(
            options: FaceDetectorOptions(
              performanceMode: FaceDetectorMode.fast,
              minFaceSize: 0.08,
            ),
          );
          final textRecognizer = TextRecognizer(
            script: TextRecognitionScript.latin,
          );
          try {
            final faces = await faceDetector.processImage(input);
            regions.addAll(
              faces.map(
                (face) => _PrivacyRegion(face.boundingBox, reason: 'yüz'),
              ),
            );
            final recognized = await textRecognizer.processImage(input);
            regions.addAll(
              recognized.blocks
                  .where(_looksLikeVehicleText)
                  .map(
                    (block) =>
                        _PrivacyRegion(block.boundingBox, reason: 'olası plaka'),
                  ),
            );
            detectionCompleted = true;
          } finally {
            await faceDetector.close();
            await textRecognizer.close();
          }
        } catch (_) {
          // Keep metadata cleanup, but the mobile upload flow fails closed when
          // automatic detection cannot complete.
          detectionCompleted = false;
        }
      }

      final mergedRegions = _mergeRegions(regions);
      for (final region in mergedRegions) {
        _blurRegion(image, region.rect);
      }

      final output = File(
        '${outputDir.path}/parkist_privacy_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      // Re-encoding is intentional: it drops EXIF/GPS and other camera tags.
      await output.writeAsBytes(img.encodeJpg(image, quality: 90), flush: true);
      return PhotoPrivacyResult(
        file: output,
        blurredRegionCount: mergedRegions.length,
        detectionCompleted: detectionCompleted,
      );
    } finally {
      if (await normalizedInput.exists()) {
        await normalizedInput.delete();
      }
    }
  }

  static bool _looksLikeVehicleText(TextBlock block) {
    final normalized = block.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (normalized.length < 4 || normalized.length > 10) return false;
    final hasDigit = normalized.contains(RegExp(r'\d'));
    final box = block.boundingBox;
    final width = box.width.abs();
    final height = box.height.abs();
    if (!hasDigit || height < 8 || width < 24) return false;
    final aspectRatio = width / height;
    return aspectRatio >= 1.5 && aspectRatio <= 8.0;
  }

  static List<_PrivacyRegion> _mergeRegions(List<_PrivacyRegion> regions) {
    final result = <_PrivacyRegion>[];
    for (final region in regions) {
      if (result.any((existing) => existing.rect.overlaps(region.rect))) {
        continue;
      }
      result.add(region);
    }
    return result;
  }

  static void _blurRegion(img.Image image, Rect rect) {
    final padX = math.max(8, (rect.width * 0.22).round());
    final padY = math.max(8, (rect.height * 0.28).round());
    final left = math.max(0, rect.left.floor() - padX);
    final top = math.max(0, rect.top.floor() - padY);
    final right = math.min(image.width, rect.right.ceil() + padX);
    final bottom = math.min(image.height, rect.bottom.ceil() + padY);
    final width = math.max(1, right - left);
    final height = math.max(1, bottom - top);
    final crop = img.copyCrop(
      image,
      x: left,
      y: top,
      width: width,
      height: height,
    );
    final radius = math.max(
      8,
      math.min(26, (math.min(width, height) / 5).round()),
    );
    img.gaussianBlur(crop, radius: radius);
    img.compositeImage(image, crop, dstX: left, dstY: top);
  }
}

class _PrivacyRegion {
  const _PrivacyRegion(this.rect, {required this.reason});

  final Rect rect;
  final String reason;
}
