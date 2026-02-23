import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_engine/grammar_engine.dart';
import 'package:mocktail/mocktail.dart';
import 'package:platform_integration/platform_integration.dart';

import 'package:grammarlens/features/external_check/presentation/bloc/external_check_bloc.dart';
import 'package:grammarlens/features/external_check/presentation/bloc/external_check_event.dart';
import 'package:grammarlens/features/external_check/presentation/bloc/external_check_state.dart';

class MockAccessibilityService extends Mock implements AccessibilityService {}

class MockGrammarAnalyzer extends Mock implements GrammarAnalyzer {}

void main() {
  late MockAccessibilityService mockAccessibility;
  late MockGrammarAnalyzer mockAnalyzer;

  setUp(() {
    mockAccessibility = MockAccessibilityService();
    mockAnalyzer = MockGrammarAnalyzer();
  });

  setUpAll(() {
    registerFallbackValue(SupportedLanguage.english);
  });

  group('ExternalCheckBloc', () {
    group('initial state', () {
      test('has initial status and no data', () {
        final bloc = ExternalCheckBloc(
          accessibilityService: mockAccessibility,
        );
        expect(bloc.state.status, ExternalCheckStatus.initial);
        expect(bloc.state.sourceAppName, isNull);
        expect(bloc.state.originalText, isNull);
        expect(bloc.state.corrections, isEmpty);
        bloc.close();
      });
    });

    group('ExternalCheckTriggered', () {
      blocTest<ExternalCheckBloc, ExternalCheckState>(
        'emits noPermission when accessibility not granted',
        setUp: () {
          when(() => mockAccessibility.hasPermission())
              .thenAnswer((_) async => false);
          when(() => mockAccessibility.requestPermission())
              .thenAnswer((_) async => false);
        },
        build: () => ExternalCheckBloc(
          accessibilityService: mockAccessibility,
          analyzer: mockAnalyzer,
        ),
        act: (bloc) => bloc.add(const ExternalCheckTriggered()),
        expect: () => [
          isA<ExternalCheckState>().having(
            (s) => s.status,
            'status',
            ExternalCheckStatus.noPermission,
          ),
        ],
        verify: (_) {
          verify(() => mockAccessibility.hasPermission()).called(1);
          verify(() => mockAccessibility.requestPermission()).called(1);
        },
      );

      blocTest<ExternalCheckBloc, ExternalCheckState>(
        'emits error when no text found in focused element',
        setUp: () {
          when(() => mockAccessibility.hasPermission())
              .thenAnswer((_) async => true);
          when(() => mockAccessibility.getFocusedAppName())
              .thenAnswer((_) async => 'TextEdit');
          when(() => mockAccessibility.readFocusedElement())
              .thenAnswer((_) async => null);
        },
        build: () => ExternalCheckBloc(
          accessibilityService: mockAccessibility,
          analyzer: mockAnalyzer,
        ),
        act: (bloc) => bloc.add(const ExternalCheckTriggered()),
        expect: () => [
          isA<ExternalCheckState>().having(
            (s) => s.status,
            'status',
            ExternalCheckStatus.loading,
          ),
          isA<ExternalCheckState>()
              .having(
                (s) => s.status,
                'status',
                ExternalCheckStatus.error,
              )
              .having(
                (s) => s.sourceAppName,
                'sourceAppName',
                'TextEdit',
              )
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains('No text found'),
              ),
        ],
      );

      blocTest<ExternalCheckBloc, ExternalCheckState>(
        'emits error when no analyzer is loaded',
        setUp: () {
          when(() => mockAccessibility.hasPermission())
              .thenAnswer((_) async => true);
          when(() => mockAccessibility.getFocusedAppName())
              .thenAnswer((_) async => 'Notes');
          when(() => mockAccessibility.readFocusedElement())
              .thenAnswer((_) async => 'Some text to check');
        },
        build: () => ExternalCheckBloc(
          accessibilityService: mockAccessibility,
          // No analyzer provided
        ),
        act: (bloc) => bloc.add(const ExternalCheckTriggered()),
        expect: () => [
          isA<ExternalCheckState>().having(
            (s) => s.status,
            'status',
            ExternalCheckStatus.loading,
          ),
          isA<ExternalCheckState>()
              .having(
                (s) => s.status,
                'status',
                ExternalCheckStatus.error,
              )
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains('No grammar model'),
              ),
        ],
      );

      blocTest<ExternalCheckBloc, ExternalCheckState>(
        'happy path: reads text, analyzes, emits ready with corrections',
        setUp: () {
          when(() => mockAccessibility.hasPermission())
              .thenAnswer((_) async => true);
          when(() => mockAccessibility.getFocusedAppName())
              .thenAnswer((_) async => 'Safari');
          when(() => mockAccessibility.readFocusedElement())
              .thenAnswer((_) async => 'He dont likes the cake.');
          when(() => mockAnalyzer.analyze(
                any(),
                language: any(named: 'language'),
              )).thenAnswer((_) async => AnalysisResult(
                corrections: [
                  Correction(
                    startOffset: 3,
                    endOffset: 7,
                    originalText: 'dont',
                    correctedText: "doesn't",
                    type: CorrectionType.grammar,
                    explanation: 'Subject-verb agreement',
                  ),
                  Correction(
                    startOffset: 8,
                    endOffset: 13,
                    originalText: 'likes',
                    correctedText: 'like',
                    type: CorrectionType.grammar,
                    explanation: 'Verb form after does',
                  ),
                ],
                language: SupportedLanguage.english,
                analysisTimeMs: 120,
              ));
        },
        build: () => ExternalCheckBloc(
          accessibilityService: mockAccessibility,
          analyzer: mockAnalyzer,
        ),
        act: (bloc) => bloc.add(const ExternalCheckTriggered()),
        expect: () => [
          isA<ExternalCheckState>().having(
            (s) => s.status,
            'status',
            ExternalCheckStatus.loading,
          ),
          isA<ExternalCheckState>()
              .having(
                (s) => s.status,
                'status',
                ExternalCheckStatus.ready,
              )
              .having(
                (s) => s.sourceAppName,
                'sourceAppName',
                'Safari',
              )
              .having(
                (s) => s.originalText,
                'originalText',
                'He dont likes the cake.',
              )
              .having(
                (s) => s.corrections,
                'corrections',
                hasLength(2),
              ),
        ],
      );

      blocTest<ExternalCheckBloc, ExternalCheckState>(
        'emits complete when text has no issues',
        setUp: () {
          when(() => mockAccessibility.hasPermission())
              .thenAnswer((_) async => true);
          when(() => mockAccessibility.getFocusedAppName())
              .thenAnswer((_) async => 'Notes');
          when(() => mockAccessibility.readFocusedElement())
              .thenAnswer((_) async => 'Perfect text.');
          when(() => mockAnalyzer.analyze(
                any(),
                language: any(named: 'language'),
              )).thenAnswer((_) async => AnalysisResult(
                corrections: [],
                language: SupportedLanguage.english,
                analysisTimeMs: 50,
              ));
        },
        build: () => ExternalCheckBloc(
          accessibilityService: mockAccessibility,
          analyzer: mockAnalyzer,
        ),
        act: (bloc) => bloc.add(const ExternalCheckTriggered()),
        expect: () => [
          isA<ExternalCheckState>().having(
            (s) => s.status,
            'status',
            ExternalCheckStatus.loading,
          ),
          isA<ExternalCheckState>()
              .having(
                (s) => s.status,
                'status',
                ExternalCheckStatus.complete,
              )
              .having(
                (s) => s.sourceAppName,
                'sourceAppName',
                'Notes',
              ),
        ],
      );

      blocTest<ExternalCheckBloc, ExternalCheckState>(
        'emits error when analysis throws',
        setUp: () {
          when(() => mockAccessibility.hasPermission())
              .thenAnswer((_) async => true);
          when(() => mockAccessibility.getFocusedAppName())
              .thenAnswer((_) async => 'TextEdit');
          when(() => mockAccessibility.readFocusedElement())
              .thenAnswer((_) async => 'Some text');
          when(() => mockAnalyzer.analyze(
                any(),
                language: any(named: 'language'),
              )).thenThrow(Exception('Model crashed'));
        },
        build: () => ExternalCheckBloc(
          accessibilityService: mockAccessibility,
          analyzer: mockAnalyzer,
        ),
        act: (bloc) => bloc.add(const ExternalCheckTriggered()),
        expect: () => [
          isA<ExternalCheckState>().having(
            (s) => s.status,
            'status',
            ExternalCheckStatus.loading,
          ),
          isA<ExternalCheckState>()
              .having(
                (s) => s.status,
                'status',
                ExternalCheckStatus.error,
              )
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains('Model crashed'),
              ),
        ],
      );
    });

    group('ExternalCorrectionAccepted', () {
      final correction = Correction(
        startOffset: 0,
        endOffset: 4,
        originalText: 'Helo',
        correctedText: 'Hello',
        type: CorrectionType.spelling,
        explanation: 'Misspelled',
      );

      blocTest<ExternalCheckBloc, ExternalCheckState>(
        'applies correction to corrected text',
        build: () => ExternalCheckBloc(
          accessibilityService: mockAccessibility,
          analyzer: mockAnalyzer,
        ),
        seed: () => ExternalCheckState(
          status: ExternalCheckStatus.ready,
          sourceAppName: 'TextEdit',
          originalText: 'Helo world',
          correctedText: 'Helo world',
          corrections: [correction],
        ),
        act: (bloc) =>
            bloc.add(ExternalCorrectionAccepted(correction: correction)),
        verify: (bloc) {
          expect(bloc.state.correctedText, 'Hello world');
          expect(bloc.state.corrections.first.isAccepted, isTrue);
        },
      );

      blocTest<ExternalCheckBloc, ExternalCheckState>(
        'adjusts offsets of subsequent corrections',
        build: () => ExternalCheckBloc(
          accessibilityService: mockAccessibility,
          analyzer: mockAnalyzer,
        ),
        seed: () => ExternalCheckState(
          status: ExternalCheckStatus.ready,
          sourceAppName: 'TextEdit',
          originalText: 'Helo wrold',
          correctedText: 'Helo wrold',
          corrections: [
            correction,
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
        act: (bloc) =>
            bloc.add(ExternalCorrectionAccepted(correction: correction)),
        verify: (bloc) {
          // "Helo" → "Hello" adds 1 char, so second correction shifts +1
          final secondCorrection =
              bloc.state.corrections.where((c) => !c.isAccepted).first;
          expect(secondCorrection.startOffset, 6);
          expect(secondCorrection.endOffset, 11);
        },
      );

      blocTest<ExternalCheckBloc, ExternalCheckState>(
        'falls back to text search when correction offsets are stale',
        build: () => ExternalCheckBloc(
          accessibilityService: mockAccessibility,
          analyzer: mockAnalyzer,
        ),
        seed: () => ExternalCheckState(
          status: ExternalCheckStatus.ready,
          sourceAppName: 'TextEdit',
          originalText: 'Helo world',
          correctedText: 'Helo world',
          corrections: [
            Correction(
              startOffset: 999,
              endOffset: 1003,
              originalText: 'Helo',
              correctedText: 'Hello',
              type: CorrectionType.spelling,
              explanation: 'Misspelled',
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          ExternalCorrectionAccepted(
            correction: Correction(
              startOffset: 999,
              endOffset: 1003,
              originalText: 'Helo',
              correctedText: 'Hello',
              type: CorrectionType.spelling,
              explanation: 'Misspelled',
            ),
          ),
        ),
        verify: (bloc) {
          expect(bloc.state.correctedText, 'Hello world');
        },
      );

      blocTest<ExternalCheckBloc, ExternalCheckState>(
        'skips invalid correction when range and text lookup are both invalid',
        build: () => ExternalCheckBloc(
          accessibilityService: mockAccessibility,
          analyzer: mockAnalyzer,
        ),
        seed: () => ExternalCheckState(
          status: ExternalCheckStatus.ready,
          sourceAppName: 'TextEdit',
          originalText: 'Helo world',
          correctedText: 'Helo world',
          corrections: [
            Correction(
              startOffset: 999,
              endOffset: 1003,
              originalText: 'missing-fragment',
              correctedText: 'fixed',
              type: CorrectionType.spelling,
              explanation: 'Misspelled',
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          ExternalCorrectionAccepted(
            correction: Correction(
              startOffset: 999,
              endOffset: 1003,
              originalText: 'missing-fragment',
              correctedText: 'fixed',
              type: CorrectionType.spelling,
              explanation: 'Misspelled',
            ),
          ),
        ),
        verify: (bloc) {
          expect(bloc.state.correctedText, 'Helo world');
          expect(bloc.state.corrections, isEmpty);
        },
      );
    });

    group('ExternalCorrectionDismissed', () {
      final correction = Correction(
        startOffset: 0,
        endOffset: 4,
        originalText: 'test',
        correctedText: 'Test',
        type: CorrectionType.grammar,
        explanation: 'Capitalize',
      );

      blocTest<ExternalCheckBloc, ExternalCheckState>(
        'removes correction from list',
        build: () => ExternalCheckBloc(
          accessibilityService: mockAccessibility,
          analyzer: mockAnalyzer,
        ),
        seed: () => ExternalCheckState(
          status: ExternalCheckStatus.ready,
          sourceAppName: 'TextEdit',
          originalText: 'test sentence',
          correctedText: 'test sentence',
          corrections: [correction],
        ),
        act: (bloc) =>
            bloc.add(ExternalCorrectionDismissed(correction: correction)),
        verify: (bloc) {
          expect(bloc.state.corrections, isEmpty);
        },
      );
    });

    group('ExternalCorrectionsDone', () {
      blocTest<ExternalCheckBloc, ExternalCheckState>(
        'applies all remaining corrections and writes back',
        setUp: () {
          when(() => mockAccessibility.writeFocusedElement(any()))
              .thenAnswer((_) async => true);
        },
        build: () => ExternalCheckBloc(
          accessibilityService: mockAccessibility,
          analyzer: mockAnalyzer,
        ),
        seed: () => ExternalCheckState(
          status: ExternalCheckStatus.ready,
          sourceAppName: 'Notes',
          originalText: 'Helo wrold',
          correctedText: 'Helo wrold',
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
        act: (bloc) => bloc.add(const ExternalCorrectionsDone()),
        expect: () => [
          // writingBack
          isA<ExternalCheckState>().having(
            (s) => s.status,
            'status',
            ExternalCheckStatus.writingBack,
          ),
          // complete
          isA<ExternalCheckState>()
              .having(
                (s) => s.status,
                'status',
                ExternalCheckStatus.complete,
              )
              .having(
                (s) => s.corrections,
                'corrections',
                isEmpty,
              ),
        ],
        verify: (_) {
          final captured =
              verify(() => mockAccessibility.writeFocusedElement(captureAny()))
                  .captured;
          expect(captured.last, 'Hello world');
        },
      );

      blocTest<ExternalCheckBloc, ExternalCheckState>(
        'emits error when write-back fails',
        setUp: () {
          when(() => mockAccessibility.writeFocusedElement(any()))
              .thenAnswer((_) async => false);
        },
        build: () => ExternalCheckBloc(
          accessibilityService: mockAccessibility,
          analyzer: mockAnalyzer,
        ),
        seed: () => ExternalCheckState(
          status: ExternalCheckStatus.ready,
          sourceAppName: 'TextEdit',
          originalText: 'some text',
          correctedText: 'some text',
          corrections: [
            Correction(
              startOffset: 0,
              endOffset: 4,
              originalText: 'some',
              correctedText: 'Some',
              type: CorrectionType.grammar,
              explanation: 'Capitalize',
            ),
          ],
        ),
        act: (bloc) => bloc.add(const ExternalCorrectionsDone()),
        expect: () => [
          isA<ExternalCheckState>().having(
            (s) => s.status,
            'status',
            ExternalCheckStatus.writingBack,
          ),
          isA<ExternalCheckState>()
              .having(
                (s) => s.status,
                'status',
                ExternalCheckStatus.error,
              )
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains('Could not write text back'),
              ),
        ],
      );

      blocTest<ExternalCheckBloc, ExternalCheckState>(
        'emits error when write-back throws',
        setUp: () {
          when(() => mockAccessibility.writeFocusedElement(any()))
              .thenThrow(Exception('Channel error'));
        },
        build: () => ExternalCheckBloc(
          accessibilityService: mockAccessibility,
          analyzer: mockAnalyzer,
        ),
        seed: () => ExternalCheckState(
          status: ExternalCheckStatus.ready,
          sourceAppName: 'TextEdit',
          originalText: 'text',
          correctedText: 'text',
          corrections: [
            Correction(
              startOffset: 0,
              endOffset: 4,
              originalText: 'text',
              correctedText: 'Text',
              type: CorrectionType.grammar,
              explanation: 'Capitalize',
            ),
          ],
        ),
        act: (bloc) => bloc.add(const ExternalCorrectionsDone()),
        expect: () => [
          isA<ExternalCheckState>().having(
            (s) => s.status,
            'status',
            ExternalCheckStatus.writingBack,
          ),
          isA<ExternalCheckState>()
              .having(
                (s) => s.status,
                'status',
                ExternalCheckStatus.error,
              )
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains('Channel error'),
              ),
        ],
      );

      blocTest<ExternalCheckBloc, ExternalCheckState>(
        'skips invalid ranges and still applies valid corrections before write-back',
        setUp: () {
          when(() => mockAccessibility.writeFocusedElement(any()))
              .thenAnswer((_) async => true);
        },
        build: () => ExternalCheckBloc(
          accessibilityService: mockAccessibility,
          analyzer: mockAnalyzer,
        ),
        seed: () => ExternalCheckState(
          status: ExternalCheckStatus.ready,
          sourceAppName: 'Notes',
          originalText: 'Helo wrold',
          correctedText: 'Helo wrold',
          corrections: [
            Correction(
              startOffset: 999,
              endOffset: 1003,
              originalText: 'missing',
              correctedText: 'fixed',
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
        act: (bloc) => bloc.add(const ExternalCorrectionsDone()),
        verify: (_) {
          final captured =
              verify(() => mockAccessibility.writeFocusedElement(captureAny()))
                  .captured;
          expect(captured.last, 'Helo world');
        },
      );
    });

    group('ExternalCheckDismissed', () {
      blocTest<ExternalCheckBloc, ExternalCheckState>(
        'resets state to initial',
        build: () => ExternalCheckBloc(
          accessibilityService: mockAccessibility,
          analyzer: mockAnalyzer,
        ),
        seed: () => const ExternalCheckState(
          status: ExternalCheckStatus.ready,
          sourceAppName: 'Safari',
          originalText: 'some text',
        ),
        act: (bloc) => bloc.add(const ExternalCheckDismissed()),
        expect: () => [
          isA<ExternalCheckState>().having(
            (s) => s.status,
            'status',
            ExternalCheckStatus.initial,
          ),
        ],
      );
    });

    group('ExternalCheckState', () {
      test('activeCorrectionsCount excludes accepted/dismissed', () {
        final state = ExternalCheckState(
          status: ExternalCheckStatus.ready,
          corrections: [
            Correction(
              startOffset: 0,
              endOffset: 4,
              originalText: 'test',
              correctedText: 'Test',
              type: CorrectionType.grammar,
              explanation: 'Cap',
            ),
            Correction(
              startOffset: 5,
              endOffset: 9,
              originalText: 'word',
              correctedText: 'Word',
              type: CorrectionType.grammar,
              explanation: 'Cap',
              isAccepted: true,
            ),
            Correction(
              startOffset: 10,
              endOffset: 14,
              originalText: 'more',
              correctedText: 'More',
              type: CorrectionType.grammar,
              explanation: 'Cap',
              isDismissed: true,
            ),
          ],
        );
        expect(state.activeCorrectionsCount, 1);
      });

      test('hasCorrections is true when corrections exist', () {
        final state = ExternalCheckState(
          corrections: [
            Correction(
              startOffset: 0,
              endOffset: 4,
              originalText: 'test',
              correctedText: 'Test',
              type: CorrectionType.grammar,
              explanation: 'Cap',
            ),
          ],
        );
        expect(state.hasCorrections, isTrue);
      });

      test('hasCorrections is false when empty', () {
        const state = ExternalCheckState();
        expect(state.hasCorrections, isFalse);
      });

      test('copyWith preserves values when not overridden', () {
        final state = ExternalCheckState(
          status: ExternalCheckStatus.ready,
          sourceAppName: 'Safari',
          originalText: 'text',
          correctedText: 'Text',
          corrections: [
            Correction(
              startOffset: 0,
              endOffset: 4,
              originalText: 'test',
              correctedText: 'Test',
              type: CorrectionType.grammar,
              explanation: 'Cap',
            ),
          ],
          errorMessage: null,
        );

        final copied = state.copyWith(status: ExternalCheckStatus.complete);
        expect(copied.status, ExternalCheckStatus.complete);
        expect(copied.sourceAppName, 'Safari');
        expect(copied.originalText, 'text');
        expect(copied.correctedText, 'Text');
        expect(copied.corrections, hasLength(1));
      });
    });
  });
}
