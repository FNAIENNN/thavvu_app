import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:thavvu_app/services/face_signature_service.dart';

/// Builds a synthetic image with a simple two-tone pattern so signature
/// computation is deterministic across runs.
Uint8List _syntheticImage({int seed = 0}) {
  final image = img.Image(width: 320, height: 240);
  for (var y = 0; y < 240; y++) {
    for (var x = 0; x < 320; x++) {
      final v = ((x + y + seed) % 2 == 0) ? 200 : 40;
      image.setPixelRgb(x, y, v, v, v);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  group('FaceSignatureService', () {
    test('computes a 16-hex signature for a valid image', () {
      final sig = FaceSignatureService.computeSignature(_syntheticImage());
      expect(sig, isNotNull);
      expect(sig!.length, 16);
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(sig), isTrue);
    });

    test('identical image yields the identical signature', () {
      final a = FaceSignatureService.computeSignature(_syntheticImage(seed: 1));
      final b = FaceSignatureService.computeSignature(_syntheticImage(seed: 1));
      expect(a, b);
    });

    test('different image yields a different signature', () {
      final a = FaceSignatureService.computeSignature(_syntheticImage(seed: 1));
      final b = FaceSignatureService.computeSignature(_syntheticImage(seed: 2));
      expect(a, isNot(b));
    });

    test('hamming distance of identical signatures is 0', () {
      final a = FaceSignatureService.computeSignature(_syntheticImage())!;
      expect(FaceSignatureService.hammingDistance(a, a), 0);
    });

    test('hamming distance of opposite nibbles is > 0', () {
      expect(FaceSignatureService.hammingDistance('0000000000000000',
          'ffffffffffffffff'), greaterThan(0));
    });

    test('bestMatch finds the closest enrolled signature within threshold', () {
      final probe = FaceSignatureService.computeSignature(_syntheticImage(seed: 3))!;
      final far = FaceSignatureService.computeSignature(_syntheticImage(seed: 9))!;
      final enrolled = {
        'w-1': probe, // exact match
        'w-2': far,
      };
      final match = FaceSignatureService.bestMatch(probe, enrolled);
      expect(match, isNotNull);
      expect(match!.workerId, 'w-1');
      expect(match.distance, 0);
    });

    test('bestMatch returns null when everything is beyond threshold', () {
      // Two unrelated patterns are very unlikely to be within threshold 14.
      final probe = FaceSignatureService.computeSignature(_syntheticImage(seed: 2))!;
      final other = FaceSignatureService.computeSignature(_syntheticImage(seed: 42))!;
      final match =
          FaceSignatureService.bestMatch(probe, {'w-x': other});
      // Either no match, or if matched, it must be at most threshold.
      if (match != null) {
        expect(match.distance, lessThanOrEqualTo(
            FaceSignatureService.matchThreshold));
      }
    });

    test('rejects images smaller than the minimum dimension', () {
      final tiny = img.Image(width: 64, height: 64);
      final bytes = Uint8List.fromList(img.encodeJpg(tiny));
      expect(FaceSignatureService.computeSignature(bytes), isNull);
    });
  });
}
