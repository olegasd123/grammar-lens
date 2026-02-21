import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';

import 'package:grammar_engine/grammar_engine.dart';
import 'package:platform_integration/platform_integration.dart';

import 'package:grammarlens/features/external_check/presentation/bloc/external_check_event.dart';
import 'package:grammarlens/features/external_check/presentation/bloc/external_check_state.dart';

final _log = Logger('ExternalCheckBloc');

/// BLoC that orchestrates the external text-checking flow:
///
/// 1. Global hotkey fires → [ExternalCheckTriggered]
/// 2. Check accessibility permission
/// 3. Read text from the focused element in the external app
/// 4. Run grammar analysis
/// 5. Present corrections for review
/// 6. Write corrected text back to the external app
class ExternalCheckBloc
    extends Bloc<ExternalCheckEvent, ExternalCheckState> {
  final AccessibilityService _accessibilityService;
  final GrammarAnalyzer? _analyzer;

  ExternalCheckBloc({
    required AccessibilityService accessibilityService,
    GrammarAnalyzer? analyzer,
  })  : _accessibilityService = accessibilityService,
        _analyzer = analyzer,
        super(const ExternalCheckState()) {
    on<ExternalCheckTriggered>(_onTriggered);
    on<ExternalCorrectionAccepted>(_onCorrectionAccepted);
    on<ExternalCorrectionDismissed>(_onCorrectionDismissed);
    on<ExternalCorrectionsDone>(_onCorrectionsDone);
    on<ExternalCheckDismissed>(_onDismissed);
  }

  // ── Triggered ─────────────────────────────────────────────────────────

  Future<void> _onTriggered(
    ExternalCheckTriggered event,
    Emitter<ExternalCheckState> emit,
  ) async {
    _log.info('External check triggered');

    // Step 1: Check permission
    final hasPermission = await _accessibilityService.hasPermission();
    if (!hasPermission) {
      _log.info('Accessibility permission not granted, requesting…');
      emit(const ExternalCheckState(
        status: ExternalCheckStatus.noPermission,
      ));
      await _accessibilityService.requestPermission();
      return;
    }

    emit(const ExternalCheckState(status: ExternalCheckStatus.loading));

    try {
      // Step 2: Get the source app name
      final appName = await _accessibilityService.getFocusedAppName();
      _log.info('Source app: $appName');

      // Step 3: Read text from the focused element
      final text = await _accessibilityService.readFocusedElement();

      if (text == null || text.trim().isEmpty) {
        _log.info('No text found in focused element');
        emit(ExternalCheckState(
          status: ExternalCheckStatus.error,
          sourceAppName: appName,
          errorMessage:
              'No text found in the focused element of ${appName ?? 'the active app'}.',
        ));
        return;
      }

      _log.info('Read ${text.length} chars from $appName');

      // Step 4: Run grammar analysis
      if (_analyzer == null) {
        emit(ExternalCheckState(
          status: ExternalCheckStatus.error,
          sourceAppName: appName,
          originalText: text,
          errorMessage:
              'No grammar model is loaded. Please load a model first.',
        ));
        return;
      }

      final result = await _analyzer.analyze(text);

      _log.info(
        'Analysis found ${result.corrections.length} corrections '
        'in ${result.analysisTimeMs}ms',
      );

      if (result.corrections.isEmpty) {
        emit(ExternalCheckState(
          status: ExternalCheckStatus.complete,
          sourceAppName: appName,
          originalText: text,
          correctedText: text,
        ));
        return;
      }

      emit(ExternalCheckState(
        status: ExternalCheckStatus.ready,
        sourceAppName: appName,
        originalText: text,
        correctedText: text,
        corrections: result.corrections,
      ));
    } catch (e, st) {
      _log.severe('External check failed', e, st);
      emit(ExternalCheckState(
        status: ExternalCheckStatus.error,
        errorMessage: 'External check failed: $e',
      ));
    }
  }

  // ── Accept a single correction ────────────────────────────────────────

  void _onCorrectionAccepted(
    ExternalCorrectionAccepted event,
    Emitter<ExternalCheckState> emit,
  ) {
    final corrections = state.corrections.toList();
    final index = corrections.indexWhere(
      (c) =>
          c.startOffset == event.correction.startOffset &&
          c.originalText == event.correction.originalText,
    );

    if (index < 0) return;

    corrections[index] = corrections[index].copyWith(isAccepted: true);

    // Apply this correction to the corrected text
    var text = state.correctedText ?? state.originalText ?? '';
    text = text.replaceRange(
      event.correction.startOffset,
      event.correction.endOffset,
      event.correction.correctedText,
    );

    // Adjust offsets of subsequent corrections
    final lengthDiff = event.correction.correctedText.length -
        event.correction.originalText.length;

    final adjusted = corrections.map((c) {
      if (c.startOffset > event.correction.startOffset && !c.isAccepted) {
        return c.copyWith(
          startOffset: c.startOffset + lengthDiff,
          endOffset: c.endOffset + lengthDiff,
        );
      }
      return c;
    }).toList();

    emit(state.copyWith(
      correctedText: text,
      corrections: adjusted,
    ));
  }

  // ── Dismiss a single correction ───────────────────────────────────────

  void _onCorrectionDismissed(
    ExternalCorrectionDismissed event,
    Emitter<ExternalCheckState> emit,
  ) {
    final corrections = state.corrections.toList();
    corrections.removeWhere(
      (c) =>
          c.startOffset == event.correction.startOffset &&
          c.originalText == event.correction.originalText,
    );

    emit(state.copyWith(corrections: corrections));
  }

  // ── Apply all and write back ──────────────────────────────────────────

  Future<void> _onCorrectionsDone(
    ExternalCorrectionsDone event,
    Emitter<ExternalCheckState> emit,
  ) async {
    emit(state.copyWith(status: ExternalCheckStatus.writingBack));

    // Apply all remaining (non-accepted, non-dismissed) corrections
    var text = state.correctedText ?? state.originalText ?? '';
    final remaining = state.corrections
        .where((c) => !c.isAccepted && !c.isDismissed)
        .toList()
      ..sort((a, b) => b.startOffset.compareTo(a.startOffset));

    for (final correction in remaining) {
      text = text.replaceRange(
        correction.startOffset,
        correction.endOffset,
        correction.correctedText,
      );
    }

    try {
      final success =
          await _accessibilityService.writeFocusedElement(text);

      if (success) {
        _log.info('Wrote corrected text back to source app');
        emit(state.copyWith(
          status: ExternalCheckStatus.complete,
          correctedText: text,
          corrections: [],
        ));
      } else {
        _log.warning('Failed to write text back');
        emit(state.copyWith(
          status: ExternalCheckStatus.error,
          errorMessage:
              'Could not write text back to ${state.sourceAppName ?? 'the app'}. '
              'The focused element may no longer be writable.',
        ));
      }
    } catch (e, st) {
      _log.severe('Write-back failed', e, st);
      emit(state.copyWith(
        status: ExternalCheckStatus.error,
        errorMessage: 'Write-back failed: $e',
      ));
    }
  }

  // ── Dismissed ─────────────────────────────────────────────────────────

  void _onDismissed(
    ExternalCheckDismissed event,
    Emitter<ExternalCheckState> emit,
  ) {
    emit(const ExternalCheckState());
  }
}
