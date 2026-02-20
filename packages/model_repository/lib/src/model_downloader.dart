import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'package:model_repository/src/model_info.dart';

final _log = Logger('ModelDownloader');

/// Downloads GGUF model files with progress tracking and resume support.
class ModelDownloader {
  final http.Client _client;
  bool _isCancelled = false;

  ModelDownloader({http.Client? client}) : _client = client ?? http.Client();

  /// Download a model file to the specified path.
  ///
  /// Supports HTTP Range headers for resume capability.
  /// [onProgress] reports download progress from 0.0 to 1.0.
  ///
  /// Throws [ModelDownloadException] on failure.
  Future<File> download(
    ModelInfo model,
    String destinationPath, {
    void Function(double progress)? onProgress,
  }) async {
    _isCancelled = false;

    final file = File(destinationPath);
    final partialFile = File('$destinationPath.part');

    _log.info(
      'Starting download: ${model.displayName} '
      '(${model.fileSizeFormatted}) -> $destinationPath',
    );

    // Check for partial download (resume support)
    var bytesDownloaded = 0;
    if (partialFile.existsSync()) {
      bytesDownloaded = partialFile.lengthSync();
      _log.info('Resuming from $bytesDownloaded bytes');
    }

    try {
      final request = http.Request('GET', Uri.parse(model.downloadUrl));

      // Add Range header for resume
      if (bytesDownloaded > 0) {
        request.headers['Range'] = 'bytes=$bytesDownloaded-';
      }

      final response = await _client.send(request);

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw ModelDownloadException(
          'Download failed with status ${response.statusCode}',
        );
      }

      final totalBytes = model.fileSizeBytes;
      final sink = partialFile.openWrite(
        mode: bytesDownloaded > 0 ? FileMode.append : FileMode.write,
      );

      await for (final chunk in response.stream) {
        if (_isCancelled) {
          await sink.close();
          _log.info('Download cancelled');
          throw ModelDownloadCancelledException();
        }

        sink.add(chunk);
        bytesDownloaded += chunk.length;

        if (totalBytes > 0) {
          onProgress?.call(bytesDownloaded / totalBytes);
        }
      }

      await sink.close();

      // Rename .part to final file
      await partialFile.rename(destinationPath);

      _log.info('Download complete: ${model.displayName}');
      return file;
    } catch (e) {
      if (e is ModelDownloadCancelledException) rethrow;
      _log.severe('Download error: $e');
      throw ModelDownloadException('Download failed: $e');
    }
  }

  /// Cancel an in-progress download.
  void cancelDownload() {
    _isCancelled = true;
  }

  /// Clean up partial download files.
  Future<void> cleanupPartial(String destinationPath) async {
    final partialFile = File('$destinationPath.part');
    if (partialFile.existsSync()) {
      await partialFile.delete();
    }
  }

  /// Dispose the HTTP client.
  void dispose() {
    _client.close();
  }
}

/// Exception thrown when a model download fails.
class ModelDownloadException implements Exception {
  final String message;
  const ModelDownloadException(this.message);

  @override
  String toString() => 'ModelDownloadException: $message';
}

/// Exception thrown when a download is cancelled by the user.
class ModelDownloadCancelledException implements Exception {
  const ModelDownloadCancelledException();

  @override
  String toString() => 'ModelDownloadCancelledException';
}
