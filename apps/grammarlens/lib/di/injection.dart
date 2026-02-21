import 'package:get_it/get_it.dart';

import 'package:grammar_engine/grammar_engine.dart';
import 'package:model_repository/model_repository.dart';
import 'package:platform_integration/platform_integration.dart';

import 'package:grammarlens/features/model_manager/presentation/bloc/model_bloc.dart';

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

  // ── Model Manager ──────────────────────────────────────────────────────

  getIt.registerLazySingleton<ModelBloc>(
    () => ModelBloc(
      registry: getIt<ModelRegistry>(),
      storage: getIt<ModelStorage>(),
      downloader: getIt<ModelDownloader>(),
    ),
  );

  // ── Platform Services ──────────────────────────────────────────────────

  getIt.registerLazySingleton<ClipboardService>(
    () => const ClipboardService(),
  );
  getIt.registerLazySingleton<GlobalHotkeyService>(
    () => GlobalHotkeyService(),
  );
}
