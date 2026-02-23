import 'dart:math' as math;

import 'package:grammar_engine/src/models/language.dart';

/// Lightweight trigram-based language detector.
///
/// Uses character trigram frequency profiles to identify the language
/// of input text. Fast (<1ms) and requires no model — works offline
/// with embedded frequency tables.
class LanguageDetector {
  const LanguageDetector();

  /// Detect the language of the given text.
  ///
  /// Returns [SupportedLanguage.english] as default for very short texts
  /// or when detection is uncertain.
  SupportedLanguage detect(String text) {
    final scriptLanguage = _detectByScript(text);
    if (scriptLanguage != null) {
      return scriptLanguage;
    }

    if (text.trim().length < 20) {
      return SupportedLanguage.english; // Too short for reliable detection
    }

    final textTrigrams = _extractTrigrams(text.toLowerCase());
    if (textTrigrams.isEmpty) return SupportedLanguage.english;

    var bestScore = double.infinity;
    var bestLang = SupportedLanguage.english;

    for (final lang in SupportedLanguage.values) {
      final profile = _profiles[lang];
      if (profile == null) continue;

      final distance = _cosineDissimilarity(textTrigrams, profile);
      if (distance < bestScore) {
        bestScore = distance;
        bestLang = lang;
      }
    }

    return bestLang;
  }

  /// Detect language with confidence score.
  ///
  /// Returns a map of language to confidence (0.0-1.0).
  Map<SupportedLanguage, double> detectWithConfidence(String text) {
    final scriptLanguage = _detectByScript(text);
    if (scriptLanguage != null) {
      return {
        for (final lang in SupportedLanguage.values)
          lang: lang == scriptLanguage ? 1.0 : 0.0,
      };
    }

    if (text.trim().length < 20) {
      return {
        for (final lang in SupportedLanguage.values)
          lang: lang == SupportedLanguage.english ? 1.0 : 0.0,
      };
    }

    final textTrigrams = _extractTrigrams(text.toLowerCase());
    final scores = <SupportedLanguage, double>{};

    for (final lang in SupportedLanguage.values) {
      final profile = _profiles[lang];
      if (profile == null) continue;
      scores[lang] = 1.0 - _cosineDissimilarity(textTrigrams, profile);
    }

    // Normalize to 0-1 range
    final total = scores.values.fold(0.0, (sum, v) => sum + v);
    if (total > 0) {
      for (final lang in scores.keys) {
        scores[lang] = scores[lang]! / total;
      }
    }

    return scores;
  }

  static SupportedLanguage? _detectByScript(String text) {
    if (_hangulPattern.hasMatch(text)) {
      return SupportedLanguage.korean;
    }
    if (_hiraganaKatakanaPattern.hasMatch(text)) {
      return SupportedLanguage.japanese;
    }
    if (_hanPattern.hasMatch(text)) {
      // Prefer Traditional Chinese if common traditional-only characters exist.
      return _traditionalHanHintPattern.hasMatch(text)
          ? SupportedLanguage.chineseTraditional
          : SupportedLanguage.chineseSimplified;
    }
    if (_devanagariPattern.hasMatch(text)) {
      return SupportedLanguage.hindi;
    }
    if (_hebrewPattern.hasMatch(text)) {
      return SupportedLanguage.hebrew;
    }
    if (_greekPattern.hasMatch(text)) {
      return SupportedLanguage.greek;
    }
    if (_arabicScriptPattern.hasMatch(text)) {
      // Persian uses additional letters not used in Arabic.
      if (_persianHintPattern.hasMatch(text)) {
        return SupportedLanguage.persian;
      }
      return SupportedLanguage.arabic;
    }
    if (_cyrillicPattern.hasMatch(text)) {
      // Ukrainian has letters that Russian does not use.
      if (_ukrainianHintPattern.hasMatch(text)) {
        return SupportedLanguage.ukrainian;
      }
      return SupportedLanguage.russian;
    }

    return null;
  }

  static final _cyrillicPattern = RegExp(r'[\u0400-\u04FF]');
  static final _ukrainianHintPattern = RegExp(r'[іїєґІЇЄҐ]');
  static final _arabicScriptPattern = RegExp(r'[\u0600-\u06FF]');
  static final _persianHintPattern = RegExp(r'[پچژگککی]');
  static final _hebrewPattern = RegExp(r'[\u0590-\u05FF]');
  static final _greekPattern = RegExp(r'[\u0370-\u03FF]');
  static final _devanagariPattern = RegExp(r'[\u0900-\u097F]');
  static final _hanPattern = RegExp(r'[\u4E00-\u9FFF]');
  static final _traditionalHanHintPattern = RegExp(r'[體國龍廣學書會話門風語]');
  static final _hiraganaKatakanaPattern = RegExp(r'[\u3040-\u30FF]');
  static final _hangulPattern = RegExp(r'[\uAC00-\uD7AF]');

  /// Extract trigram frequency map from text.
  static Map<String, double> _extractTrigrams(String text) {
    final trigrams = <String, int>{};
    final cleaned =
        text.replaceAll(RegExp(r'[^a-záéíóúñüàèìòùâêîôûäëïöüçãõ\s]'), '');

    for (var i = 0; i < cleaned.length - 2; i++) {
      final trigram = cleaned.substring(i, i + 3);
      trigrams[trigram] = (trigrams[trigram] ?? 0) + 1;
    }

    // Normalize to frequencies
    final total = trigrams.values.fold(0, (sum, v) => sum + v);
    return {
      for (final entry in trigrams.entries) entry.key: entry.value / total,
    };
  }

