import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Professional face identity using a 64-bit perceptual hash (dHash).
///
/// Enrollment: a live selfie is captured, downscaled to 9×8 grayscale and
/// hashed into a 64-bit signature (16 hex chars) stored on the worker.
/// Check-in: a live selfie is captured, hashed the same way, and matched
/// against enrolled signatures by Hamming distance.
///
/// This is real image-based matching (not a name-derived string). It works
/// best with frontal, well-lit selfies. Extremely different lighting or
/// pose can raise distance — the UI confirms matches before marking.
class FaceSignatureService {
  FaceSignatureService._();

  /// Maximum Hamming distance (of 64 bits) still considered a match.
  static const int matchThreshold = 14;

  /// Minimum image dimension (px) to accept a selfie for matching.
  static const int minDimension = 160;

  /// Compute the dHash signature from raw image bytes.
  /// Returns 16 hex chars, or null when the image can't be decoded
  /// or is too small to be a useful selfie.
  static String? computeSignature(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      if (decoded.width < minDimension || decoded.height < minDimension) {
        return null;
      }

      // dHash: 9x8 grayscale, compare adjacent pixel brightness.
      final small = img.copyResize(decoded, width: 9, height: 8);
      final grey = img.grayscale(small);

      int hash = 0;
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 8; x++) {
          final left = grey.getPixel(x, y).r.toInt();
          final right = grey.getPixel(x + 1, y).r.toInt();
          if (left < right) {
            hash |= (1 << (y * 8 + x));
          }
        }
      }
      return hash.toRadixString(16).padLeft(16, '0');
    } catch (_) {
      return null;
    }
  }

  /// Hamming distance between two hex signatures (0..64).
  static int hammingDistance(String a, String b) {
    if (a.length != b.length) return 64;
    var distance = 0;
    for (var i = 0; i < a.length; i++) {
      final x = int.parse(a[i], radix: 16);
      final y = int.parse(b[i], radix: 16);
      final xor = x ^ y;
      // popcount of the 4-bit xor
      distance += (xor & 1) +
          ((xor >> 1) & 1) +
          ((xor >> 2) & 1) +
          ((xor >> 3) & 1);
    }
    return distance;
  }

  /// Find the best enrolled match for a probe signature.
  ///
  /// [signatures] maps workerId → enrolled signature.
  /// Returns (workerId, distance) for the closest match when it is within
  /// [matchThreshold], otherwise null.
  static ({String workerId, int distance})? bestMatch(
    String probe,
    Map<String, String> signatures,
  ) {
    String? bestId;
    var bestDistance = matchThreshold + 1;
    signatures.forEach((id, sig) {
      if (sig.length != 16) return;
      final d = hammingDistance(probe, sig);
      if (d < bestDistance) {
        bestDistance = d;
        bestId = id;
      }
    });
    if (bestId == null) return null;
    return (workerId: bestId!, distance: bestDistance);
  }

  /// Human-readable confidence label from a match distance.
  static String confidenceLabel(int distance) {
    if (distance <= 4) return 'Strong match';
    if (distance <= 8) return 'Good match';
    if (distance <= matchThreshold) return 'Possible match';
    return 'No match';
  }
}
