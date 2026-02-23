import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grammar_engine/grammar_engine.dart';

import 'package:grammarlens/features/editor/presentation/bloc/editor_event.dart';
import 'package:grammarlens/features/editor/presentation/bloc/editor_state.dart';

/// BLoC for the main text editor.
///
/// Manages the text analysis pipeline: debouncing user input,
/// running grammar analysis, and merging correction results.
class EditorBloc extends Bloc<EditorEvent, EditorState> {
  final GrammarAnalyzer? _analyzer;
  final LanguageDetector _languageDetector;
  final TextStatisticsCalculator _statisticsCalculator;

  Timer? _debounceTimer;

  EditorBloc({
    GrammarAnalyzer? analyzer,
    LanguageDetector languageDetector = const LanguageDetector(),
    TextStatisticsCalculator statisticsCalculator =
        const TextStatisticsCalculator(),
  })  : _analyzer = analyzer,
        _languageDetector = languageDetector,
        _statisticsCalculator = statisticsCalculator,
        super(const EditorState()) {
    on<TextChanged>(_onTextChanged);
    on<LanguageChanged>(_onLanguageChanged);
    on<CorrectionAccepted>(_onCorrectionAccepted);
    on<CorrectionDismissed>(_onCorrectionDismissed);
    on<AcceptAllCorrections>(_onAcceptAll);
    on<AnalyzeRequested>(_onAnalyzeRequested);
  }

  Future<void> _onTextChanged(
    TextChanged event,
    Emitter<EditorState> emit,
  ) async {
    // Update text immediately
    emit(state.copyWith(text: event.text));

    // Update statistics instantly (no model needed)
    final language = state.selectedLanguage != null
        ? SupportedLanguage.fromCode(state.selectedLanguage!)
        : _languageDetector.detect(event.text);

    final stats = _statisticsCalculator.calculate(event.text, language);
    emit(state.copyWith(statistics: stats));

    // Debounce grammar analysis (500ms)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      add(AnalyzeRequested(text: event.text));
    });
  }

  Future<void> _onAnalyzeRequested(
    AnalyzeRequested event,
    Emitter<EditorState> emit,
  ) async {
    if (_analyzer == null) {
      // No model loaded yet
      return;
    }

    if (event.text.trim().isEmpty) {
      emit(state.copyWith(
        status: AnalysisStatus.idle,
        corrections: [],
      ));
      return;
    }

    emit(state.copyWith(
      status: AnalysisStatus.analyzing,
      clearRawModelOutput: true,
    ));

    try {
      final language = state.selectedLanguage != null
          ? SupportedLanguage.fromCode(state.selectedLanguage!)
          : null;

      final result = await _analyzer.analyze(
        event.text,
        language: language,
      );

      // Only update if text hasn't changed during analysis
      if (state.text == event.text) {
        emit(state.copyWith(
          status: AnalysisStatus.complete,
          corrections: result.corrections,
          detectedLanguage: result.language.code,
          rawModelOutput: result.rawModelOutput,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AnalysisStatus.error,
        errorMessage: e.toString(),
        clearRawModelOutput: true,
      ));
    }
  }

  void _onLanguageChanged(
    LanguageChanged event,
    Emitter<EditorState> emit,
  ) {
    if (event.languageCode == 'auto') {
      emit(state.copyWith(clearSelectedLanguage: true));
    } else {
      emit(state.copyWith(selectedLanguage: event.languageCode));
    }

    // Re-analyze with the new language
    if (state.text.trim().isNotEmpty) {
      add(AnalyzeRequested(text: state.text));
    }
  }

  void _onCorrectionAccepted(
    CorrectionAccepted event,
    Emitter<EditorState> emit,
  ) {
    final corrections = state.corrections.toList();
    final index = corrections.indexWhere(
      (c) =>
          c.startOffset == event.correction.startOffset &&
          c.originalText == event.correction.originalText,
    );

    if (index >= 0) {
      corrections[index] = corrections[index].copyWith(isAccepted: true);

      // Apply the correction to the text
      final text = state.text;
      final newText = text.replaceRange(
        event.correction.startOffset,
        event.correction.endOffset,
        event.correction.correctedText,
      );

      // Adjust offsets of subsequent corrections
      final lengthDiff = event.correction.correctedText.length -
          event.correction.originalText.length;

      final adjustedCorrections = corrections.map((c) {
        if (c.startOffset > event.correction.startOffset && !c.isAccepted) {
          return c.copyWith(
            startOffset: c.startOffset + lengthDiff,
            endOffset: c.endOffset + lengthDiff,
          );
        }
        return c;
      }).toList();

      emit(state.copyWith(
        text: newText,
        corrections: adjustedCorrections,
      ));
    }
  }

  void _onCorrectionDismissed(
    CorrectionDismissed event,
    Emitter<EditorState> emit,
  ) {
    final corrections = state.corrections.toList();
    corrections.removeWhere(
      (c) =>
          c.startOffset == event.correction.startOffset &&
          c.originalText == event.correction.originalText,
    );

    emit(state.copyWith(corrections: corrections));
  }

  void _onAcceptAll(
    AcceptAllCorrections event,
    Emitter<EditorState> emit,
  ) {
    // Apply all corrections from end to start (to preserve offsets)
    var text = state.text;
    final sorted = state.corrections.toList()
      ..sort((a, b) => b.startOffset.compareTo(a.startOffset));

    for (final correction in sorted) {
      if (!correction.isAccepted && !correction.isDismissed) {
        text = text.replaceRange(
          correction.startOffset,
          correction.endOffset,
          correction.correctedText,
        );
      }
    }

    emit(state.copyWith(
      text: text,
      corrections: [],
      status: AnalysisStatus.idle,
    ));
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
