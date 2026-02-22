import 'package:grammar_engine/src/analyzer/sentence_splitter.dart';
import 'package:grammar_engine/src/models/correction.dart';
import 'package:grammar_engine/src/models/correction_type.dart';

/// Parses XML correction output from the grammar model.
///
/// Handles both complete and partial (streaming) XML output.
/// Uses a lightweight regex-based approach instead of a full XML parser
/// for performance and to handle malformed model output gracefully.
class CorrectionParser {
  const CorrectionParser._();

  /// Parse a complete XML corrections block.
  ///
  /// [xml] - The raw model output containing `<corrections>...</corrections>`.
  /// [sentences] - The original sentences, used to map offsets to the full text.
  /// [baseOffset] - Character offset of the first sentence in the full document.
  static List<Correction> parse(
    String xml,
    List<SentenceSpan> sentences, {
    int baseOffset = 0,
  }) {
    final corrections = <Correction>[];
    final itemPattern = RegExp(
      '<item>(.*?)</item>',
      dotAll: true,
    );

    for (final match in itemPattern.allMatches(xml)) {
      final itemXml = match.group(1);
      if (itemXml == null) continue;

      final correction = _parseItem(itemXml, sentences, baseOffset);
      if (correction != null) {
        corrections.add(correction);
      }
    }

    return corrections;
  }

  /// Parse a single `<item>` block into a [Correction].
  static Correction? _parseItem(
    String itemXml,
    List<SentenceSpan> sentences,
    int baseOffset,
  ) {
    final original = _extractTag(itemXml, 'original');
    final corrected = _extractTag(itemXml, 'corrected');
    final type = _extractTag(itemXml, 'type');
    final explanation = _extractTag(itemXml, 'explanation');
    final offsetStr = _extractTag(itemXml, 'offset');

    if (original == null || corrected == null) return null;

    // Parse the offset from model output, or find it by searching
    var startOffset = baseOffset;
    if (offsetStr != null) {
      final parsed = int.tryParse(offsetStr.trim());
      if (parsed != null) {
        startOffset = baseOffset + parsed;
      } else {
        startOffset = _findOffsetByText(original, sentences, baseOffset);
      }
    } else {
      startOffset = _findOffsetByText(original, sentences, baseOffset);
    }

    final endOffset = startOffset + original.length;

    return Correction(
      startOffset: startOffset,
      endOffset: endOffset,
      originalText: original,
      correctedText: corrected,
      type: CorrectionType.fromString(type ?? 'grammar'),
      explanation: explanation ?? '',
    );
  }

  /// Extract the text content of an XML tag.
  static String? _extractTag(String xml, String tagName) {
    final pattern = RegExp(
      '<$tagName>(.*?)</$tagName>',
      dotAll: true,
    );
    final match = pattern.firstMatch(xml);
    return match?.group(1)?.trim();
  }

  /// Find the character offset of [text] within the sentences.
  ///
  /// Used as fallback when the model doesn't provide a valid offset.
  static int _findOffsetByText(
    String text,
    List<SentenceSpan> sentences,
    int baseOffset,
  ) {
    // Search in each sentence for the original text
    for (final sentence in sentences) {
      final index = sentence.text.indexOf(text);
      if (index >= 0) {
        return sentence.startOffset + index;
      }
    }

    // Fuzzy fallback: try case-insensitive search
    for (final sentence in sentences) {
      final index = sentence.text.toLowerCase().indexOf(text.toLowerCase());
      if (index >= 0) {
        return sentence.startOffset + index;
      }
    }

    return baseOffset;
  }

  /// Parse corrections from a streaming (potentially incomplete) XML output.
  ///
  /// Returns corrections for any complete `<item>` blocks found so far.
  /// Incomplete blocks at the end are ignored (will be parsed in next call).
  static List<Correction> parsePartial(
    String partialXml,
    List<SentenceSpan> sentences, {
    int baseOffset = 0,
  }) {
    // Same as parse(), but tolerant of missing closing tags
    return parse(partialXml, sentences, baseOffset: baseOffset);
  }
}
