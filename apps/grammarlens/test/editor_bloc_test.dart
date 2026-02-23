import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_engine/grammar_engine.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grammarlens/features/editor/presentation/bloc/editor_bloc.dart';
import 'package:grammarlens/features/editor/presentation/bloc/editor_event.dart';
import 'package:grammarlens/features/editor/presentation/bloc/editor_state.dart';

class MockGrammarAnalyzer extends Mock implements GrammarAnalyzer {}

void main() {
  late MockGrammarAnalyzer mockAnalyzer;

  setUp(() {
    mockAnalyzer = MockGrammarAnalyzer();
  });

  setUpAll(() {
    registerFallbackValue(SupportedLanguage.english);
  });

  group('EditorBloc', () {
    group('initial state', () {
      test('has empty text and idle status', () {
        final bloc = EditorBloc();
        expect(bloc.state.text, isEmpty);
        expect(bloc.state.status, AnalysisStatus.idle);
        expect(bloc.state.corrections, isEmpty);
        expect(bloc.state.selectedLanguage, isNull);
        expect(bloc.state.detectedLanguage, isNull);
        bloc.close();
      });
    });

    group('TextChanged', () {
      blocTest<EditorBloc, EditorState>(
        'updates text in state',
        build: EditorBloc.new,
        act: (bloc) => bloc.add(const TextChanged(text: 'Hello world')),
        verify: (bloc) {
          expect(bloc.state.text, 'Hello world');
        },
      );

      blocTest<EditorBloc, EditorState>(
        'computes statistics immediately',
        build: EditorBloc.new,
        act: (bloc) =>
            bloc.add(const TextChanged(text: 'Hello world. This is a test.')),
        verify: (bloc) {
          expect(bloc.state.statistics, isNotNull);
          expect(bloc.state.statistics!.wordCount, greaterThan(0));
        },
      );
    });

    group('LanguageChanged', () {
      blocTest<EditorBloc, EditorState>(
        'updates selected language',
        build: EditorBloc.new,
        act: (bloc) => bloc.add(const LanguageChanged(languageCode: 'fr')),
        verify: (bloc) {
          expect(bloc.state.selectedLanguage, 'fr');
          expect(bloc.state.effectiveLanguage, 'fr');
        },
      );

      blocTest<EditorBloc, EditorState>(
        'sets selectedLanguage to null for auto-detect',
        build: EditorBloc.new,
        seed: () => const EditorState(selectedLanguage: 'fr'),
        act: (bloc) => bloc.add(const LanguageChanged(languageCode: 'auto')),
        verify: (bloc) {
          expect(bloc.state.selectedLanguage, isNull);
        },
      );
    });

    group('AnalyzeRequested', () {
      blocTest<EditorBloc, EditorState>(
        'is no-op without analyzer',
        build: EditorBloc.new,
        seed: () => const EditorState(text: 'Some text'),
        act: (bloc) => bloc.add(const AnalyzeRequested(text: 'Some text')),
        expect: () => <EditorState>[],
      );

      blocTest<EditorBloc, EditorState>(
        'emits idle with empty corrections for blank text',
        build: () => EditorBloc(analyzer: mockAnalyzer),
        seed: () => const EditorState(text: ''),
        act: (bloc) => bloc.add(const AnalyzeRequested(text: '   ')),
        expect: () => [
          isA<EditorState>()
              .having((s) => s.status, 'status', AnalysisStatus.idle)
              .having((s) => s.corrections, 'corrections', isEmpty),
        ],
      );

      blocTest<EditorBloc, EditorState>(
        'runs analysis and emits corrections on success',
        setUp: () {
          when(() => mockAnalyzer.analyze(
                any(),
                language: any(named: 'language'),
              )).thenAnswer((_) async => AnalysisResult(
                corrections: [
                  Correction(
                    startOffset: 0,
                    endOffset: 5,
                    originalText: 'Helo',
                    correctedText: 'Hello',
                    type: CorrectionType.spelling,
                    explanation: 'Misspelled word',
                  ),
                ],
                language: SupportedLanguage.english,
                rawModelOutput: '<corrections><item>...</item></corrections>',
              ));
        },
        build: () => EditorBloc(analyzer: mockAnalyzer),
        seed: () => const EditorState(text: 'Helo world'),
        act: (bloc) => bloc.add(const AnalyzeRequested(text: 'Helo world')),
        expect: () => [
          // First: analyzing status
          isA<EditorState>().having(
            (s) => s.status,
            'status',
            AnalysisStatus.analyzing,
          ),
          // Then: complete with corrections
          isA<EditorState>()
              .having((s) => s.status, 'status', AnalysisStatus.complete)
              .having((s) => s.corrections, 'corrections', hasLength(1))
              .having((s) => s.detectedLanguage, 'detectedLanguage', 'en')
              .having((s) => s.rawModelOutput, 'rawModelOutput', isNotNull),
        ],
      );

      blocTest<EditorBloc, EditorState>(
        'emits error status when analyzer throws',
        setUp: () {
          when(() => mockAnalyzer.analyze(
                any(),
                language: any(named: 'language'),
              )).thenThrow(Exception('Inference failed'));
        },
        build: () => EditorBloc(analyzer: mockAnalyzer),
        seed: () => const EditorState(text: 'Test text'),
        act: (bloc) => bloc.add(const AnalyzeRequested(text: 'Test text')),
        expect: () => [
          isA<EditorState>().having(
            (s) => s.status,
            'status',
            AnalysisStatus.analyzing,
          ),
          isA<EditorState>()
              .having((s) => s.status, 'status', AnalysisStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    group('CorrectionAccepted', () {
      final correction = Correction(
        startOffset: 0,
        endOffset: 4,
        originalText: 'Helo',
        correctedText: 'Hello',
        type: CorrectionType.spelling,
        explanation: 'Misspelled',
      );

      blocTest<EditorBloc, EditorState>(
        'applies correction to text',
        build: EditorBloc.new,
        seed: () => EditorState(
          text: 'Helo world',
          corrections: [correction],
        ),
        act: (bloc) => bloc.add(CorrectionAccepted(correction: correction)),
        verify: (bloc) {
          expect(bloc.state.text, 'Hello world');
        },
      );

      blocTest<EditorBloc, EditorState>(
        'marks correction as accepted',
        build: EditorBloc.new,
        seed: () => EditorState(
          text: 'Helo world',
          corrections: [correction],
        ),
        act: (bloc) => bloc.add(CorrectionAccepted(correction: correction)),
        verify: (bloc) {
          final accepted =
              bloc.state.corrections.where((c) => c.isAccepted).toList();
          expect(accepted, hasLength(1));
        },
      );

      blocTest<EditorBloc, EditorState>(
        'adjusts offsets of subsequent corrections',
        build: EditorBloc.new,
        seed: () => EditorState(
          text: 'Helo wrold',
          corrections: [
            correction, // offset 0-4, "Helo" → "Hello" (+1 char)
            Correction(
              startOffset: 5,
              endOffset: 10,
              originalText: 'wrold',
              correctedText: 'world',
              type: CorrectionType.spelling,
              explanation: 'Misspelled',
            ),
          ],
        ),
        act: (bloc) => bloc.add(CorrectionAccepted(correction: correction)),
        verify: (bloc) {
          // Second correction should have shifted by +1
          final secondCorrection =
              bloc.state.corrections.where((c) => !c.isAccepted).first;
          expect(secondCorrection.startOffset, 6);
          expect(secondCorrection.endOffset, 11);
        },
      );
    });

    group('CorrectionDismissed', () {
      final correction = Correction(
        startOffset: 0,
        endOffset: 4,
        originalText: 'test',
        correctedText: 'Test',
        type: CorrectionType.grammar,
        explanation: 'Capitalize',
      );

      blocTest<EditorBloc, EditorState>(
        'removes correction from list',
        build: EditorBloc.new,
        seed: () => EditorState(
          text: 'test sentence',
          corrections: [correction],
        ),
        act: (bloc) => bloc.add(CorrectionDismissed(correction: correction)),
        verify: (bloc) {
          expect(bloc.state.corrections, isEmpty);
        },
      );

      blocTest<EditorBloc, EditorState>(
        'does not modify text',
        build: EditorBloc.new,
        seed: () => EditorState(
          text: 'test sentence',
          corrections: [correction],
        ),
        act: (bloc) => bloc.add(CorrectionDismissed(correction: correction)),
        verify: (bloc) {
          expect(bloc.state.text, 'test sentence');
        },
      );
    });

    group('AcceptAllCorrections', () {
      blocTest<EditorBloc, EditorState>(
        'applies all active corrections and clears list',
        build: EditorBloc.new,
        seed: () => EditorState(
          text: 'Helo wrold',
          corrections: [
            Correction(
              startOffset: 0,
              endOffset: 4,
              originalText: 'Helo',
              correctedText: 'Hello',
              type: CorrectionType.spelling,
              explanation: 'Misspelled',
            ),
            Correction(
              startOffset: 5,
              endOffset: 10,
              originalText: 'wrold',
              correctedText: 'world',
              type: CorrectionType.spelling,
              explanation: 'Misspelled',
            ),
          ],
        ),
        act: (bloc) => bloc.add(const AcceptAllCorrections()),
        verify: (bloc) {
          expect(bloc.state.text, 'Hello world');
          expect(bloc.state.corrections, isEmpty);
          expect(bloc.state.status, AnalysisStatus.idle);
        },
      );
    });

    group('EditorState', () {
      test('activeCorrectionsCount excludes accepted/dismissed', () {
        final state = EditorState(
          text: 'test',
          corrections: [
            Correction(
              startOffset: 0,
              endOffset: 4,
              originalText: 'test',
              correctedText: 'Test',
              type: CorrectionType.grammar,
              explanation: 'Capitalize',
            ),
            Correction(
              startOffset: 0,
              endOffset: 4,
              originalText: 'test',
              correctedText: 'Test',
              type: CorrectionType.grammar,
              explanation: 'Capitalize',
              isAccepted: true,
            ),
            Correction(
              startOffset: 0,
              endOffset: 4,
              originalText: 'test',
              correctedText: 'Test',
              type: CorrectionType.grammar,
              explanation: 'Capitalize',
              isDismissed: true,
            ),
          ],
        );
        expect(state.activeCorrectionsCount, 1);
      });

      test('effectiveLanguage prefers selectedLanguage', () {
        const state = EditorState(
          selectedLanguage: 'fr',
          detectedLanguage: 'en',
        );
        expect(state.effectiveLanguage, 'fr');
      });

      test('effectiveLanguage falls back to detectedLanguage', () {
        const state = EditorState(detectedLanguage: 'es');
        expect(state.effectiveLanguage, 'es');
      });

      test('effectiveLanguage defaults to en', () {
        const state = EditorState();
        expect(state.effectiveLanguage, 'en');
      });
    });
  });
}
