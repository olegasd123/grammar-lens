import 'package:grammar_engine/grammar_engine.dart';

/// Base class for external check events.
sealed class ExternalCheckEvent {
  const ExternalCheckEvent();
}

/// Global hotkey was pressed — begin reading text from the focused app.
class ExternalCheckTriggered extends ExternalCheckEvent {
  const ExternalCheckTriggered();
}

/// User accepted a single correction.
class ExternalCorrectionAccepted extends ExternalCheckEvent {
  final Correction correction;
  const ExternalCorrectionAccepted({required this.correction});
}

/// User dismissed a single correction.
class ExternalCorrectionDismissed extends ExternalCheckEvent {
  final Correction correction;
  const ExternalCorrectionDismissed({required this.correction});
}

/// User pressed "Apply All" — write corrected text back to the external app.
class ExternalCorrectionsDone extends ExternalCheckEvent {
  const ExternalCorrectionsDone();
}

/// User cancelled / closed the external check panel.
class ExternalCheckDismissed extends ExternalCheckEvent {
  const ExternalCheckDismissed();
}
