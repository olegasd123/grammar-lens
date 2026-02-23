import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:model_repository/model_repository.dart';

class MockClient extends Mock implements http.Client {}

void main() {
  late MockClient mockClient;
  late ModelManifestFetcher fetcher;
  final bundledManifest =
      ModelManifest.fromJson(ModelManifest.bundledManifestJson);

  final testManifestJson = {
    'version': 2,
    'models': [
      {
        'id': 'test-model',
        'displayName': 'Test Model',
        'languages': ['en'],
        'quantization': 'Q4_K_M',
        'fileSizeBytes': 2300000000,
        'sha256': 'abc123',
        'downloadUrl': 'https://example.com/test-model.gguf',
        'minAppVersion': '0.1.0',
        'contextLength': 4096,
      },
    ],
  };

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    mockClient = MockClient();
    fetcher = ModelManifestFetcher(
      client: mockClient,
      manifestUrl: 'https://example.com/manifest.json',
    );
  });

  group('ModelManifestFetcher', () {
    test('fetches and parses remote manifest', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
        (_) async => http.Response(
          jsonEncode(testManifestJson),
          200,
          headers: {'etag': '"v2"'},
        ),
      );

      final manifest = await fetcher.fetchManifest();

      expect(manifest.version, 2);
      expect(manifest.models, hasLength(1));
      expect(manifest.models.first.id, 'test-model');
    });

    test('returns cached manifest on 304 Not Modified', () async {
      // First fetch — populate cache
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
        (_) async => http.Response(
          jsonEncode(testManifestJson),
          200,
          headers: {'etag': '"v2"'},
        ),
      );

      await fetcher.fetchManifest();

      // Second fetch — 304
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('', 304));

      final manifest = await fetcher.fetchManifest();

      expect(manifest.version, 2);
      expect(manifest.models.first.id, 'test-model');
    });

    test('falls back to bundled manifest on HTTP error', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('Not Found', 404));

      final manifest = await fetcher.fetchManifest();

      // Should be the bundled manifest
      expect(manifest.version, bundledManifest.version);
      expect(
        manifest.models.map((m) => m.id).toSet(),
        bundledManifest.models.map((m) => m.id).toSet(),
      );
    });

    test('falls back to bundled manifest on network error', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenThrow(Exception('No internet'));

      final manifest = await fetcher.fetchManifest();

      // Should be the bundled manifest
      expect(manifest.version, bundledManifest.version);
      expect(
        manifest.models.map((m) => m.id).toSet(),
        bundledManifest.models.map((m) => m.id).toSet(),
      );
    });

    test('falls back to cached manifest if available on error', () async {
      // First fetch — populate cache
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
        (_) async => http.Response(
          jsonEncode(testManifestJson),
          200,
          headers: {'etag': '"v2"'},
        ),
      );

      await fetcher.fetchManifest();

      // Second fetch — network error
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenThrow(Exception('Connection lost'));

      final manifest = await fetcher.fetchManifest();

      // Should be the cached manifest, not bundled
      expect(manifest.version, 2);
      expect(manifest.models, hasLength(1));
    });

    test('sends If-None-Match header after first fetch', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
        (_) async => http.Response(
          jsonEncode(testManifestJson),
          200,
          headers: {'etag': '"v2"'},
        ),
      );

      await fetcher.fetchManifest();

      // Second fetch — verify header is sent
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('', 304));

      await fetcher.fetchManifest();

      final captured = verify(
        () => mockClient.get(any(), headers: captureAny(named: 'headers')),
      ).captured;

      // The second call should include If-None-Match
      final secondHeaders = captured.last as Map<String, String>;
      expect(secondHeaders['If-None-Match'], '"v2"');
    });

    test('falls back to bundled manifest on invalid JSON', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('not json', 200));

      final manifest = await fetcher.fetchManifest();

      // Should fall back to bundled
      expect(manifest.version, bundledManifest.version);
      expect(
        manifest.models.map((m) => m.id).toSet(),
        bundledManifest.models.map((m) => m.id).toSet(),
      );
    });

    test('defaultManifestUrl points to GitHub Releases', () {
      expect(
        ModelManifestFetcher.defaultManifestUrl,
        contains('github.com/grammarlens/grammarlens/releases'),
      );
    });
  });
}
