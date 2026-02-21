import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_repository/model_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('model_integrity_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ModelIntegrity', () {
    group('computeChecksum', () {
      test('computes correct SHA-256 for known content', () async {
        final file = File('${tempDir.path}/test.bin');
        final content = 'Hello, GrammarLens!';
        file.writeAsStringSync(content);

        // Compute expected hash independently.
        final expectedHash = sha256.convert(content.codeUnits).toString();

        final computed = await ModelIntegrity.computeChecksum(file.path);
        expect(computed, expectedHash);
      });

      test('computes checksum for empty file', () async {
        final file = File('${tempDir.path}/empty.bin');
        file.writeAsBytesSync([]);

        // SHA-256 of empty input.
        final expectedHash = sha256.convert([]).toString();

        final computed = await ModelIntegrity.computeChecksum(file.path);
        expect(computed, expectedHash);
      });

      test('reports progress during computation', () async {
        final file = File('${tempDir.path}/progress.bin');
        // Write a non-trivial amount of data.
        file.writeAsBytesSync(List.filled(1024 * 64, 42));

        final progressValues = <double>[];
        await ModelIntegrity.computeChecksum(
          file.path,
          onProgress: progressValues.add,
        );

        expect(progressValues, isNotEmpty);
        // Last reported progress should be 1.0 (fully read).
        expect(progressValues.last, closeTo(1.0, 0.001));
      });

      test('throws FileSystemException for missing file', () async {
        expect(
          () => ModelIntegrity.computeChecksum('${tempDir.path}/missing.bin'),
          throwsA(isA<FileSystemException>()),
        );
      });
    });

    group('verifyChecksum', () {
      test('returns true for matching checksum', () async {
        final file = File('${tempDir.path}/verify.bin');
        final content = 'GrammarLens test data';
        file.writeAsStringSync(content);

        final correctHash = sha256.convert(content.codeUnits).toString();
        final result =
            await ModelIntegrity.verifyChecksum(file.path, correctHash);
        expect(result, isTrue);
      });

      test('returns true regardless of case in expected hash', () async {
        final file = File('${tempDir.path}/case.bin');
        file.writeAsStringSync('data');

        final hash = sha256.convert('data'.codeUnits).toString();
        final upperHash = hash.toUpperCase();

        final result =
            await ModelIntegrity.verifyChecksum(file.path, upperHash);
        expect(result, isTrue);
      });

      test('returns false for mismatched checksum', () async {
        final file = File('${tempDir.path}/mismatch.bin');
        file.writeAsStringSync('actual content');

        final result = await ModelIntegrity.verifyChecksum(
          file.path,
          'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
        );
        expect(result, isFalse);
      });
    });
  });
}
