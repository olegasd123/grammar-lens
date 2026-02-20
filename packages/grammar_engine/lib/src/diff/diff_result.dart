/// A segment in a diff result.
enum DiffOperation {
  /// Text is unchanged.
  equal,

  /// Text was inserted (new text).
  insert,

  /// Text was deleted (old text).
  delete,
}

/// A single segment of a text diff.
class DiffSegment {
  /// The operation type.
  final DiffOperation operation;

  /// The text content of this segment.
  final String text;

  const DiffSegment({
    required this.operation,
    required this.text,
  });

  /// Whether this segment represents unchanged text.
  bool get isEqual => operation == DiffOperation.equal;

  /// Whether this segment represents inserted text.
  bool get isInsert => operation == DiffOperation.insert;

  /// Whether this segment represents deleted text.
  bool get isDelete => operation == DiffOperation.delete;

  @override
  String toString() => 'DiffSegment(${operation.name}: "$text")';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiffSegment &&
          operation == other.operation &&
          text == other.text;

  @override
  int get hashCode => Object.hash(operation, text);
}

/// Result of diffing two texts.
class DiffResult {
  /// Ordered list of diff segments.
  final List<DiffSegment> segments;

  const DiffResult(this.segments);

  /// Whether the texts are identical (no changes).
  bool get isIdentical => segments.every((s) => s.isEqual);

  /// Get only the equal segments.
  List<DiffSegment> get unchanged =>
      segments.where((s) => s.isEqual).toList();

  /// Get only the inserted segments.
  List<DiffSegment> get insertions =>
      segments.where((s) => s.isInsert).toList();

  /// Get only the deleted segments.
  List<DiffSegment> get deletions =>
      segments.where((s) => s.isDelete).toList();

  /// Build the original text from the diff.
  String get originalText {
    final buffer = StringBuffer();
    for (final segment in segments) {
      if (segment.isEqual || segment.isDelete) {
        buffer.write(segment.text);
      }
    }
    return buffer.toString();
  }

  /// Build the modified text from the diff.
  String get modifiedText {
    final buffer = StringBuffer();
    for (final segment in segments) {
      if (segment.isEqual || segment.isInsert) {
        buffer.write(segment.text);
      }
    }
    return buffer.toString();
  }

  @override
  String toString() => 'DiffResult(${segments.length} segments)';
}
