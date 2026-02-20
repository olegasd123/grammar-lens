import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final _log = Logger('ModelStorage');

/// Manages filesystem storage for downloaded GGUF models.
class ModelStorage {
  static const _modelsDirName = 'grammarlens_models';

  const ModelStorage();

  /// Get the platform-appropriate models directory.
  ///
  /// Creates the directory if it doesn't exist.
  Future<Directory> getModelsDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final modelsDir = Directory(p.join(appDir.path, _modelsDirName));

    if (!modelsDir.existsSync()) {
      await modelsDir.create(recursive: true);
      _log.info('Created models directory: ${modelsDir.path}');
    }

    return modelsDir;
  }

  /// Get the expected file path for a model.
  Future<String> getModelPath(String modelId) async {
    final dir = await getModelsDirectory();
    return p.join(dir.path, '$modelId.gguf');
  }

  /// Check if a model file exists on disk.
  Future<bool> isModelDownloaded(String modelId) async {
    final path = await getModelPath(modelId);
    return File(path).existsSync();
  }

  /// Delete a model file from disk.
  Future<void> deleteModel(String modelId) async {
    final path = await getModelPath(modelId);
    final file = File(path);

    if (file.existsSync()) {
      await file.delete();
      _log.info('Deleted model: $modelId');
    }

    // Also clean up partial download
    final partialFile = File('$path.part');
    if (partialFile.existsSync()) {
      await partialFile.delete();
    }
  }

  /// Get total storage used by all downloaded models (in bytes).
  Future<int> getStorageUsage() async {
    final dir = await getModelsDirectory();
    if (!dir.existsSync()) return 0;

    var totalBytes = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        totalBytes += await entity.length();
      }
    }
    return totalBytes;
  }

  /// Get formatted storage usage string (e.g., "4.5 GB").
  Future<String> getStorageUsageFormatted() async {
    final bytes = await getStorageUsage();
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  /// List all .gguf files in the models directory.
  Future<List<String>> listDownloadedModelFiles() async {
    final dir = await getModelsDirectory();
    if (!dir.existsSync()) return [];

    final files = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.gguf')) {
        files.add(p.basenameWithoutExtension(entity.path));
      }
    }
    return files;
  }
}
