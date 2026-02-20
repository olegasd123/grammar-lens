import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';

final _log = Logger('ModelIntegrity');

/// Verifies integrity of downloaded model files using SHA-256 checksums.
class ModelIntegrity {
  const ModelIntegrity._();

  /// Verify that a file matches its expected SHA-256 checksum.
  ///
  /// Returns true if the file's checksum matches [expectedSha256].
  /// Reports progress via [onProgress] (0.0 to 1.0) for large files.
  static Future<bool> verifyChecksum(
    String filePath,
    String expectedSha256, {
    void Function(double progress)? onProgress,
  }) async {
    _log.info('Verifying checksum for: $filePath');

    final computed = await computeChecksum(
      filePath,
      onProgress: onProgress,
    );

    final matches = computed == expectedSha256.toLowerCase();

    if (matches) {
      _log.info('Checksum verified: $filePath');
    } else {
      _log.warning(
        'Checksum mismatch for $filePath: '
        'expected=$expectedSha256, computed=$computed',
      );
    }

    return matches;
  }

  /// Compute the SHA-256 checksum of a file.
  ///
  /// Reads the file in chunks to handle large model files (2+ GB)
  /// without loading the entire file into memory.
  static Future<String> computeChecksum(
    String filePath, {
    void Function(double progress)? onProgress,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('File not found', filePath);
    }

    final fileLength = await file.length();
    var bytesRead = 0;

    final output = AccumulatorSink<Digest>();
    final input = sha256.startChunkedConversion(output);

    final stream = file.openRead();
    await for (final chunk in stream) {
      input.add(chunk);
      bytesRead += chunk.length;

      if (fileLength > 0) {
        onProgress?.call(bytesRead / fileLength);
      }
    }

    input.close();
    final digest = output.events.single;

    return digest.toString();
  }
}

/// Accumulator sink for collecting chunked conversion results.
class AccumulatorSink<T> implements Sink<T> {
  final List<T> events = [];

  @override
  void add(T event) => events.add(event);

  @override
  void close() {}
}
