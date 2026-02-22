import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'package:model_repository/src/model_manifest.dart';

final _log = Logger('ModelManifestFetcher');

/// Fetches the latest model manifest from GitHub Releases.
///
/// Falls back to the bundled manifest on network failure.
/// Supports ETag-based caching to avoid redundant downloads.
class ModelManifestFetcher {
  final http.Client _client;
  final String _manifestUrl;

  /// Cached ETag from the last successful fetch.
  String? _lastEtag;

  /// Cached manifest from the last successful fetch.
  ModelManifest? _cachedManifest;

  /// Default manifest URL pointing to the latest release's manifest.json.
  static const defaultManifestUrl =
      'https://github.com/grammarlens/grammarlens/releases/latest/download/manifest.json';

  ModelManifestFetcher({
    http.Client? client,
    String manifestUrl = defaultManifestUrl,
  })  : _client = client ?? http.Client(),
        _manifestUrl = manifestUrl;

  /// Fetch the latest manifest from the remote URL.
  ///
  /// Returns the remote manifest if available, or falls back to the
  /// bundled manifest on any failure (network error, parse error, etc.).
  Future<ModelManifest> fetchManifest() async {
    try {
      final headers = <String, String>{};
      if (_lastEtag != null) {
        headers['If-None-Match'] = _lastEtag!;
      }

      _log.info('Fetching manifest from $_manifestUrl');

      final response = await _client
          .get(Uri.parse(_manifestUrl), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 304 && _cachedManifest != null) {
        _log.info('Manifest not modified (304), using cache');
        return _cachedManifest!;
      }

      if (response.statusCode != 200) {
        _log.warning(
          'Manifest fetch failed with status ${response.statusCode}',
        );
        return _fallback();
      }

      final etag = response.headers['etag'];
      if (etag != null) {
        _lastEtag = etag;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final manifest = ModelManifest.fromJson(json);

      _cachedManifest = manifest;
      _log.info(
        'Fetched manifest v${manifest.version} '
        'with ${manifest.models.length} models',
      );

      return manifest;
    } catch (e) {
      _log.warning('Failed to fetch remote manifest: $e');
      return _fallback();
    }
  }

  ModelManifest _fallback() {
    if (_cachedManifest != null) {
      _log.info('Using previously cached manifest');
      return _cachedManifest!;
    }
    _log.info('Using bundled manifest');
    return ModelManifest.fromJson(ModelManifest.bundledManifestJson);
  }

  /// Dispose the HTTP client.
  void dispose() {
    _client.close();
  }
}
