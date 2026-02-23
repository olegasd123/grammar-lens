import 'package:grammar_engine/src/models/language.dart';

/// Readability scores for a text document.
class ReadabilityScores {
  /// Flesch-Kincaid Grade Level (English).
  /// Grade 8 = 8th grade reading level. Lower is easier.
  final double? fleschKincaidGrade;

  /// Flesch Reading Ease score (English).
  /// 100 = very easy, 0 = very hard. 60-70 is standard.
  final double? fleschReadingEase;

  /// Simple label: "Easy", "Standard", "Advanced", "Complex".
  final String readabilityLabel;

  const ReadabilityScores({
    this.fleschKincaidGrade,
    this.fleschReadingEase,
    required this.readabilityLabel,
  });
}

/// Computes readability scores for text.
class ReadabilityScorer {
  const ReadabilityScorer._();

  /// Calculate readability scores for the given text.
  static ReadabilityScores score(
    String text,
    SupportedLanguage language,
  ) {
    final words = _splitWords(text);
    final sentences = _countSentences(text);
    final syllables = _countTotalSyllables(words, language);

    if (words.isEmpty || sentences == 0) {
      return const ReadabilityScores(readabilityLabel: 'N/A');
    }

    final wordsPerSentence = words.length / sentences;
    final syllablesPerWord = syllables / words.length;

    switch (language) {
      case SupportedLanguage.english:
        return _scoreEnglish(wordsPerSentence, syllablesPerWord);
      default:
        // Use adapted Flesch formula for non-English languages.
        return _scoreGeneric(wordsPerSentence, syllablesPerWord);
    }
  }

  static ReadabilityScores _scoreEnglish(
    double wordsPerSentence,
    double syllablesPerWord,
  ) {
    // Flesch Reading Ease
    final ease = 206.835 - 1.015 * wordsPerSentence - 84.6 * syllablesPerWord;

    // Flesch-Kincaid Grade Level
    final grade = 0.39 * wordsPerSentence + 11.8 * syllablesPerWord - 15.59;

    return ReadabilityScores(
      fleschReadingEase: ease.clamp(0, 100),
      fleschKincaidGrade: grade.clamp(0, 20),
      readabilityLabel: _labelFromEase(ease),
    );
  }

  static ReadabilityScores _scoreGeneric(
    double wordsPerSentence,
    double syllablesPerWord,
  ) {
    // Simplified Flesch adaptation for non-English languages
    final ease = 206.835 - 1.015 * wordsPerSentence - 84.6 * syllablesPerWord;

    return ReadabilityScores(
      fleschReadingEase: ease.clamp(0, 100),
      readabilityLabel: _labelFromEase(ease),
    );
  }

  static String _labelFromEase(double ease) {
    if (ease >= 80) return 'Easy';
    if (ease >= 60) return 'Standard';
    if (ease >= 40) return 'Advanced';
    return 'Complex';
  }

  static List<String> _splitWords(String text) {
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  }

  static int _countSentences(String text) {
    return RegExp('[.!?]+').allMatches(text).length.clamp(1, text.length);
  }

  static int _countTotalSyllables(
    List<String> words,
    SupportedLanguage language,
  ) {
    return words.fold(0, (sum, word) => sum + _countSyllables(word));
  }

  /// Estimate syllable count for a single word.
  ///
  /// Uses a simple vowel-group heuristic. Not perfectly accurate
  /// but sufficient for readability scoring.
  static int _countSyllables(String word) {
    word = word
        .toLowerCase()
        .replaceAll(RegExp('[^a-záéíóúàèìòùâêîôûäëïöüñç]'), '');
    if (word.isEmpty) return 0;
    if (word.length <= 3) return 1;

    // Count vowel groups
    final vowelGroups = RegExp('[aeiouyáéíóúàèìòùâêîôûäëïöü]+');
    var count = vowelGroups.allMatches(word).length;

    // Adjust for common patterns
    if (word.endsWith('e') && !word.endsWith('le')) {
      count--;
    }

    return count.clamp(1, word.length);
  }
}
