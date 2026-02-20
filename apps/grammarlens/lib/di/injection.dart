import 'package:get_it/get_it.dart';

import 'package:grammar_engine/grammar_engine.dart';
import 'package:model_repository/model_repository.dart';
import 'package:platform_integration/platform_integration.dart';

/// Global service locator instance.
final getIt = GetIt.instance;

/// Register all dependencies.
///
/// Called once at app startup before runApp().
Future<void> configureDependencies() async {
  // ── Core Services ──────────────────────────────────────────────────────

  // Model storage & registry
  getIt.registerLazySingleton<ModelStorage>(() => const ModelStorage());
  getIt.registerLazySingleton<ModelRegistry>(
    () => ModelRegistry(storage: getIt<ModelStorage>()),
  );
  getIt.registerLazySingleton<ModelDownloader>(() => ModelDownloader());

  // ── Grammar Engine ─────────────────────────────────────────────────────

  getIt.registerLazySingleton<LanguageDetector>(
    () => const LanguageDetector(),
  );
  getIt.registerLazySingleton<TextStatisticsCalculator>(
    () => const TextStatisticsCalculator(),
  );

  // GrammarAnalyzer will be registered after a model is loaded,
  // since it needs the inference callback.
  // See EditorBloc for how this is wired up.

  // ── Platform Services ──────────────────────────────────────────────────

  getIt.registerLazySingleton<ClipboardService>(
    () => const ClipboardService(),
  );
  getIt.registerLazySingleton<GlobalHotkeyService>(
    () => GlobalHotkeyService(),
  );
}
