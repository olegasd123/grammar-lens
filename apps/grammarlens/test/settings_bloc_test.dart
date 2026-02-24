import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grammarlens/features/settings/data/preferences_repository.dart';
import 'package:grammarlens/features/settings/domain/app_preferences.dart';
import 'package:grammarlens/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:grammarlens/features/settings/presentation/bloc/settings_event.dart';
import 'package:grammarlens/features/settings/presentation/bloc/settings_state.dart';

class MockPreferencesRepository extends Mock implements PreferencesRepository {}

void main() {
  late MockPreferencesRepository repository;

  setUp(() {
    repository = MockPreferencesRepository();
    when(() => repository.load()).thenAnswer(
      (_) async => const AppPreferences(),
    );
    when(() => repository.saveAiTopP(any())).thenAnswer((_) async {});
    when(() => repository.saveAiTopK(any())).thenAnswer((_) async {});
    when(() => repository.saveAiRepeatPenalty(any())).thenAnswer((_) async {});
  });

  group('SettingsBloc', () {
    blocTest<SettingsBloc, SettingsState>(
      'loads preferences from repository',
      build: () => SettingsBloc(repository: repository),
      act: (bloc) => bloc.add(const SettingsLoaded()),
      expect: () => [
        isA<SettingsState>().having((s) => s.isLoaded, 'isLoaded', isTrue),
      ],
      verify: (_) {
        verify(() => repository.load()).called(1);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'clamps and saves ai top-p',
      build: () => SettingsBloc(repository: repository),
      seed: () => const SettingsState(
        preferences: AppPreferences(themeMode: ThemeMode.light),
      ),
      act: (bloc) => bloc.add(const AiTopPChanged(topP: 1.5)),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.preferences.aiTopP,
          'aiTopP',
          1.0,
        ),
      ],
      verify: (_) {
        verify(() => repository.saveAiTopP(1.0)).called(1);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'clamps and saves ai top-k',
      build: () => SettingsBloc(repository: repository),
      act: (bloc) => bloc.add(const AiTopKChanged(topK: 999)),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.preferences.aiTopK,
          'aiTopK',
          200,
        ),
      ],
      verify: (_) {
        verify(() => repository.saveAiTopK(200)).called(1);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'clamps and saves ai repeat penalty',
      build: () => SettingsBloc(repository: repository),
      act: (bloc) => bloc.add(
        const AiRepeatPenaltyChanged(repeatPenalty: 0.3),
      ),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.preferences.aiRepeatPenalty,
          'aiRepeatPenalty',
          1.0,
        ),
      ],
      verify: (_) {
        verify(() => repository.saveAiRepeatPenalty(1.0)).called(1);
      },
    );
  });
}
