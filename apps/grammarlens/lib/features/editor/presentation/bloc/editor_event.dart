import 'package:grammar_engine/grammar_engine.dart';

/// Base class for editor events.
sealed class EditorEvent {
  const EditorEvent();
}

/// User typed or pasted text.
class TextChanged extends EditorEvent {
  final String text;
  const TextChanged({required this.text});
}

/// User changed the target language.
class LanguageChanged extends EditorEvent {
  final String languageCode;
  const LanguageChanged({required this.languageCode});
}

/// User accepted a correction.
class CorrectionAccepted extends EditorEvent {
  final Correction correction;
  const CorrectionAccepted({required this.correction});
}

/// User dismissed a correction.
class CorrectionDismissed extends EditorEvent {
  final Correction correction;
  const CorrectionDismissed({required this.correction});
}

/// User tapped "Accept All".
class AcceptAllCorrections extends EditorEvent {
  const AcceptAllCorrections();
}

/// Internal: trigger grammar analysis.
class AnalyzeRequested extends EditorEvent {
  final String text;
  const AnalyzeRequested({required this.text});
}

/// Auto-check mode changed in settings.
class AutoCheckModeChanged extends EditorEvent {
  final bool enabled;
  const AutoCheckModeChanged({required this.enabled});
}
