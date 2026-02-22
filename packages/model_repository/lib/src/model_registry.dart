import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:model_repository/src/model_info.dart';
import 'package:model_repository/src/model_storage.dart';
import 'package:path/path.dart' as p;

final _log = Logger('ModelRegistry');

/// Tracks installed models and active model selections.
///
/// Stores registry data as a JSON file in the models directory.
class ModelRegistry {
  final ModelStorage _storage;
  static const _registryFileName = 'registry.json';

  const ModelRegistry({ModelStorage storage = const ModelStorage()})
      : _storage = storage;

  /// Get the list of all installed (downloaded) models.
  Future<List<ModelInfo>> getInstalledModels() async {
    final data = await _readRegistry();
    final modelsJson = data['installed'] as List<dynamic>? ?? [];
    return modelsJson
        .map((m) => ModelInfo.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  /// Register a newly downloaded model.
  Future<void> registerModel(ModelInfo info) async {
    final data = await _readRegistry();
    final models = (data['installed'] as List<dynamic>? ?? []).toList()
      ..removeWhere(
        // Remove existing entry with same ID (update).
        (m) => (m as Map<String, dynamic>)['id'] == info.id,
      )
      ..add(info.toJson());

    data['installed'] = models;
    await _writeRegistry(data);

    _log.info('Registered model: ${info.id}');
  }

  /// Remove a model from the registry.
  Future<void> unregisterModel(String modelId) async {
    final data = await _readRegistry();
    final models = (data['installed'] as List<dynamic>? ?? []).toList()
      ..removeWhere(
        (m) => (m as Map<String, dynamic>)['id'] == modelId,
      );

    data['installed'] = models;

    // Also remove from active models if it was active
    final active = (data['active'] as Map<String, dynamic>? ?? {})
        .cast<String, String>()
      ..removeWhere((_, value) => value == modelId);
    data['active'] = active;

    await _writeRegistry(data);

    _log.info('Unregistered model: $modelId');
  }

  /// Get the active model for a language.
  Future<ModelInfo?> getActiveModel(String languageCode) async {
    final data = await _readRegistry();
    final active = data['active'] as Map<String, dynamic>? ?? {};
    final modelId = active[languageCode] as String?;
    if (modelId == null) return null;

    final installed = await getInstalledModels();
    try {
      return installed.firstWhere((m) => m.id == modelId);
    } catch (_) {
      return null;
    }
  }

  /// Set the active model for a language.
  Future<void> setActiveModel(String languageCode, String modelId) async {
    final data = await _readRegistry();
    final active =
        (data['active'] as Map<String, dynamic>? ?? {}).cast<String, dynamic>();
    active[languageCode] = modelId;
    data['active'] = active;
    await _writeRegistry(data);

    _log.info('Set active model for $languageCode: $modelId');
  }

  /// Get the file path of the registry JSON.
  Future<String> _getRegistryPath() async {
    final dir = await _storage.getModelsDirectory();
    return p.join(dir.path, _registryFileName);
  }

  Future<Map<String, dynamic>> _readRegistry() async {
    final path = await _getRegistryPath();
    final file = File(path);

    if (!file.existsSync()) return {};

    try {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      _log.warning('Failed to read registry: $e');
      return {};
    }
  }

  Future<void> _writeRegistry(Map<String, dynamic> data) async {
    final path = await _getRegistryPath();
    final file = File(path);
    final json = const JsonEncoder.withIndent('  ').convert(data);
    await file.writeAsString(json);
  }
}
