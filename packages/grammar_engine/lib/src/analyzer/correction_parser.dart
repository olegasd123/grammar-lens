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
  static const _noErrorMarkers = {
    'no correction needed',
    'no corrections needed',
    'no error found',
    'no errors found',
    'correct as is',
  };

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
    final blocks = _extractCorrectionsBlocks(xml);
    final sourceText = sentences.map((s) => s.text).join('\n').toLowerCase();
    final primaryBlock = _selectBestCorrectionsBlock(blocks, sourceText) ?? xml;

    return _parseItems(primaryBlock, sentences, baseOffset);
  }

  static List<Correction> _parseItems(
    String xml,
    List<SentenceSpan> sentences,
    int baseOffset,
  ) {
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

  static List<String> _extractCorrectionsBlocks(String xml) {
    final blockPattern = RegExp(
      '<corrections>[\\s\\S]*?</corrections>',
      caseSensitive: false,
    );
    return blockPattern
        .allMatches(xml)
        .map((m) => m.group(0))
        .whereType<String>()
        .toList();
  }

  static String? _selectBestCorrectionsBlock(
    List<String> blocks,
    String sourceText,
  ) {
    if (blocks.isEmpty) return null;

    String? bestMatching;
    var bestMatchingScore = -1;

    for (final block in blocks) {
      final itemCount =
          RegExp('<item>(.*?)</item>', dotAll: true).allMatches(block).length;
      final validOriginalCount = RegExp(
        '<original>(.*?)</original>',
        dotAll: true,
      )
          .allMatches(block)
          .map((m) => m.group(1)?.trim().toLowerCase() ?? '')
          .where(
            (original) => original.isNotEmpty && sourceText.contains(original),
          )
          .length;

      // Prefer blocks that reference the actual source text.
      // Then prefer blocks with more items.
      // On ties, keep earlier block.
      final score = (validOriginalCount * 1000) + itemCount;
      if (validOriginalCount > 0 && score > bestMatchingScore) {
        bestMatchingScore = score;
        bestMatching = block;
      }
    }

    if (bestMatching != null) {
      return bestMatching;
    }

    // No block matches the source text; keep the first one to avoid
    // selecting unrelated examples from model chatter.
    return blocks.first;
  }

  /// Parse a single `<item>` block into a [Correction].
  static Correction? _parseItem(
    String itemXml,
    List<SentenceSpan> sentences,
    int baseOffset,
  ) {
    final original = _extractTag(itemXml, 'original');
    final corrected = _extractTag(itemXml, 'corrected');
    final type = _parseType(_extractTag(itemXml, 'type'));
    final explanation = _extractTag(itemXml, 'explanation');
    final offsetStr = _extractTag(itemXml, 'offset');

    if (original == null || corrected == null || type == null) return null;
    if (_containsNoErrorMarker(corrected) ||
        _containsNoErrorMarker(explanation)) {
      return null;
    }

    // Parse the offset from model output, or find it by searching
    var startOffset = baseOffset;
    if (offsetStr != null) {
      final parsed = int.tryParse(offsetStr.trim());
      if (parsed != null) {
        // Validate the offset is within the bounds of the input text
        final totalTextLength =
            sentences.fold<int>(0, (sum, s) => sum + s.text.length);
        if (parsed >= 0 && parsed < totalTextLength) {
          startOffset = baseOffset + parsed;
        } else {
          startOffset = _findOffsetByText(original, sentences, baseOffset);
        }
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
      type: type,
      explanation: explanation ?? '',
    );
  }

  static CorrectionType? _parseType(String? rawType) {
    if (rawType == null) return null;
    final normalizedType = rawType.trim().toLowerCase();
    for (final type in CorrectionType.values) {
      if (type.value == normalizedType) {
        return type;
      }
    }
    return null;
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

  static bool _containsNoErrorMarker(String? value) {
    if (value == null) return false;
    final normalized = value.trim().toLowerCase();
    for (final marker in _noErrorMarkers) {
      if (normalized.contains(marker)) {
        return true;
      }
    }
    return false;
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