  /// Cosine dissimilarity between two trigram frequency maps.
  static double _cosineDissimilarity(
    Map<String, double> a,
    Map<String, double> b,
  ) {
    final allKeys = {...a.keys, ...b.keys};

    var dotProduct = 0.0;
    var normA = 0.0;
    var normB = 0.0;

    for (final key in allKeys) {
      final va = a[key] ?? 0.0;
      final vb = b[key] ?? 0.0;
      dotProduct += va * vb;
      normA += va * va;
      normB += vb * vb;
    }

    final denominator = math.sqrt(normA) * math.sqrt(normB);
    if (denominator == 0) return 1.0;

    return 1.0 - (dotProduct / denominator);
  }

  /// Trigram frequency profiles for each supported language.
  ///
  /// These are the top-50 most common trigrams for each language,
  /// normalized to frequencies. In production, these would be
  /// generated from a large corpus (e.g., Wikipedia dumps).
  static const _profiles = <SupportedLanguage, Map<String, double>>{
    SupportedLanguage.english: {
      'the': 0.035,
      ' th': 0.033,
      'he ': 0.025,
      'and': 0.018,
      'nd ': 0.016,
      'ion': 0.015,
      'tio': 0.014,
      ' an': 0.014,
      'ing': 0.013,
      'ng ': 0.012,
      'ent': 0.011,
      ' in': 0.011,
      'ati': 0.010,
      'on ': 0.010,
      'er ': 0.009,
      'hat': 0.009,
      'is ': 0.009,
      'for': 0.008,
      'his': 0.008,
      'all': 0.008,
      'tha': 0.008,
      'ter': 0.007,
      ' to': 0.007,
      'ore': 0.007,
      ' of': 0.007,
      'of ': 0.007,
      'in ': 0.007,
      ' fo': 0.006,
      'nt ': 0.006,
      'ver': 0.006,
      ' co': 0.006,
      'ere': 0.006,
    },
    SupportedLanguage.spanish: {
      'de ': 0.028,
      ' de': 0.025,
      ' la': 0.020,
      'la ': 0.018,
      'os ': 0.016,
      'en ': 0.015,
      ' en': 0.014,
      'ión': 0.014,
      'ció': 0.013,
      'que': 0.012,
      'ue ': 0.011,
      ' el': 0.011,
      'el ': 0.010,
      ' qu': 0.010,
      'es ': 0.010,
      'as ': 0.009,
      'aci': 0.009,
      'con': 0.008,
      ' co': 0.008,
      'nte': 0.008,
      ' lo': 0.008,
      'los': 0.007,
      'las': 0.007,
      'do ': 0.007,
      'al ': 0.007,
      ' pa': 0.007,
      'par': 0.006,
      'ara': 0.006,
      'est': 0.006,
      'sta': 0.006,
      ' un': 0.006,
      'una': 0.006,
    },
    SupportedLanguage.french: {
      'es ': 0.022,
      ' de': 0.020,
      'de ': 0.018,
      ' le': 0.016,
      'ent': 0.015,
      'le ': 0.014,
      'on ': 0.013,
      ' la': 0.013,
      'la ': 0.012,
      'ion': 0.012,
      'tio': 0.011,
      'ati': 0.010,
      ' et': 0.010,
      'et ': 0.009,
      ' en': 0.009,
      'en ': 0.009,
      'les': 0.009,
      ' un': 0.008,
      'ons': 0.008,
      'des': 0.008,
      ' co': 0.008,
      'nt ': 0.008,
      ' pa': 0.007,
      'par': 0.007,
      ' qu': 0.007,
      'que': 0.007,
      'ue ': 0.007,
      're ': 0.007,
      'une': 0.006,
      'ne ': 0.006,
      'men': 0.006,
      ' da': 0.006,
    },
    SupportedLanguage.german: {
      'en ': 0.028,
      'er ': 0.022,
      'die': 0.018,
      ' di': 0.017,
      'ie ': 0.016,
      'der': 0.015,
      'und': 0.014,
      ' un': 0.014,
      'nd ': 0.013,
      'ein': 0.012,
      'ich': 0.011,
      'den': 0.010,
      'che': 0.010,
      ' de': 0.010,
      'sch': 0.009,
      ' ei': 0.009,
      'in ': 0.009,
      'ine': 0.009,
      'eit': 0.008,
      'gen': 0.008,
      'ung': 0.008,
      'das': 0.008,
      ' da': 0.007,
      ' in': 0.007,
      'ber': 0.007,
      'ter': 0.007,
      'nte': 0.007,
      'nen': 0.007,
      'ach': 0.006,
      'auf': 0.006,
      ' au': 0.006,
      'hen': 0.006,
    },
    SupportedLanguage.portuguese: {
      'de ': 0.025,
      ' de': 0.022,
      'os ': 0.018,
      ' qu': 0.016,
      'que': 0.015,
      'ue ': 0.014,
      'ão ': 0.013,
      'ção': 0.012,
      ' o ': 0.012,
      ' co': 0.011,
      'as ': 0.011,
      'do ': 0.010,
      'ent': 0.010,
      'con': 0.009,
      ' pa': 0.009,
      'par': 0.009,
      'ara': 0.009,
      'com': 0.008,
      'est': 0.008,
      ' es': 0.008,
      ' do': 0.008,
      ' em': 0.008,
      'em ': 0.007,
      ' se': 0.007,
      ' um': 0.007,
      'uma': 0.007,
      'nte': 0.007,
      ' da': 0.007,
      ' no': 0.007,
      'no ': 0.007,
      'da ': 0.006,
      'dos': 0.006,
      'mos': 0.006,
      'ado': 0.006,
      'men': 0.006,
      'osa': 0.005,
      'oso': 0.005,
      ' na': 0.005,
    },
  };
}
